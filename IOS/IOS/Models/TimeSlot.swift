//
//  TimeSlot.swift
//  CourtLink
//

import Foundation

enum DayPeriod: String, CaseIterable, Identifiable, Codable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }
}

struct TimeSlot: Identifiable, Hashable, Codable {
    let id: String
    let timeLabel: String // e.g. "06:00 PM - 07:00 PM"
    let startTimeString: String // "18:00"
    let period: DayPeriod
    var isAvailable: Bool
    var isBlockedByOwner: Bool
    
    init(
        id: String = UUID().uuidString,
        timeLabel: String,
        startTimeString: String,
        period: DayPeriod,
        isAvailable: Bool = true,
        isBlockedByOwner: Bool = false
    ) {
        self.id = id
        self.timeLabel = timeLabel
        self.startTimeString = startTimeString
        self.period = period
        self.isAvailable = isAvailable
        self.isBlockedByOwner = isBlockedByOwner
    }
}
