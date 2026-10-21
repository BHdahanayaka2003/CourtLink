//
//  CustomerProfileView.swift
//  CourtLink
//
//  Dedicated Profile Screen for Customers / Players (No Owner Mode visible).
//

import SwiftUI

struct CustomerProfileView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    @EnvironmentObject var authService: AuthService
    
    @State private var notificationsEnabled = true
    @State private var locationReminders = true
    @State private var showFirebaseTestSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Customer Profile Header Card
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(CourtLinkTheme.primaryGreen)
                                .frame(width: 80, height: 80)
                            
                            Text("BD")
                                .font(.title.bold())
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
                                Image(systemName: "figure.badminton")
                                Text("Player Account")
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                            .foregroundColor(CourtLinkTheme.primaryGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                    
                    // Player Activity Quick Stats
                    HStack(spacing: 12) {
                        PlayerStatCard(
                            title: "Bookings",
                            value: "\(dataStore.bookings.count)",
                            icon: "calendar.badge.clock",
                            color: CourtLinkTheme.primaryGreen
                        )
                        PlayerStatCard(
                            title: "Favorites",
                            value: "\(dataStore.favoriteFacilityIds.count)",
                            icon: "heart.fill",
                            color: .red
                        )
                        PlayerStatCard(
                            title: "Points",
                            value: "450",
                            icon: "flame.fill",
                            color: CourtLinkTheme.accentOrange
                        )
                    }
                    .padding(.horizontal)
                    
                    // Preferences & Settings List
                    VStack(spacing: 0) {
                        ToggleRow(icon: "bell.fill", title: "Booking Reminders & Push", isOn: $notificationsEnabled)
                        Divider().padding(.leading, 50)
                        ToggleRow(icon: "location.fill", title: "Arrival Check-in Prompt", isOn: $locationReminders)
                        Divider().padding(.leading, 50)
                        
                        NavigationLink(destination: MyBookingsView()) {
                            ProfileMenuRow(icon: "calendar", title: "My Reservations", detail: "\(dataStore.bookings.count) total")
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        Button(action: { showFirebaseTestSheet = true }) {
                            ProfileMenuRow(icon: "flame.fill", title: "Live Firestore Sync", detail: "Connected")
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
            .navigationTitle("Player Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFirebaseTestSheet) {
                FirebaseDebugSheet()
            }
        }
    }
}

struct PlayerStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    CustomerProfileView()
        .environmentObject(CourtLinkDataStore())
}
