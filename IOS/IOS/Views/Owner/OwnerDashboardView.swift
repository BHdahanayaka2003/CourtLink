//
//  OwnerDashboardView.swift
//  CourtLink
//

import SwiftUI

struct OwnerDashboardView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @State private var selectedDate = Date()
    @State private var navigateToManageFacility = false
    
    var facility: Facility {
        dataStore.ownerFacility ?? dataStore.facilities[0]
    }
    
    var todaySlots: [TimeSlot] {
        dataStore.getTimeSlots(for: facility.id, on: selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    // Owner Greeting Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Good morning, \(dataStore.userName.components(separatedBy: " ").first ?? "Owner") 👋")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("\(facility.name) • \(facility.area)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            navigateToManageFacility = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.headline)
                                .foregroundColor(CourtLinkTheme.primaryGreen)
                                .padding(10)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Metrics Hero Banner (Figma Screen 9)
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TODAY'S REVENUE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .tracking(1)
                                Text("Rs. \(dataStore.ownerTodayRevenue)")
                                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right")
                                Text("+18%")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                        
                        Divider()
                            .overlay(Color.white.opacity(0.2))
                        
                        HStack {
                            OwnerStatItem(title: "Today's Bookings", value: "\(dataStore.ownerTodayBookings.count)")
                            Spacer()
                            OwnerStatItem(title: "Active Courts", value: "\(facility.courtsCount)")
                            Spacer()
                            OwnerStatItem(title: "Fill Rate", value: "85%")
                        }
                    }
                    .padding(20)
                    .background(CourtLinkTheme.heroGradient)
                    .cornerRadius(24)
                    .padding(.horizontal)
                    .shadow(color: CourtLinkTheme.primaryGreen.opacity(0.3), radius: 12, x: 0, y: 6)
                    
                    // Court Availability Manager (Screen 9 / Screen 12 from Figma)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Court Availability & Blocking")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("Tap any slot to block/unblock for maintenance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(todaySlots.prefix(8)) { slot in
                                let dateKey = DateFormatter.localizedString(from: selectedDate, dateStyle: .short, timeStyle: .none)
                                let isBlocked = dataStore.isSlotBlocked(facilityId: facility.id, dateString: dateKey, slotId: slot.id)
                                
                                Button(action: {
                                    dataStore.toggleBlockSlot(facilityId: facility.id, dateString: dateKey, slotId: slot.id)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(slot.startTimeString)
                                                .font(.headline)
                                                .foregroundColor(isBlocked ? .red : .primary)
                                            Text(isBlocked ? "Blocked" : "Open")
                                                .font(.caption2.bold())
                                                .foregroundColor(isBlocked ? .red : CourtLinkTheme.statusSuccess)
                                        }
                                        Spacer()
                                        Image(systemName: isBlocked ? "lock.fill" : "lock.open.fill")
                                            .foregroundColor(isBlocked ? .red : CourtLinkTheme.primaryGreen)
                                            .font(.caption)
                                    }
                                    .padding(12)
                                    .background(isBlocked ? Color.red.opacity(0.08) : Color(.systemBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isBlocked ? Color.red.opacity(0.4) : Color(.systemGray5), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Today's Bookings Live Feed
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Today's Reservations")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        if dataStore.ownerTodayBookings.isEmpty {
                            Text("No reservations scheduled for today.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(dataStore.ownerTodayBookings) { booking in
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(CourtLinkTheme.primaryGreen.opacity(0.12))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "person.fill")
                                                .foregroundColor(CourtLinkTheme.primaryGreen)
                                                .font(.subheadline)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(booking.customerName)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.primary)
                                            Text("\(booking.sport.courtUnit) \(booking.courtNumber) • \(booking.timeSlot)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text("Rs. \(booking.price)")
                                                .font(.subheadline.bold())
                                                .foregroundColor(CourtLinkTheme.primaryGreen)
                                            Text(booking.status.rawValue)
                                                .font(.caption2.bold())
                                                .foregroundColor(booking.status.color)
                                        }
                                    }
                                    .padding(14)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                    .padding(.horizontal)
                                    .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
                                }
                            }
                        }
                    }
                    
                    // Quick Action: Manage Facility Profile
                    Button(action: {
                        navigateToManageFacility = true
                    }) {
                        HStack {
                            Image(systemName: "pencil.and.outline")
                            Text("Edit Facility Profile & Rates")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .foregroundColor(CourtLinkTheme.primaryGreen)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
            .navigationTitle("Owner Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToManageFacility) {
                OwnerManageFacilityView(facility: facility)
            }
        }
    }
}

struct OwnerStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

#Preview {
    OwnerDashboardView()
        .environmentObject(CourtLinkDataStore())
}
