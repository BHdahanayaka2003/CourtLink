//
//  OwnerProfileView.swift
//  CourtLink
//
//  Dedicated Profile Screen for Facility Owners.
//

import SwiftUI

struct OwnerProfileView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @EnvironmentObject var authService: AuthService
    
    @State private var bookingAlertsEnabled = true
    @State private var autoConfirmEnabled = true
    @State private var showFirebaseTestSheet = false
    @State private var navigateToManage = false
    
    var facility: Facility {
        dataStore.ownerFacility ?? dataStore.facilities[0]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Owner Profile Header Card
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(CourtLinkTheme.heroGradient)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "building.2.fill")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 4) {
                            Text(dataStore.userName)
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            Text(dataStore.userEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Verified Venue Owner")
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(CourtLinkTheme.primaryGreen)
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                    
                    // Managed Venue Summary Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ASSIGNED FACILITY")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .tracking(1)
                                Text(facility.name)
                                    .font(.headline.bold())
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            
                            Button(action: { navigateToManage = true }) {
                                Text("Edit Venue")
                                    .font(.caption.bold())
                                    .foregroundColor(CourtLinkTheme.accentOrange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(CourtLinkTheme.accentOrangeLight)
                                    .cornerRadius(10)
                            }
                        }
                        
                        Divider()
                        
                        HStack(spacing: 16) {
                            OwnerVenueStat(title: "Location", value: facility.area)
                            Spacer()
                            OwnerVenueStat(title: "Courts", value: "\(facility.courtsCount) \(facility.sport.courtUnit)s")
                            Spacer()
                            OwnerVenueStat(title: "Rate", value: "\(facility.formattedPrice)/hr")
                        }
                    }
                    .padding(18)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                    
                    // Business & Operational Preferences
                    VStack(spacing: 0) {
                        ToggleRow(icon: "bell.badge.fill", title: "Instant Booking Push Alerts", isOn: $bookingAlertsEnabled)
                        Divider().padding(.leading, 50)
                        ToggleRow(icon: "checkmark.circle.fill", title: "Auto-Confirm Online Slots", isOn: $autoConfirmEnabled)
                        Divider().padding(.leading, 50)
                        
                        Button(action: { navigateToManage = true }) {
                            ProfileMenuRow(icon: "pencil.and.list.clipboard", title: "Update Facility Details", detail: "Edit")
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        Button(action: { showFirebaseTestSheet = true }) {
                            ProfileMenuRow(icon: "flame.fill", title: "Firestore Real-Time Sync", detail: "Connected")
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                    
                    
                    // Face ID login (per account)
                    FaceIDSettingsCard()
                    
                    // Log Out / Return to Open Page
                    Button(action: {
                        withAnimation {
                            authService.signOut()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out / Switch Account")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical, 12)
            }
            .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
            .navigationTitle("Owner Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToManage) {
                OwnerManageFacilityView(facility: facility)
            }
            .sheet(isPresented: $showFirebaseTestSheet) {
                FirebaseDebugSheet()
            }
        }
    }
}

struct OwnerVenueStat: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    OwnerProfileView()
        .environmentObject(CourtLinkDataStore())
}
