//
//  BookingConfirmationView.swift
//  CourtLink
//

import SwiftUI

struct BookingConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    let booking: Booking
    @State private var addedToCalendar = false
    
    var body: some View {
        ZStack {
            CourtLinkTheme.backgroundLight
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Success Badge
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(CourtLinkTheme.statusSuccess.opacity(0.15))
                            .frame(width: 96, height: 96)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(CourtLinkTheme.statusSuccess)
                    }
                    
                    VStack(spacing: 6) {
                        Text("You're all set!")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Your court reservation is confirmed with the facility.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Detailed Receipt Card (Figma Screen 7)
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BOOKING REFERENCE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1)
                            Text("#\(booking.id)")
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Text(booking.status.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(booking.status.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(booking.status.backgroundColor)
                            .cornerRadius(12)
                    }
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        ReceiptRow(title: "Facility", value: booking.facilityName)
                        ReceiptRow(title: "Sport", value: "\(booking.sport.rawValue) (\(booking.sport.courtUnit) \(booking.courtNumber))")
                        ReceiptRow(title: "Date", value: booking.formattedDate)
                        ReceiptRow(title: "Time Slot", value: booking.timeSlot)
                        ReceiptRow(title: "Player", value: booking.customerName)
                        
                        Divider()
                        
                        HStack {
                            Text("Total Amount Paid")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("Rs. \(booking.price)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(CourtLinkTheme.primaryGreen)
                        }
                    }
                }
                .padding(20)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Add to Calendar Button
                    Button(action: {
                        withAnimation {
                            addedToCalendar = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: addedToCalendar ? "checkmark" : "calendar.badge.plus")
                            Text(addedToCalendar ? "Added to Calendar" : "Add to Calendar")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(addedToCalendar ? Color.green.opacity(0.15) : Color(.systemGray6))
                        .foregroundColor(addedToCalendar ? .green : .primary)
                        .cornerRadius(14)
                    }
                    
                    // Done Button (Figma Orange)
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(CourtLinkTheme.orangeButtonGradient)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(color: CourtLinkTheme.accentOrange.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

struct ReceiptRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}


