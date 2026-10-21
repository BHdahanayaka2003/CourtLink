//
//  SlotBookingView.swift
//  CourtLink
//

import SwiftUI

struct SlotBookingView: View {
    @EnvironmentObject var dataStore: CourtLinkDataStore
    let facility: Facility
    
    @State private var selectedDate: Date = Date()
    @State private var selectedSlot: TimeSlot? = nil
    @State private var selectedCourt: Int = 1
    @State private var confirmedBooking: Booking? = nil
    @State private var showConfirmation = false
    
    var datesForWeek: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }
    
    var slotsForDate: [TimeSlot] {
        dataStore.getTimeSlots(for: facility.id, on: selectedDate)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Venue Mini Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(facility.name)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        Text("\(facility.sport.rawValue) • \(facility.area) • \(facility.formattedPrice)/hour")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Court Selector Chips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select \(facility.sport.courtUnit)")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(1...facility.courtsCount, id: \.self) { court in
                                    let isClosed = !dataStore.isCourtBookable(facilityId: facility.id, number: court)
                                    Button(action: { if !isClosed { selectedCourt = court } }) {
                                        Text(isClosed ? "\(facility.sport.courtUnit) \(court) ⚠︎" : "\(facility.sport.courtUnit) \(court)")
                                            .font(.subheadline)
                                            .fontWeight(selectedCourt == court ? .bold : .medium)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedCourt == court ? CourtLinkTheme.primaryGreen : Color(.systemGray6))
                                            .foregroundColor(selectedCourt == court ? .white : .primary)
                                            .cornerRadius(12)
                                            .opacity(isClosed ? 0.4 : 1)
                                    }
                                    .disabled(isClosed)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Horizontal Date Selector (Figma Design)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select Date")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(datesForWeek, id: \.self) { date in
                                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                                    Button(action: {
                                        selectedDate = date
                                        selectedSlot = nil
                                    }) {
                                        DatePill(date: date, isSelected: isSelected)
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Slots Sections (Morning, Afternoon, Evening)
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Available Time Slots")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(DayPeriod.allCases) { period in
                            let periodSlots = slotsForDate.filter { $0.period == period }
                            if !periodSlots.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 6) {
                                        Image(systemName: period.iconName)
                                            .foregroundColor(CourtLinkTheme.primaryGreen)
                                            .font(.caption)
                                        Text(period.rawValue)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal)
                                    
                                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                        ForEach(periodSlots) { slot in
                                            let isSelected = selectedSlot?.id == slot.id
                                            Button(action: {
                                                if slot.isAvailable {
                                                    selectedSlot = slot
                                                }
                                            }) {
                                                SlotPill(slot: slot, isSelected: isSelected)
                                            }
                                            .disabled(!slot.isAvailable)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Spacer for bottom sticky bar
                    Color.clear.frame(height: 110)
                }
            }
            
            // Bottom Sticky Bar (Figma Design)
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: 12) {
                    if let slot = selectedSlot {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(formatShortDate(selectedDate)) • \(slot.timeLabel)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Text("\(facility.sport.courtUnit) \(selectedCourt) • Total: \(facility.formattedPrice)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        guard let slot = selectedSlot else { return }
                        let booking = dataStore.bookSlot(
                            facility: facility,
                            date: selectedDate,
                            slot: slot,
                            courtNumber: selectedCourt
                        )
                        confirmedBooking = booking
                        showConfirmation = true
                    }) {
                        HStack(spacing: 8) {
                            Text(selectedSlot == nil ? "Select a Slot to Continue" : "Confirm Booking • \(facility.formattedPrice)")
                                .font(.headline)
                                .fontWeight(.bold)
                            if selectedSlot != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selectedSlot != nil ? CourtLinkTheme.orangeButtonGradient : LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .shadow(color: selectedSlot != nil ? CourtLinkTheme.accentOrange.opacity(0.35) : Color.clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(selectedSlot == nil)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
            }
        }
        .background(CourtLinkTheme.backgroundLight.ignoresSafeArea())
        .navigationTitle("Choose a Slot")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showConfirmation) {
            if let booking = confirmedBooking {
                BookingConfirmationView(booking: booking)
            }
        }
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Date Pill (Horizontal picker)
struct DatePill: View {
    let date: Date
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayName)
                .font(.caption2.bold())
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            
            Text(dayNumber)
                .font(.title3.bold())
                .foregroundColor(isSelected ? .white : .primary)
            
            Text(monthName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .frame(width: 58, height: 76)
        .background(isSelected ? CourtLinkTheme.primaryGreen : Color(.systemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.clear : Color(.systemGray5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.02), radius: 4, x: 0, y: 2)
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}

// MARK: - Slot Pill
struct SlotPill: View {
    let slot: TimeSlot
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.timeLabel)
                    .font(.caption.bold())
                    .foregroundColor(textColor)
                
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundColor(statusTextColor)
            }
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1.5)
        )
    }
    
    private var textColor: Color {
        if isSelected { return .white }
        if !slot.isAvailable { return .secondary }
        return .primary
    }
    
    private var statusText: String {
        if isSelected { return "Selected" }
        if slot.isBlockedByOwner { return "Blocked" }
        if !slot.isAvailable { return "Booked" }
        return "Available"
    }
    
    private var statusTextColor: Color {
        if isSelected { return .white.opacity(0.85) }
        if !slot.isAvailable { return .secondary }
        return CourtLinkTheme.statusSuccess
    }
    
    private var backgroundColor: Color {
        if isSelected { return CourtLinkTheme.accentOrange }
        if !slot.isAvailable { return Color(.systemGray6) }
        return Color(.systemBackground)
    }
    
    private var borderColor: Color {
        if isSelected { return CourtLinkTheme.accentOrange }
        if !slot.isAvailable { return Color.clear }
        return Color(.systemGray5)
    }
}

#Preview {
    NavigationStack {
        SlotBookingView(
            facility: Facility(
                id: "fac-1",
                name: "District Sport Complex",
                sport: .badminton,
                address: "Albert Crescent",
                area: "Colombo 07",
                latitude: 6.908,
                longitude: 79.866,
                pricePerHour: 1500,
                rating: 4.8,
                reviewsCount: 142,
                openingHours: "06:00 AM - 10:00 PM",
                amenities: ["Parking", "Locker Room", "Equipment Rental", "Showers"],
                description: "State-of-the-art wooden flooring indoor courts.",
                courtsCount: 4,
                imageSystemName: "sportscourt.fill",
                isFeatured: true
            )
        )
        .environmentObject(CourtLinkDataStore())
    }
}
