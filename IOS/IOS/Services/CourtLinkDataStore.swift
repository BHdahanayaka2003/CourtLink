//
//  CourtLinkDataStore.swift
//  CourtLink
//

import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class CourtLinkDataStore: ObservableObject {
    @Published var facilities: [Facility] = []
    @Published var bookings: [Booking] = []
    @Published var selectedSport: SportType? = nil
    @Published var favoriteFacilityIds: Set<String> = []
    
    // Owner Mode State
    @Published var isOwnerMode: Bool = false
    @Published var ownerFacilityId: String = ""
    @Published var ownerFacilityIds: Set<String> = []
    
    // User Info
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var userPhone: String = ""
    
    // Blocked Slots cache: [FacilityId-DateString-SlotId: Bool]
    @Published var blockedSlots: Set<String> = []
    
    // Court identity + fault tracking (see CourtLinkDataStore+Courts.swift)
    @Published var customCourts: [String: Court] = [:]   // owner-pinned court locations, keyed by court id
    @Published var courtFaults: [CourtFault] = []
    
    init() {
        fetchFacilitiesFromFirestore()
        fetchBookingsFromFirestore()
        listenForCourtsAndFaults()
    }
    
    // MARK: - Firestore Real-Time Listener
    func fetchFacilitiesFromFirestore() {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("facilities").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents, !documents.isEmpty else { return }
            
            let firestoreFacilities = documents.compactMap { doc -> Facility? in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let sportRaw = data["sport"] as? String,
                      let sport = SportType(rawValue: sportRaw) else { return nil }
                
                return Facility(
                    id: doc.documentID,
                    name: name,
                    sport: sport,
                    address: data["address"] as? String ?? "",
                    area: data["area"] as? String ?? "Colombo",
                    latitude: data["latitude"] as? Double ?? 6.9080,
                    longitude: data["longitude"] as? Double ?? 79.8660,
                    pricePerHour: data["pricePerHour"] as? Int ?? 1500,
                    rating: data["rating"] as? Double ?? 4.8,
                    reviewsCount: data["reviewsCount"] as? Int ?? 10,
                    openingHours: data["openingHours"] as? String ?? "06:00 AM - 10:00 PM",
                    amenities: data["amenities"] as? [String] ?? ["Parking", "Locker Room"],
                    description: data["description"] as? String ?? "",
                    courtsCount: data["courtsCount"] as? Int ?? 1,
                    imageSystemName: data["imageSystemName"] as? String ?? "sportscourt.fill",
                    isFeatured: data["isFeatured"] as? Bool ?? false
                )
            }
            
            DispatchQueue.main.async {
                for f in firestoreFacilities {
                    if let idx = self.facilities.firstIndex(where: { $0.id == f.id }) {
                        self.facilities[idx] = f
                    } else {
                        self.facilities.insert(f, at: 0)
                        self.ownerFacilityIds.insert(f.id)
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - Firestore Bookings Listener
    func fetchBookingsFromFirestore() {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("bookings").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents else { return }
            let firestoreBookings = documents.compactMap { doc -> Booking? in
                let data = doc.data()
                guard let facilityId   = data["facilityId"]   as? String,
                      let facilityName = data["facilityName"] as? String,
                      let sportRaw     = data["sport"]        as? String,
                      let sport        = SportType(rawValue: sportRaw),
                      let timestamp    = data["date"]         as? Timestamp,
                      let timeSlot     = data["timeSlot"]     as? String,
                      let courtNumber  = data["courtNumber"]  as? Int,
                      let price        = data["price"]        as? Int,
                      let statusRaw    = data["status"]       as? String,
                      let status       = BookingStatus(rawValue: statusRaw) else { return nil }
                return Booking(
                    id: doc.documentID,
                    facilityId: facilityId,
                    facilityName: facilityName,
                    facilityAddress: data["facilityAddress"] as? String ?? "",
                    sport: sport,
                    date: timestamp.dateValue(),
                    timeSlot: timeSlot,
                    courtNumber: courtNumber,
                    price: price,
                    status: status,
                    customerName: data["customerName"] as? String ?? "",
                    customerPhone: data["customerPhone"] as? String ?? "",
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
            DispatchQueue.main.async {
                self.bookings = firestoreBookings.sorted { $0.createdAt > $1.createdAt }
            }
        }
        #endif
    }
    
    // MARK: - Helper Methods
    func toggleFavorite(facilityId: String) {
        if favoriteFacilityIds.contains(facilityId) {
            favoriteFacilityIds.remove(facilityId)
        } else {
            favoriteFacilityIds.insert(facilityId)
        }
    }
    
    func isFavorite(facilityId: String) -> Bool {
        favoriteFacilityIds.contains(facilityId)
    }
    
    func bookSlot(
        facility: Facility,
        date: Date,
        slot: TimeSlot,
        courtNumber: Int
    ) -> Booking {
        let newBookingId = "CL-\(Int.random(in: 10000...99999))"
        let booking = Booking(
            id: newBookingId,
            facilityId: facility.id,
            facilityName: facility.name,
            facilityAddress: facility.address,
            sport: facility.sport,
            date: date,
            timeSlot: slot.timeLabel,
            courtNumber: courtNumber,
            price: facility.pricePerHour,
            status: .confirmed,
            customerName: userName,
            customerPhone: userPhone,
            createdAt: Date()
        )
        bookings.insert(booking, at: 0)
        
        // Notify the customer
        NotificationService.shared.notifyBookingConfirmed(booking: booking)
        NotificationService.shared.scheduleBookingReminder(booking: booking)
        
        // Notify the owner (if they are on this device in owner mode)
        if isOwnerMode {
            NotificationService.shared.notifyOwnerNewBooking(booking: booking)
        }
        
        // Sync to Firestore if available
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("bookings").document(booking.id).setData([
            "id": booking.id,
            "facilityId": booking.facilityId,
            "facilityName": booking.facilityName,
            "facilityAddress": booking.facilityAddress,
            "sport": booking.sport.rawValue,
            "date": Timestamp(date: booking.date),
            "timeSlot": booking.timeSlot,
            "courtNumber": booking.courtNumber,
            "price": booking.price,
            "status": booking.status.rawValue,
            "customerName": booking.customerName,
            "customerPhone": booking.customerPhone,
            "createdAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Firestore booking sync error: \(error.localizedDescription)")
            } else {
                print("Booking synced to Firestore successfully!")
            }
        }
        #endif
        
        return booking
    }
    
    func cancelBooking(bookingId: String) {
        if let index = bookings.firstIndex(where: { $0.id == bookingId }) {
            bookings[index].status = .cancelled
            let cancelled = bookings[index]
            
            // Notify the customer and cancel any pending reminder
            NotificationService.shared.notifyBookingCancelled(booking: cancelled)
            
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            db.collection("bookings").document(bookingId).updateData([
                "status": BookingStatus.cancelled.rawValue
            ])
            #endif
        }
    }
    
    // MARK: - Owner Mode Actions
    var ownerFacility: Facility? {
        facilities.first(where: { $0.id == ownerFacilityId }) ?? facilities.first
    }
    
    var ownerFacilities: [Facility] {
        facilities.filter { ownerFacilityIds.contains($0.id) }
    }
    
    var ownerTodayBookings: [Booking] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayEnd = Calendar.current.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        return bookings.filter {
            $0.facilityId == ownerFacilityId &&
            $0.date >= todayStart &&
            $0.date < todayEnd
        }
    }
    
    var ownerTodayRevenue: Int {
        ownerTodayBookings
            .filter { $0.status == .confirmed || $0.status == .completed }
            .reduce(0) { $0 + $1.price }
    }
    
    // MARK: - Add New Facility (Firestore + Local)
    func addFacility(facility: Facility) {
        facilities.insert(facility, at: 0)
        ownerFacilityIds.insert(facility.id)
        ownerFacilityId = facility.id
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("facilities").document(facility.id).setData([
            "id": facility.id,
            "name": facility.name,
            "sport": facility.sport.rawValue,
            "address": facility.address,
            "area": facility.area,
            "latitude": facility.latitude,
            "longitude": facility.longitude,
            "pricePerHour": facility.pricePerHour,
            "rating": facility.rating,
            "reviewsCount": facility.reviewsCount,
            "openingHours": facility.openingHours,
            "amenities": facility.amenities,
            "description": facility.description,
            "courtsCount": facility.courtsCount,
            "imageSystemName": facility.imageSystemName,
            "isFeatured": facility.isFeatured,
            "createdAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error saving facility to Firestore: \(error.localizedDescription)")
            } else {
                print("Facility successfully saved to Firestore!")
            }
        }
        #endif
    }
    
    // MARK: - Update Existing Facility (Firestore + Local)
    func updateFacility(facility: Facility) {
        if let index = facilities.firstIndex(where: { $0.id == facility.id }) {
            facilities[index] = facility
        }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("facilities").document(facility.id).setData([
            "id": facility.id,
            "name": facility.name,
            "sport": facility.sport.rawValue,
            "address": facility.address,
            "area": facility.area,
            "latitude": facility.latitude,
            "longitude": facility.longitude,
            "pricePerHour": facility.pricePerHour,
            "rating": facility.rating,
            "reviewsCount": facility.reviewsCount,
            "openingHours": facility.openingHours,
            "amenities": facility.amenities,
            "description": facility.description,
            "courtsCount": facility.courtsCount,
            "imageSystemName": facility.imageSystemName,
            "isFeatured": facility.isFeatured,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                print("Error updating facility in Firestore: \(error.localizedDescription)")
            } else {
                print("Facility successfully updated in Firestore!")
            }
        }
        #endif
    }
    
    // Legacy support alias
    func updateOwnerFacility(updated: Facility) {
        updateFacility(facility: updated)
    }
    
    // MARK: - Add Court to Facility (+ Add Court button)
    func addCourt(to facilityId: String) {
        if let index = facilities.firstIndex(where: { $0.id == facilityId }) {
            facilities[index].courtsCount += 1
            let updated = facilities[index]
            
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            db.collection("facilities").document(facilityId).updateData([
                "courtsCount": updated.courtsCount
            ])
            #endif
        }
    }
    
    // MARK: - Delete Facility
    func deleteFacility(facilityId: String) {
        facilities.removeAll { $0.id == facilityId }
        courtFaults.removeAll { $0.facilityId == facilityId }
        ownerFacilityIds.remove(facilityId)
        if ownerFacilityId == facilityId, let first = ownerFacilities.first {
            ownerFacilityId = first.id
        }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("facilities").document(facilityId).delete()
        #endif
    }
    
    func toggleBlockSlot(facilityId: String, dateString: String, slotId: String) {
        let key = "\(facilityId)_\(dateString)_\(slotId)"
        if blockedSlots.contains(key) {
            blockedSlots.remove(key)
        } else {
            blockedSlots.insert(key)
        }
    }
    
    func isSlotBlocked(facilityId: String, dateString: String, slotId: String) -> Bool {
        blockedSlots.contains("\(facilityId)_\(dateString)_\(slotId)")
    }
    
    // MARK: - Generate Time Slots for a Date
    func getTimeSlots(for facilityId: String, on date: Date) -> [TimeSlot] {
        let dateKey = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        
        let rawSlots: [(String, String, DayPeriod)] = [
            // Morning
            ("06:00 AM - 07:00 AM", "06:00", .morning),
            ("07:00 AM - 08:00 AM", "07:00", .morning),
            ("08:00 AM - 09:00 AM", "08:00", .morning),
            ("09:00 AM - 10:00 AM", "09:00", .morning),
            ("10:00 AM - 11:00 AM", "10:00", .morning),
            
            // Afternoon
            ("12:00 PM - 01:00 PM", "12:00", .afternoon),
            ("01:00 PM - 02:00 PM", "13:00", .afternoon),
            ("02:00 PM - 03:00 PM", "14:00", .afternoon),
            ("03:00 PM - 04:00 PM", "15:00", .afternoon),
            ("04:00 PM - 05:00 PM", "16:00", .afternoon),
            
            // Evening
            ("05:00 PM - 06:00 PM", "17:00", .evening),
            ("06:00 PM - 07:00 PM", "18:00", .evening),
            ("07:00 PM - 08:00 PM", "19:00", .evening),
            ("08:00 PM - 09:00 PM", "20:00", .evening),
            ("09:00 PM - 10:00 PM", "21:00", .evening)
        ]
        
        return rawSlots.enumerated().map { index, slotTuple in
            let slotId = "slot-\(index)"
            let isBlocked = isSlotBlocked(facilityId: facilityId, dateString: dateKey, slotId: slotId)
            
            return TimeSlot(
                id: slotId,
                timeLabel: slotTuple.0,
                startTimeString: slotTuple.1,
                period: slotTuple.2,
                isAvailable: !isBlocked,
                isBlockedByOwner: isBlocked
            )
        }
    }
}
