//
//  ReportFaultSheet.swift
//  CourtLink
//
//  Owner picks the exact court, describes the fault, and sees it pinned on the map.
//

import SwiftUI
import MapKit

struct FaultTarget: Identifiable {
    let facility: Facility
    let courtNumber: Int
    var id: String { "\(facility.id)-\(courtNumber)" }
}

struct CourtPinTarget: Identifiable {
    let facility: Facility
    let courtNumber: Int
    var id: String { "pin-\(facility.id)-\(courtNumber)" }
}

struct ReportFaultSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @StateObject private var locationService = LocationService()

    let facility: Facility

    @State private var courtNumber: Int
    @State private var category: FaultCategory = .surface
    @State private var severity: FaultSeverity = .moderate
    @State private var notes: String = ""
    @State private var showPinPicker = false

    private let onSiteRadius: Double = 150 // metres

    init(facility: Facility, courtNumber: Int = 1) {
        self.facility = facility
        _courtNumber = State(initialValue: min(max(courtNumber, 1), max(facility.courtsCount, 1)))
    }

    private var court: Court {
        dataStore.courts(for: facility).first { $0.number == courtNumber }
            ?? Court.generated(for: facility, number: courtNumber)
    }

    private var distanceToCourt: Double? { locationService.distance(to: court.coordinate) }
    private var isOnSite: Bool { (distanceToCourt ?? .infinity) <= onSiteRadius }

    var body: some View {
        NavigationStack {
            Form {
                Section("Which \(facility.sport.courtUnit.lowercased())?") {
                    Picker("\(facility.sport.courtUnit)", selection: $courtNumber) {
                        ForEach(1...max(facility.courtsCount, 1), id: \.self) { n in
                            Text("\(facility.sport.courtUnit) \(n)  •  \(Court.code(for: facility, number: n))").tag(n)
                        }
                    }
                    Text("This fault will be shown on the map at \(facility.sport.courtUnit) \(courtNumber)'s location.")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("Location on Map") {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: court.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)
                    )), interactionModes: []) {
                        Annotation("", coordinate: court.coordinate) {
                            CourtPin(number: court.number, status: .closed, isFocused: true)
                        }
                    }
                    .id("\(court.id)-\(court.latitude)-\(court.longitude)")
                    .frame(height: 160)
                    .cornerRadius(12)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                    Button {
                        showPinPicker = true
                    } label: {
                        Label(court.isCustomLocation ? "Adjust exact court position" : "Pin exact court position",
                              systemImage: "mappin.and.ellipse")
                    }
                }

                Section("Fault Details") {
                    Picker("Type", selection: $category) {
                        ForEach(FaultCategory.allCases) { c in
                            Label(c.rawValue, systemImage: c.iconName).tag(c)
                        }
                    }
                    Picker("Severity", selection: $severity) {
                        ForEach(FaultSeverity.allCases) { s in Text(s.title).tag(s) }
                    }
                    .pickerStyle(.segmented)
                    if severity.closesCourt {
                        Label("Critical faults close this \(facility.sport.courtUnit.lowercased()) for booking until resolved.",
                              systemImage: "lock.fill")
                            .font(.caption).foregroundColor(CourtLinkTheme.statusError)
                    }
                    TextField("Describe the problem", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("On-Site Verification (optional)") {
                    if let d = distanceToCourt {
                        Label(isOnSite ? "Verified: you are \(Int(d)) m from this court"
                                       : "You are \(Int(d)) m away from this court",
                              systemImage: isOnSite ? "checkmark.seal.fill" : "location.slash")
                            .foregroundColor(isOnSite ? CourtLinkTheme.statusSuccess : .secondary)
                            .font(.subheadline)
                    }
                    Button {
                        locationService.request()
                    } label: {
                        Label("Check my location", systemImage: "location.fill")
                    }
                }

                Section {
                    Button {
                        dataStore.reportFault(
                            facility: facility,
                            court: court,
                            category: category,
                            severity: severity,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            verifiedOnSite: isOnSite
                        )
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Report Fault").font(.headline.bold()).foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 50)
                        .background(CourtLinkTheme.statusError)
                        .cornerRadius(14)
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Report Fault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showPinPicker) {
                LocationPickerView(
                    title: "\(facility.sport.courtUnit) \(courtNumber) Position",
                    initial: court.coordinate,
                    onConfirm: { coordinate in
                        dataStore.setCourtLocation(facilityId: facility.id, number: courtNumber, coordinate: coordinate)
                    }
                )
            }
        }
    }
}
