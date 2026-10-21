//
//  SportSelectionView.swift
//  CourtLink
//

import SwiftUI

struct SportSelectionView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @EnvironmentObject var locationService: LocationService
    @State private var navigateToFacilities = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Greeting & Title
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(locationService.placeName ?? "Colombo, Sri Lanka") 📍")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(CourtLinkTheme.primaryGreen)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(20)
                                
                                Text("What are you playing?")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            
                            // Favorite indicator button
                            NavigationLink(destination: MyBookingsView()) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.title3)
                                    .foregroundColor(CourtLinkTheme.primaryGreen)
                                    .padding(10)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Text("Find and book sports venues around you with live availability.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Sports 2x2 Grid (Figma Design)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        ForEach(SportType.allCases) { sport in
                            SportCard(
                                sport: sport,
                                isSelected: dataStore.selectedSport == sport,
                                count: countFor(sport: sport)
                            ) {
                                dataStore.selectedSport = sport
                                navigateToFacilities = true
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Featured Venues Near You
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(locationService.location == nil ? "Featured Venues" : "Courts Nearest You")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button(action: {
                                dataStore.selectedSport = nil
                                navigateToFacilities = true
                            }) {
                                Text("View All")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(CourtLinkTheme.primaryGreen)
                            }
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(homeVenues) { item in
                                    NavigationLink(destination: FacilityDetailView(facility: item.facility)) {
                                        FeaturedVenueCard(facility: item.facility, distanceText: item.distanceText)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Quick Action Banner
                    HStack(spacing: 16) {
                        Image(systemName: "bolt.fill")
                            .font(.title2)
                            .foregroundColor(CourtLinkTheme.accentOrange)
                            .padding(12)
                            .background(CourtLinkTheme.accentOrangeLight)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fast Targeted Booking")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Sport • Facility • Slot • Instant Confirmation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
            .navigationDestination(isPresented: $navigateToFacilities) {
                FacilityListView()
            }
        }
    }
    
    /// With GPS: the 8 closest courts of any kind. Without GPS: the featured venues.
    private var homeVenues: [NearbyFacility] {
        if locationService.location != nil {
            return Array(dataStore.facilities.rankedByDistance(from: locationService.location).prefix(8))
        }
        return dataStore.facilities.filter { $0.isFeatured }.rankedByDistance(from: nil)
    }
    
    private func countFor(sport: SportType) -> Int {
        dataStore.facilities.filter { $0.sport == sport }.count
    }
}

// MARK: - Sport Card (Screen 2 Component)
struct SportCard: View {
    let sport: SportType
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(sport.badgeColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: sport.iconName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(sport.badgeColor)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(sport.rawValue)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(count) venues active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? CourtLinkTheme.primaryGreen : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Featured Venue Card
struct FeaturedVenueCard: View {
    let facility: Facility
    var distanceText: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(CourtLinkTheme.primaryGreen.opacity(0.12))
                    .frame(width: 240, height: 130)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: facility.imageSystemName)
                                .font(.system(size: 40))
                                .foregroundColor(CourtLinkTheme.primaryGreen)
                            Text(facility.sport.rawValue)
                                .font(.caption2.bold())
                                .foregroundColor(CourtLinkTheme.primaryGreen)
                        }
                    )
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", facility.rating))
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.92))
                .cornerRadius(12)
                .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(facility.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("\(facility.area) • \(facility.formattedPrice)/slot")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let distanceText {
                    Label("\(distanceText) away", systemImage: "location.fill")
                        .font(.caption.bold())
                        .foregroundColor(CourtLinkTheme.primaryGreen)
                }
            }
            .frame(width: 240, alignment: .leading)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    SportSelectionView()
        .environmentObject(CourtLinkDataStore())
        .environmentObject(LocationService())
}
