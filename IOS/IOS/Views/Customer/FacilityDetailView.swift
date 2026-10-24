//
//  FacilityDetailView.swift
//  CourtLink
//

import SwiftUI

struct FacilityDetailView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    let facility: Facility
    @State private var navigateToBooking = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero Banner Card
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        facility.sport.badgeColor.opacity(0.85),
                                        CourtLinkTheme.primaryGreen
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 220)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: facility.imageSystemName)
                                        .font(.system(size: 64))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text("\(facility.courtsCount) \(facility.sport.courtUnit)s Available")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            )
                        
                        // Sport Pill Badge
                        HStack {
                            Text(facility.sport.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(20)
                            Spacer()
                        }
                        .padding(16)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Venue Header Info
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text(facility.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                dataStore.toggleFavorite(facilityId: facility.id)
                            }) {
                                Image(systemName: dataStore.isFavorite(facilityId: facility.id) ? "heart.fill" : "heart")
                                    .font(.title3)
                                    .foregroundColor(dataStore.isFavorite(facilityId: facility.id) ? .red : .secondary)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(CourtLinkTheme.primaryGreen)
                            Text("\(facility.address) • \(facility.area)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text(String(format: "%.1f", facility.rating))
                                    .font(.subheadline.bold())
                                Text("(\(facility.reviewsCount) reviews)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(facility.openingHours)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Quick Specs Bar
                    HStack(spacing: 16) {
                        SpecBox(title: "Price", value: "\(facility.formattedPrice)/hr", icon: "tag.fill")
                        SpecBox(title: "Capacity", value: "\(facility.courtsCount) \(facility.sport.courtUnit)s", icon: "square.grid.2x2.fill")
                        SpecBox(title: "Status", value: "Available", icon: "checkmark.circle.fill")
                    }
                    .padding(.horizontal)
                    
                    // Amenities Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Amenities & Features")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(facility.amenities, id: \.self) { amenity in
                                HStack(spacing: 8) {
                                    Image(systemName: amenityIcon(for: amenity))
                                        .font(.caption)
                                        .foregroundColor(CourtLinkTheme.primaryGreen)
                                        .frame(width: 20)
                                    Text(amenity)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // About Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About this venue")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(facility.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal)
                    
                    // Spacer for bottom sticky bar
                    Color.clear.frame(height: 90)
                }
            }
            
            // Sticky Bottom CTA Bar (Figma Design)
            VStack(spacing: 0) {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Total Price")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(facility.formattedPrice)
                            .font(.title3)
                            .fontWeight(.heavy)
                            .foregroundColor(CourtLinkTheme.primaryGreen)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        navigateToBooking = true
                    }) {
                        HStack(spacing: 8) {
                            Text("Check Availability & Book")
                                .font(.headline)
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(CourtLinkTheme.orangeButtonGradient)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: CourtLinkTheme.accentOrange.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
            }
        }
        .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToBooking) {
            SlotBookingView(facility: facility)
        }
    }
    
    private func amenityIcon(for name: String) -> String {
        switch name.lowercased() {
        case let n where n.contains("parking"): return "car.fill"
        case let n where n.contains("locker"): return "lock.fill"
        case let n where n.contains("shower"): return "shower.fill"
        case let n where n.contains("wi-fi") || n.contains("wifi"): return "wifi"
        case let n where n.contains("cafe") || n.contains("refresh"): return "cup.and.saucer.fill"
        case let n where n.contains("equipment") || n.contains("racket"): return "tennis.racket"
        case let n where n.contains("light"): return "lightbulb.fill"
        default: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Spec Box
struct SpecBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(CourtLinkTheme.primaryGreen)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

