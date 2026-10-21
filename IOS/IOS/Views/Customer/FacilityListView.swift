//
//  FacilityListView.swift
//  CourtLink
//

import SwiftUI

struct FacilityListView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @EnvironmentObject var locationService: LocationService
    @State private var searchText: String = ""
    @State private var selectedFilter: SportType? = nil
    /// Maximum distance in km (nil = any distance)
    @State private var radiusKm: Double? = nil
    
    private let radiusOptions: [Double?] = [nil, 2, 5, 10, 25]
    
    /// Facilities matching sport/search/radius, ordered nearest-first when GPS is available.
    var filteredFacilities: [NearbyFacility] {
        let matches = dataStore.facilities.filter { facility in
            let matchesSport = (selectedFilter == nil) || (facility.sport == selectedFilter)
            let matchesSearch = searchText.isEmpty ||
                facility.name.localizedCaseInsensitiveContains(searchText) ||
                facility.area.localizedCaseInsensitiveContains(searchText) ||
                facility.address.localizedCaseInsensitiveContains(searchText) ||
                facility.sport.rawValue.localizedCaseInsensitiveContains(searchText)
            return matchesSport && matchesSearch
        }
        let ranked = matches.rankedByDistance(from: locationService.location)
        guard let radiusKm else { return ranked }
        return ranked.filter { ($0.distance ?? 0) <= radiusKm * 1000 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search & Filter Header
            VStack(spacing: 12) {
                // Search Field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search venues, areas in Colombo...", text: $searchText)
                        .font(.subheadline)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(14)
                .padding(.horizontal)
                
                // Sport Filter Pills (Horizontal Scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(
                            title: "All Sports",
                            isSelected: selectedFilter == nil,
                            icon: "sportscourt"
                        ) {
                            selectedFilter = nil
                            dataStore.selectedSport = nil
                        }
                        
                        ForEach(SportType.allCases) { sport in
                            FilterPill(
                                title: sport.rawValue,
                                isSelected: selectedFilter == sport,
                                icon: sport.iconName
                            ) {
                                selectedFilter = sport
                                dataStore.selectedSport = sport
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Distance radius (only useful once we know where the customer is)
                if locationService.location != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(radiusOptions, id: \.self) { option in
                                FilterPill(
                                    title: option.map { "Within \(Int($0)) km" } ?? "Any distance",
                                    isSelected: radiusKm == option,
                                    icon: option == nil ? "infinity" : "location.circle"
                                ) {
                                    radiusKm = option
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            
            // List Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    locationBanner
                    
                    HStack {
                        Text(resultsTitle)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    ForEach(Array(filteredFacilities.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(destination: FacilityDetailView(facility: item.facility)) {
                            FacilityListRow(
                                facility: item.facility,
                                distanceText: item.distanceText,
                                travelHint: item.travelHint,
                                isNearest: index == 0 && item.distance != nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if filteredFacilities.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "mappin.slash")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No courts found")
                                .font(.headline)
                            Text("Try a larger distance or a different sport.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
        .navigationTitle("Nearby Facilities")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let preselected = dataStore.selectedSport {
                selectedFilter = preselected
            }
            locationService.request()
        }
    }
    
    private var resultsTitle: String {
        let count = filteredFacilities.count
        if locationService.location != nil {
            let from = locationService.placeName.map { " to \($0)" } ?? " to you"
            return "\(count) court\(count == 1 ? "" : "s") • nearest first\(from)"
        }
        return "\(count) places"
    }
    
    /// Shown when we have no GPS fix, so the customer knows why distances are missing.
    @ViewBuilder
    private var locationBanner: some View {
        if locationService.isDenied {
            HStack(spacing: 10) {
                Image(systemName: "location.slash.fill").foregroundColor(CourtLinkTheme.accentOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location is off").font(.subheadline.bold())
                    Text("Turn it on in Settings to see the courts closest to you.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption.bold())
            }
            .padding(12)
            .background(CourtLinkTheme.accentOrangeLight)
            .cornerRadius(14)
            .padding(.horizontal)
            .padding(.top, 12)
        } else if locationService.location == nil {
            Button(action: { locationService.request() }) {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill").foregroundColor(CourtLinkTheme.primaryGreen)
                    Text("Allow location to sort courts by distance")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(14)
                .padding(.horizontal)
                .padding(.top, 12)
            }
        } else {
            Color.clear.frame(height: 4)
        }
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2.bold())
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? CourtLinkTheme.primaryGreen : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Facility List Row Card (Screen 3)
struct FacilityListRow: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    let facility: Facility
    var distanceText: String? = nil
    var travelHint: String? = nil
    var isNearest: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Visual / Icon Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(facility.sport.badgeColor.opacity(0.12))
                    .frame(width: 80, height: 80)
                
                Image(systemName: facility.imageSystemName)
                    .font(.system(size: 32))
                    .foregroundColor(facility.sport.badgeColor)
            }
            
            // Facility Information
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(facility.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        dataStore.toggleFavorite(facilityId: facility.id)
                    }) {
                        Image(systemName: dataStore.isFavorite(facilityId: facility.id) ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundColor(dataStore.isFavorite(facilityId: facility.id) ? .red : .secondary)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(facility.sport.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(facility.sport.badgeColor)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(facility.area)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let distanceText {
                    HStack(spacing: 6) {
                        Label(distanceText, systemImage: "location.fill")
                            .font(.caption.bold())
                            .foregroundColor(CourtLinkTheme.primaryGreen)
                        if let travelHint {
                            Text(travelHint)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if isNearest {
                            Text("NEAREST")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(CourtLinkTheme.accentOrange)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                }
                
                HStack {
                    Text(facility.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(CourtLinkTheme.primaryGreen)
                    
                    Text("/ slot")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Rating Badge
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", facility.rating))
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        FacilityListView()
            .environmentObject(CourtLinkDataStore())
            .environmentObject(LocationService())
    }
}
