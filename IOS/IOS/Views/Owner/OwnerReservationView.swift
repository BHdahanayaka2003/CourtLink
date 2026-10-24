//
//  OwnerReservationsView.swift
//  CourtLink
//
//  Owner-only screen: every reservation together with the customer's
//  username and name. Customers can never reach this screen, and the data
//  store returns an empty list for non-owner accounts.
//

import SwiftUI

struct OwnerReservationsView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    @State private var selectedTab: ReservationFilter = .upcoming
    @State private var searchText: String = ""
    @State private var bookingToCancel: Booking? = nil
    @State private var showCancelAlert = false
    
    enum ReservationFilter: String, CaseIterable {
        case upcoming = "Upcoming"
        case past = "Past"
    }
    
    private var filteredBookings: [Booking] {
        let base = dataStore.ownerVisibleBookings.filter {
            selectedTab == .upcoming ? $0.status == .confirmed : $0.status != .confirmed
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.customerUsername.lowercased().contains(query) ||
            $0.customerName.lowercased().contains(query) ||
            $0.facilityName.lowercased().contains(query) ||
            $0.id.lowercased().contains(query)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Reservations", selection: $selectedTab) {
                    ForEach(ReservationFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                if filteredBookings.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 54))
                            .foregroundColor(.secondary)
                        Text("No \(selectedTab.rawValue.lowercased()) reservations")
                            .font(.headline)
                        Text("Customer reservations for your facilities will appear here.")
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
                                OwnerReservationCard(booking: booking) {
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
            .navigationTitle("Reservations")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search username, name or facility")
            .alert("Cancel Reservation?", isPresented: $showCancelAlert, presenting: bookingToCancel) { booking in
                Button("Keep", role: .cancel) { }
                Button("Yes, Cancel", role: .destructive) {
                    dataStore.cancelBooking(bookingId: booking.id)
                }
            } message: { booking in
                Text("Cancel \(booking.customerName)'s reservation at \(booking.facilityName) for \(booking.timeSlot)?")
            }
        }
    }
}

// MARK: - Owner Reservation Card
struct OwnerReservationCard: View {
    let booking: Booking
    let onCancel: () -> Void
    
    private var usernameText: String {
        booking.customerUsername.isEmpty ? "—" : "@\(booking.customerUsername)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Customer identity (username + name + phone)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(CourtLinkTheme.primaryGreen.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.fill")
                        .foregroundColor(CourtLinkTheme.primaryGreen)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(usernameText)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(booking.customerName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !booking.customerPhone.isEmpty {
                        Text(booking.customerPhone)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
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
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: booking.sport.iconName)
                        .foregroundColor(booking.sport.badgeColor)
                        .font(.caption.bold())
                    Text(booking.facilityName)
                        .font(.headline)
                    Text("• #\(booking.id)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(CourtLinkTheme.primaryGreen)
                    Text("\(booking.formattedDate) • \(booking.timeSlot)")
                        .font(.caption.bold())
                }
            }
            
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
                        Text("Cancel")
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
    OwnerReservationsView()
        .environmentObject(CourtLinkDataStore())
}
//
//  OwnerReservationView.swift
//  IOS
//
//  Created by Cobsccomp251p-062 on 2026-10-24.
//

