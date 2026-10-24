//
//  CourtLinkDataStore+Courts.swift
//  CourtLink
//
//  Court identity, court locations and fault management (local + Firestore real-time sync).
//

import SwiftUI
import CoreLocation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

extension CourtLinkDataStore {

    // MARK: - Court lookup
    /// All courts of a facility. Owner-pinned courts keep their saved location,
    /// the rest are auto-placed around the facility coordinate.
    func courts(for facility: Facility) -> [Court] {
        let total = max(facility.courtsCount, 1)
        return (1...total).map { number in
            let id = Court.makeId(facilityId: facility.id, number: number)
            return customCourts[id] ?? Court.generated(for: facility, number: number)
        }
    }

    func court(facilityId: String, number: Int) -> Court? {
        guard let facility = facilities.first(where: { $0.id == facilityId }) else { return nil }
        return courts(for: facility).first { $0.number == number }
    }

    /// Current map coordinate of a fault = current coordinate of its court (so it follows the court).
    func coordinate(for fault: CourtFault) -> CLLocationCoordinate2D {
        court(facilityId: fault.facilityId, number: fault.courtNumber)?.coordinate ?? fault.coordinate
    }

    // MARK: - Fault queries
    func openFaults(forCourt courtId: String) -> [CourtFault] {
        courtFaults.filter { $0.courtId == courtId && $0.status.isOpen }
    }

    func openFaults(forFacility facilityId: String) -> [CourtFault] {
        courtFaults.filter { $0.facilityId == facilityId && $0.status.isOpen }
    }

    func faults(forFacility facilityId: String) -> [CourtFault] {
        courtFaults
            .filter { $0.facilityId == facilityId }
            .sorted { $0.reportedAt > $1.reportedAt }
    }

    func courtStatus(_ courtId: String) -> CourtStatus {
        let open = openFaults(forCourt: courtId)
        if open.contains(where: { $0.severity.closesCourt }) { return .closed }
        return open.isEmpty ? .available : .needsAttention
    }

    func worstOpenSeverity(forFacility facilityId: String) -> FaultSeverity? {
        openFaults(forFacility: facilityId).map(\.severity).max()
    }

    func isCourtBookable(facilityId: String, number: Int) -> Bool {
        courtStatus(Court.makeId(facilityId: facilityId, number: number)) != .closed
    }

    // MARK: - Fault actions
    @discardableResult
    func reportFault(
        facility: Facility,
        court: Court,
        category: FaultCategory,
        severity: FaultSeverity,
        notes: String,
        verifiedOnSite: Bool
    ) -> CourtFault {
        let fault = CourtFault(
            id: "flt-\(UUID().uuidString.prefix(8))",
            facilityId: facility.id,
            courtId: court.id,
            courtNumber: court.number,
            category: category,
            severity: severity,
            notes: notes,
            status: .reported,
            reportedBy: userName,
            reportedAt: Date(),
            resolvedAt: nil,
            latitude: court.latitude,
            longitude: court.longitude,
            verifiedOnSite: verifiedOnSite
        )
        courtFaults.insert(fault, at: 0)
        
        // Notify the owner about the new fault
        NotificationService.shared.notifyOwnerFaultReported(fault: fault, facilityName: facility.name)

        #if canImport(FirebaseFirestore)
        Firestore.firestore().collection("faults").document(fault.id).setData([
            "id": fault.id,
            "facilityId": fault.facilityId,
            "courtId": fault.courtId,
            "courtNumber": fault.courtNumber,
            "category": fault.category.rawValue,
            "severity": fault.severity.rawValue,
            "notes": fault.notes,
            "status": fault.status.rawValue,
            "reportedBy": fault.reportedBy,
            "reportedAt": Timestamp(date: fault.reportedAt),
            "latitude": fault.latitude,
            "longitude": fault.longitude,
            "verifiedOnSite": fault.verifiedOnSite
        ]) { error in
            if let error = error {
                print("Error saving fault: \(error.localizedDescription)")
            }
        }
        #endif
        return fault
    }

    func updateFaultStatus(faultId: String, status: FaultStatus) {
        guard let index = courtFaults.firstIndex(where: { $0.id == faultId }) else { return }
        courtFaults[index].status = status
        courtFaults[index].resolvedAt = status == .resolved ? Date() : nil
        
        // Notify the owner about the status change
        let updatedFault = courtFaults[index]
        let facilityName = facilities.first(where: { $0.id == updatedFault.facilityId })?.name ?? "Facility"
        NotificationService.shared.notifyOwnerFaultStatusUpdated(fault: updatedFault, facilityName: facilityName)

        #if canImport(FirebaseFirestore)
        var data: [String: Any] = ["status": status.rawValue]
        if status == .resolved {
            data["resolvedAt"] = Timestamp(date: Date())
        } else {
            data["resolvedAt"] = FieldValue.delete()
        }
        Firestore.firestore().collection("faults").document(faultId).updateData(data)
        #endif
    }

    func deleteFault(faultId: String) {
        courtFaults.removeAll { $0.id == faultId }
        #if canImport(FirebaseFirestore)
        Firestore.firestore().collection("faults").document(faultId).delete()
        #endif
    }

    // MARK: - Court location (owner pins the exact court position)
    func setCourtLocation(facilityId: String, number: Int, coordinate: CLLocationCoordinate2D) {
        let id = Court.makeId(facilityId: facilityId, number: number)
        let court = Court(
            id: id,
            facilityId: facilityId,
            number: number,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            isCustomLocation: true
        )
        customCourts[id] = court

        #if canImport(FirebaseFirestore)
        Firestore.firestore().collection("courts").document(id).setData([
            "id": id,
            "facilityId": facilityId,
            "number": number,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude
        ])
        #endif
    }

    func resetCourtLocation(facilityId: String, number: Int) {
        let id = Court.makeId(facilityId: facilityId, number: number)
        customCourts[id] = nil
        #if canImport(FirebaseFirestore)
        Firestore.firestore().collection("courts").document(id).delete()
        #endif
    }

    // MARK: - Firestore real-time listeners
    func listenForCourtsAndFaults() {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()

        db.collection("courts").addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self, let documents = snapshot?.documents else { return }
            var map: [String: Court] = [:]
            for doc in documents {
                let d = doc.data()
                guard let facilityId = d["facilityId"] as? String,
                      let number = d["number"] as? Int,
                      let lat = d["latitude"] as? Double,
                      let lon = d["longitude"] as? Double else { continue }
                map[doc.documentID] = Court(
                    id: doc.documentID,
                    facilityId: facilityId,
                    number: number,
                    latitude: lat,
                    longitude: lon,
                    isCustomLocation: true
                )
            }
            DispatchQueue.main.async { self.customCourts = map }
        }

        db.collection("faults").addSnapshotListener { [weak self] snapshot, _ in
            guard let self = self, let documents = snapshot?.documents else { return }
            let remote = documents.compactMap { doc -> CourtFault? in
                let d = doc.data()
                guard let facilityId = d["facilityId"] as? String,
                      let courtId = d["courtId"] as? String,
                      let courtNumber = d["courtNumber"] as? Int,
                      let categoryRaw = d["category"] as? String,
                      let category = FaultCategory(rawValue: categoryRaw),
                      let severityRaw = d["severity"] as? Int,
                      let severity = FaultSeverity(rawValue: severityRaw) else { return nil }
                let status = FaultStatus(rawValue: d["status"] as? String ?? "") ?? .reported
                return CourtFault(
                    id: doc.documentID,
                    facilityId: facilityId,
                    courtId: courtId,
                    courtNumber: courtNumber,
                    category: category,
                    severity: severity,
                    notes: d["notes"] as? String ?? "",
                    status: status,
                    reportedBy: d["reportedBy"] as? String ?? "Owner",
                    reportedAt: (d["reportedAt"] as? Timestamp)?.dateValue() ?? Date(),
                    resolvedAt: (d["resolvedAt"] as? Timestamp)?.dateValue(),
                    latitude: d["latitude"] as? Double ?? 0,
                    longitude: d["longitude"] as? Double ?? 0,
                    verifiedOnSite: d["verifiedOnSite"] as? Bool ?? false
                )
            }
            DispatchQueue.main.async {
                self.courtFaults = remote.sorted { $0.reportedAt > $1.reportedAt }
            }
        }
        #endif
    }
}
