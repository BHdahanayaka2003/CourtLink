//
//  OnboardingView.swift
//  CourtLink
//

import SwiftUI

enum UserRole: String, CaseIterable, Identifiable {
    case player = "Sports Player"
    case owner = "Facility Owner"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .player: return "figure.badminton"
        case .owner: return "building.2.crop.circle.fill"
        }
    }
}

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @EnvironmentObject var dataStore: CourtLinkDataStore
    
    @State private var selectedRole: UserRole = .player
    
    var body: some View {
        ZStack {
            // Background Dark Forest Green / Stadium Vibe
            CourtLinkTheme.heroGradient
                .ignoresSafeArea()
            
            // Court Lines Graphic Overlay
            VStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 4)
                    .frame(width: 380, height: 380)
                    .offset(x: 100, y: -60)
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Hero Visual & Logo
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(CourtLinkTheme.accentOrange)
                            .frame(width: 86, height: 86)
                            .shadow(color: CourtLinkTheme.accentOrange.opacity(0.4), radius: 16, x: 0, y: 8)
                        
                        Image(systemName: selectedRole == .player ? "figure.badminton" : "building.2.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedRole)
                    }
                    
                    Text("CourtLink")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Text("SRI LANKA'S SPORTS BOOKING PLATFORM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.65))
                        .tracking(2)
                }
                .padding(.bottom, 28)
                
                Spacer()
                
                // Bottom Content Card (Dual Role Support)
                VStack(spacing: 18) {
                    // Role Selector Segment (Player vs Facility Owner)
                    HStack(spacing: 0) {
                        ForEach(UserRole.allCases) { role in
                            let isSelected = selectedRole == role
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    selectedRole = role
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: role.iconName)
                                        .font(.caption.bold())
                                    Text(role.rawValue)
                                        .font(.caption.bold())
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(isSelected ? (role == .player ? CourtLinkTheme.accentOrange : CourtLinkTheme.primaryGreen) : Color.clear)
                                .foregroundColor(isSelected ? .white : .secondary)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .padding(.top, 4)
                    
                    // Dynamic Header based on Role
                    VStack(spacing: 8) {
                        if selectedRole == .player {
                            Text("Book your court in seconds")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("Find and book badminton courts, tennis, futsal and swimming pools around you with real-time slot availability.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                                .lineSpacing(3)
                        } else {
                            Text("Facility Owner Dashboard")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("Manage bookings, open or block time slots for maintenance, and monitor your facility revenue in real time.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 10)
                                .lineSpacing(3)
                        }
                    }
                    
                    // Primary Action Button
                    if selectedRole == .player {
                        Button(action: {
                            enterAsPlayer()
                        }) {
                            HStack(spacing: 8) {
                                Text("Get Started as Player")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(CourtLinkTheme.orangeButtonGradient)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: CourtLinkTheme.accentOrange.opacity(0.35), radius: 10, x: 0, y: 5)
                        }
                    } else {
                        Button(action: {
                            enterAsOwner()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "building.2.crop.circle.fill")
                                    .font(.title3)
                                Text("Enter as Facility Owner")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(CourtLinkTheme.heroGradient)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: CourtLinkTheme.primaryGreen.opacity(0.35), radius: 10, x: 0, y: 5)
                        }
                    }
                    
                    // Quick Direct Switch Button
                    Button(action: {
                        if selectedRole == .player {
                            enterAsOwner()
                        } else {
                            enterAsPlayer()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(selectedRole == .player ? "Are you a venue owner?" : "Looking to book a court?")
                                .foregroundColor(.secondary)
                            Text(selectedRole == .player ? "Go to Owner Mode" : "Go to Player Mode")
                                .fontWeight(.bold)
                                .foregroundColor(selectedRole == .player ? CourtLinkTheme.primaryGreen : CourtLinkTheme.accentOrange)
                        }
                        .font(.caption)
                    }
                    .padding(.bottom, 6)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: -4)
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
    
    private func enterAsPlayer() {
        dataStore.isOwnerMode = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isOnboardingCompleted = true
        }
    }
    
    private func enterAsOwner() {
        dataStore.isOwnerMode = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isOnboardingCompleted = true
        }
    }
}

#Preview {
    OnboardingView(isOnboardingCompleted: .constant(false))
        .environmentObject(CourtLinkDataStore())
}
