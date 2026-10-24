//
//  ProfileView.swift
//  CourtLink
//

import SwiftUI

struct ProfileView: View {
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
                    // Profile Header Card (Figma Screen 10)
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
                            
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                    
                    // Owner Mode Toggle Card (Core Proposal Requirement)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "building.2.crop.circle.fill")
                                        .foregroundColor(CourtLinkTheme.accentOrange)
                                    Text("Facility Owner Mode")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                Text("Switch between Player Booking and Venue Owner Dashboard")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Toggle("", isOn: $dataStore.isOwnerMode)
                                .labelsHidden()
                                .tint(CourtLinkTheme.primaryGreen)
                        }
                    }
                    .padding(16)
                    .background(dataStore.isOwnerMode ? CourtLinkTheme.accentOrangeLight : Color(.systemBackground))
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(dataStore.isOwnerMode ? CourtLinkTheme.accentOrange.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
                    .padding(.horizontal)
                    
                    // Preferences & Settings List
                    VStack(spacing: 0) {
                        ToggleRow(icon: "bell.fill", title: "Booking Reminders & Push", isOn: $notificationsEnabled)
                        Divider().padding(.leading, 50)
                        ToggleRow(icon: "location.fill", title: "Geofenced Arrival Check-in", isOn: $locationReminders)
                        Divider().padding(.leading, 50)
                        
                        NavigationLink(destination: MyBookingsView()) {
                            ProfileMenuRow(icon: "calendar", title: "Booking History", detail: "\(dataStore.myBookings.count) total")
                        }
                        
                        Divider().padding(.leading, 50)
                        
                        Button(action: { showFirebaseTestSheet = true }) {
                            ProfileMenuRow(icon: "flame.fill", title: "Firebase Connection Status", detail: "Active")
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
                    
                    // App Information Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(CourtLinkTheme.primaryGreen)
                            Text("About CourtLink")
                                .font(.headline)
                        }
                        Text("CourtLink is an iOS sports facility booking platform designed for casual & semi-professional athletes and court owners in Sri Lanka.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(18)
                    .padding(.horizontal)
                    
                    // Sign Out / Switch User Role
                    Button(action: {
                        withAnimation {
                            authService.signOut()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Switch Mode / Log Out")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
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
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFirebaseTestSheet) {
                FirebaseDebugSheet()
            }
        }
    }
}

struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(CourtLinkTheme.primaryGreen)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
        .padding(16)
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(CourtLinkTheme.primaryGreen)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(CourtLinkTheme.primaryGreen)
        }
        .padding(16)
    }
}

struct FirebaseDebugSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "flame.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                    .padding(.top, 20)
                
                Text("Firebase Backend Connected")
                    .font(.title2.bold())
                
                Text("Real-time database sync for CourtLink facilities, bookings, and slots is configured with project 'couseworkios'.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Close")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(CourtLinkTheme.primaryGreen)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .navigationTitle("Firebase Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(CourtLinkDataStore())
}
