//
//  Booking.swift
//  CourtLink
//

import SwiftUI

enum BookingStatus: String, CaseIterable, Codable {
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var color: Color {
        switch self {
        case .confirmed: return CourtLinkTheme.statusSuccess
        case .completed: return Color.gray
        case .cancelled: return CourtLinkTheme.statusError
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .confirmed: return CourtLinkTheme.statusSuccessBg
        case .completed: return Color(.systemGray5)
        case .cancelled: return CourtLinkTheme.statusErrorBg
        }
    }
}

struct Booking: Identifiable, Hashable, Codable {
    let id: String // e.g. "CL-89241"
    let facilityId: String
    let facilityName: String
    let facilityAddress: String
    let sport: SportType
    let date: Date
    let timeSlot: String // "06:00 PM - 07:00 PM"
    let courtNumber: Int
    let price: Int
    var status: BookingStatus
    let customerName: String
    let customerPhone: String
    let createdAt: Date
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var isUpcoming: Bool {
        status == .confirmed && date >= Calendar.current.startOfDay(for: Date())
    }
}
