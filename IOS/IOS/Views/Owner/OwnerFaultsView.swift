//
//  OwnerFaultsView.swift
//  CourtLink
//
//  Owner's fault centre: live map of every court (coloured by status) + fault list with status control.
//

import SwiftUI
import MapKit

struct OwnerFaultsView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore

    private enum Mode: String, CaseIterable { case map = "Map", list = "List" }

    @State private var mode: Mode = .map
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCourt: Court?
    @State private var faultTarget: FaultTarget?

    private var facility: Facility? { dataStore.ownerFacility }
    private var courts: [Court] { facility.map { dataStore.courts(for: $0) } ?? [] }
    private var faults: [CourtFault] { facility.map { dataStore.faults(forFacility: $0.id) } ?? [] }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if facility == nil {
                    Text("No facility yet.").foregroundColor(.secondary).frame(maxHeight: .infinity)
                } else if mode == .map {
                    mapView
                } else {
                    listView
                }
            }
            .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
            .navigationTitle("Court Faults")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(dataStore.ownerFacilities) { f in
                            Button(f.name) {
                                dataStore.ownerFacilityId = f.id
                                selectedCourt = nil
                                focusFacility()
                            }
                        }
                    } label: {
                        Image(systemName: "building.2")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let f = facility {
                            faultTarget = FaultTarget(facility: f, courtNumber: selectedCourt?.number ?? 1)
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(item: $faultTarget) { target in
                ReportFaultSheet(facility: target.facility, courtNumber: target.courtNumber)
            }
            .onAppear { focusFacility() }
        }
    }

    // MARK: Map
    private var mapView: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position) {
                ForEach(courts) { court in
                    Annotation("", coordinate: court.coordinate) {
                        CourtPin(
                            number: court.number,
                            status: dataStore.courtStatus(court.id),
                            isFocused: selectedCourt?.id == court.id
                        )
                        .onTapGesture { withAnimation { selectedCourt = court } }
                    }
                }
            }
            .mapStyle(.hybrid)

            if let court = selectedCourt, let f = facility {
                courtCard(court: court, facility: f)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                legend.padding()
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([CourtStatus.available, .needsAttention, .closed], id: \.title) { s in
                HStack(spacing: 5) {
                    Circle().fill(s.color).frame(width: 10, height: 10)
                    Text(s.title).font(.caption2.bold())
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func courtCard(court: Court, facility: Facility) -> some View {
        let open = dataStore.openFaults(forCourt: court.id)
        let status = dataStore.courtStatus(court.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(facility.sport.courtUnit) \(court.number) • \(Court.code(for: facility, number: court.number))")
                        .font(.headline)
                    Text(status.title).font(.caption.bold()).foregroundColor(status.color)
                }
                Spacer()
                Button { selectedCourt = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
            ForEach(open) { FaultRow(fault: $0) }
            Button {
                faultTarget = FaultTarget(facility: facility, courtNumber: court.number)
            } label: {
                Label("Report Fault Here", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(CourtLinkTheme.statusError)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
    }

    // MARK: List
    private var listView: some View {
        List {
            if faults.isEmpty {
                Text("No faults reported. All courts are in good condition.")
                    .foregroundColor(.secondary)
            }
            ForEach(faults) { fault in
                FaultRow(fault: fault)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            dataStore.deleteFault(faultId: fault.id)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                    .contextMenu {
                        ForEach(FaultStatus.allCases) { s in
                            Button {
                                dataStore.updateFaultStatus(faultId: fault.id, status: s)
                            } label: { Label(s.rawValue, systemImage: s.iconName) }
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func focusFacility() {
        guard let f = facility else { return }
        position = .region(MKCoordinateRegion(
            center: f.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.0025, longitudeDelta: 0.0025)
        ))
    }
}
