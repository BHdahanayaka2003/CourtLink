//
//  MyBookingsView.swift
//  CourtLink
//

import SwiftUI

struct MyBookingsView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @State private var selectedTab: BookingFilter = .upcoming
    @State private var bookingToCancel: Booking? = nil
    @State private var showCancelAlert = false
    
    enum BookingFilter: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
    }
    
    var filteredBookings: [Booking] {
        switch selectedTab {
        case .upcoming:
            return dataStore.bookings.filter { $0.status == .confirmed }
        case .past:
            return dataStore.bookings.filter { $0.status != .confirmed }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control (Figma Screen 8)
                Picker("Bookings", selection: $selectedTab) {
                    ForEach(BookingFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                // Bookings List
                if filteredBookings.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 54))
                            .foregroundColor(.secondary)
                        Text("No \(selectedTab.rawValue.lowercased()) bookings")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Book your first court from the Explore tab in seconds.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredBookings) { booking in
                                BookingCard(booking: booking) {
                                    bookingToCancel = booking
                                    showCancelAlert = true
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
            .navigationTitle("My Bookings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Cancel Booking?", isPresented: $showCancelAlert, presenting: bookingToCancel) { booking in
                Button("Keep Booking", role: .cancel) { }
                Button("Yes, Cancel", role: .destructive) {
                    dataStore.cancelBooking(bookingId: booking.id)
                }
            } message: { booking in
                Text("Are you sure you want to cancel your slot at \(booking.facilityName) for \(booking.timeSlot)? The slot will be released for other players.")
            }
        }
    }
}

// MARK: - Booking Card (Figma Screen 8)
struct BookingCard: View {
    let booking: Booking
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Booking ID & Status
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: booking.sport.iconName)
                        .foregroundColor(booking.sport.badgeColor)
                        .font(.caption.bold())
                    Text(booking.sport.rawValue)
                        .font(.caption.bold())
                        .foregroundColor(booking.sport.badgeColor)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("#\(booking.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(booking.status.rawValue)
                    .font(.caption.bold())
                    .foregroundColor(booking.status.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(booking.status.backgroundColor)
                    .cornerRadius(8)
            }
            
            Divider()
            
            // Facility & Time Information
            VStack(alignment: .leading, spacing: 6) {
                Text(booking.facilityName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(CourtLinkTheme.primaryGreen)
                    Text(booking.facilityAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(CourtLinkTheme.primaryGreen)
                    Text("\(booking.formattedDate) • \(booking.timeSlot)")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }
            }
            
            // Footer: Court & Price + Cancel Action
            HStack {
                Text("\(booking.sport.courtUnit) \(booking.courtNumber)")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Text("Rs. \(booking.price)")
                    .font(.subheadline.bold())
                    .foregroundColor(CourtLinkTheme.primaryGreen)
                
                Spacer()
                
                if booking.status == .confirmed {
                    Button(action: onCancel) {
                        Text("Cancel Booking")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

#Preview {
    MyBookingsView()
        .environmentObject(CourtLinkDataStore())
}
