//
//  FacilityMapView.swift
//  CourtLink
//
//  Facility + court-level map. Zoom in (or tap a facility) to see every court with its
//  number and live fault status, exactly where the owner placed it.
//

import SwiftUI
import MapKit

struct FacilityMapView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @EnvironmentObject var locationService: LocationService
    
    @State private var hasCenteredOnUser = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 6.9080, longitude: 79.8660),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var cameraSpan: Double = 0.08
    
    @State private var selectedFacility: Facility? = nil
    @State private var selectedCourt: Court? = nil
    @State private var selectedSport: SportType? = nil
    @State private var faultsOnly: Bool = false
    
    /// Courts become visible once the map is zoomed in far enough
    private var showCourts: Bool { cameraSpan < 0.006 }
    
    var visibleFacilities: [Facility] {
        dataStore.facilities.filter { facility in
            (selectedSport == nil || facility.sport == selectedSport) &&
            (!faultsOnly || !dataStore.openFaults(forFacility: facility.id).isEmpty)
        }
    }
    
    private var facilitiesToPin: [Facility] {
        visibleFacilities.filter { !(showCourts && $0.id == selectedFacility?.id) }
    }
    
    private var courtsToShow: [Court] {
        guard showCourts else { return [] }
        return visibleFacilities.flatMap { dataStore.courts(for: $0) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $position) {
                    UserAnnotation()
                    
                    ForEach(facilitiesToPin) { facility in
                        Annotation("", coordinate: facility.coordinate, anchor: .bottom) {
                            Button(action: { select(facility) }) {
                                MapMarkerBubble(
                                    facility: facility,
                                    isSelected: selectedFacility?.id == facility.id,
                                    faultSeverity: dataStore.worstOpenSeverity(forFacility: facility.id)
                                )
                            }
                        }
                    }
                    
                    ForEach(courtsToShow) { court in
                        Annotation("", coordinate: court.coordinate) {
                            CourtPin(
                                number: court.number,
                                status: dataStore.courtStatus(court.id),
                                isFocused: selectedCourt?.id == court.id
                            )
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedCourt = court
                                    selectedFacility = dataStore.facilities.first { $0.id == court.facilityId }
                                }
                            }
                        }
                    }
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    cameraSpan = context.region.span.latitudeDelta
                }
                .ignoresSafeArea(edges: .top)
                
                // Top Overlay: Sport Filters
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            MapFilterChip(title: "All", icon: "globe", isSelected: selectedSport == nil && !faultsOnly) {
                                selectedSport = nil
                                faultsOnly = false
                            }
                            
                            ForEach(SportType.allCases) { sport in
                                MapFilterChip(title: sport.rawValue, icon: sport.iconName, isSelected: selectedSport == sport) {
                                    selectedSport = sport
                                }
                            }
                            
                            MapFilterChip(title: "Faults", icon: "exclamationmark.triangle.fill", isSelected: faultsOnly) {
                                faultsOnly.toggle()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                    
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            MapRoundButton(icon: "location.fill") { centerOnUser(selectNearest: false) }
                            MapRoundButton(icon: "scope") { centerOnUser(selectNearest: true) }
                        }
                        .padding(.trailing)
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
                
                // Bottom card: court details if a court is tapped, otherwise the facility card
                if let court = selectedCourt, let facility = selectedFacility {
                    courtCard(court: court, facility: facility)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let facility = selectedFacility {
                    facilityCard(facility)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Explore Map")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                locationService.request()
                if selectedFacility == nil {
                    selectedFacility = dataStore.facilities.first
                }
                if locationService.location != nil, !hasCenteredOnUser {
                    centerOnUser(selectNearest: true)
                }
            }
            // First GPS fix: jump to the customer and highlight the closest court.
            .onChange(of: locationService.location) { _, newValue in
                guard newValue != nil, !hasCenteredOnUser else { return }
                centerOnUser(selectNearest: true)
            }
        }
    }
    
    /// Nearest facility to the customer within the currently visible filters.
    private var nearestFacility: NearbyFacility? {
        visibleFacilities.rankedByDistance(from: locationService.location).first { $0.distance != nil }
    }
    
    private func distanceText(for facility: Facility) -> String? {
        locationService.distance(to: facility.coordinate).map { NearbyFacility.format($0) }
    }
    
    /// Centre on the customer; optionally zoom so the nearest court is also in view.
    private func centerOnUser(selectNearest: Bool) {
        guard let user = locationService.location else {
            locationService.request()
            return
        }
        hasCenteredOnUser = true
        withAnimation(.spring()) {
            if selectNearest, let nearest = nearestFacility {
                selectedFacility = nearest.facility
                selectedCourt = nil
                let c1 = user.coordinate, c2 = nearest.facility.coordinate
                let center = CLLocationCoordinate2D(
                    latitude: (c1.latitude + c2.latitude) / 2,
                    longitude: (c1.longitude + c2.longitude) / 2
                )
                let span = max(abs(c1.latitude - c2.latitude), abs(c1.longitude - c2.longitude)) * 2.4
                position = .region(MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: max(span, 0.01), longitudeDelta: max(span, 0.01))
                ))
            } else {
                position = .region(MKCoordinateRegion(
                    center: user.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                ))
            }
        }
    }
    
    // MARK: - Actions
    private func select(_ facility: Facility) {
        withAnimation(.spring()) {
            selectedFacility = facility
            selectedCourt = nil
            position = .region(MKCoordinateRegion(
                center: facility.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0016, longitudeDelta: 0.0016)
            ))
        }
    }
    
    // MARK: - Court Card
    private func courtCard(court: Court, facility: Facility) -> some View {
        let status = dataStore.courtStatus(court.id)
        let faults = dataStore.openFaults(forCourt: court.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                CourtPin(number: court.number, status: status)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(facility.name)")
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(facility.sport.courtUnit) \(court.number) • \(Court.code(for: facility, number: court.number))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { withAnimation { selectedCourt = nil } }) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
            
            Text(status.title)
                .font(.caption.bold())
                .foregroundColor(status.color)
            
            ForEach(faults) { FaultRow(fault: $0) }
            
            NavigationLink(destination: FacilityDetailView(facility: facility)) {
                Text(status == .closed ? "View Facility" : "View Details & Book")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(CourtLinkTheme.primaryGreen)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .padding(.horizontal)
        .padding(.bottom, 16)
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Facility Card
    private func facilityCard(_ facility: Facility) -> some View {
        NavigationLink(destination: FacilityDetailView(facility: facility)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(facility.sport.badgeColor.opacity(0.15))
                        .frame(width: 70, height: 70)
                    Image(systemName: facility.imageSystemName)
                        .font(.system(size: 28))
                        .foregroundColor(facility.sport.badgeColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(facility.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", facility.rating))
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Text("\(facility.sport.rawValue) • \(facility.area)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let d = distanceText(for: facility) {
                        Label(nearestFacility?.id == facility.id ? "\(d) away • nearest to you" : "\(d) away",
                              systemImage: "location.fill")
                            .font(.caption.bold())
                            .foregroundColor(CourtLinkTheme.primaryGreen)
                    }
                    
                    let faultCount = dataStore.openFaults(forFacility: facility.id).count
                    if faultCount > 0 {
                        Label("\(faultCount) active fault\(faultCount == 1 ? "" : "s") • zoom in to see which court",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(CourtLinkTheme.statusWarning)
                    }
                    
                    HStack {
                        Text("\(facility.formattedPrice)/slot")
                            .font(.subheadline.bold())
                            .foregroundColor(CourtLinkTheme.primaryGreen)
                        Spacer()
                        Text("View Details")
                            .font(.caption.bold())
                            .foregroundColor(CourtLinkTheme.accentOrange)
                    }
                }
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .padding(.horizontal)
            .padding(.bottom, 16)
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Floating round map button
struct MapRoundButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundColor(CourtLinkTheme.primaryGreen)
                .frame(width: 40, height: 40)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Map Marker Bubble
struct MapMarkerBubble: View {
    let facility: Facility
    let isSelected: Bool
    var faultSeverity: FaultSeverity? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: facility.sport.iconName)
                    .font(.caption2.bold())
                Text(facility.formattedPrice)
                    .font(.caption2.bold())
                if let severity = faultSeverity {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2.bold())
                        .foregroundColor(severity == .critical ? .white : .yellow)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? CourtLinkTheme.accentOrange : CourtLinkTheme.primaryGreen)
            .foregroundColor(.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(faultSeverity?.color ?? Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            // Triangle pointer
            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundColor(isSelected ? CourtLinkTheme.accentOrange : CourtLinkTheme.primaryGreen)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
        }
    }
}

// MARK: - Map Filter Chip
struct MapFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? CourtLinkTheme.primaryGreen : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
    }
}

#Preview {
    FacilityMapView()
        .environmentObject(CourtLinkDataStore())
        .environmentObject(LocationService())
}
