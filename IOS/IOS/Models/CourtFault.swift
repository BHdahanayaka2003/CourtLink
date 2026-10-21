//
//  CourtFault.swift
//  CourtLink
//
//  A fault is always attached to a specific court (courtId), so it is drawn
//  exactly where that court is on the map.
//

import SwiftUI
import CoreLocation

enum FaultCategory: String, CaseIterable, Identifiable, Codable {
    case surface = "Surface Damage"
    case lighting = "Lighting"
    case net = "Net / Goal Posts"
    case drainage = "Drainage / Leak"
    case equipment = "Equipment"
    case safety = "Safety Hazard"
    case other = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .surface: return "square.dashed"
        case .lighting: return "lightbulb.slash.fill"
        case .net: return "figure.badminton"
        case .drainage: return "drop.fill"
        case .equipment: return "wrench.and.screwdriver.fill"
        case .safety: return "exclamationmark.triangle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum FaultSeverity: Int, CaseIterable, Identifiable, Codable, Comparable {
    case minor = 1
    case moderate = 2
    case critical = 3

    var id: Int { rawValue }

    static func < (lhs: FaultSeverity, rhs: FaultSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .minor: return "Minor"
        case .moderate: return "Moderate"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .minor: return Color(red: 0.90, green: 0.70, blue: 0.10)
        case .moderate: return CourtLinkTheme.statusWarning
        case .critical: return CourtLinkTheme.statusError
        }
    }

    /// A critical fault closes the court for booking until it is resolved.
    var closesCourt: Bool { self == .critical }
}

enum FaultStatus: String, CaseIterable, Identifiable, Codable {
    case reported = "Reported"
    case inProgress = "In Progress"
    case resolved = "Resolved"

    var id: String { rawValue }
    var isOpen: Bool { self != .resolved }

    var iconName: String {
        switch self {
        case .reported: return "exclamationmark.circle.fill"
        case .inProgress: return "hammer.fill"
        case .resolved: return "checkmark.seal.fill"
        }
    }
}

struct CourtFault: Identifiable, Hashable, Codable {
    let id: String
    let facilityId: String
    let courtId: String
    let courtNumber: Int
    var category: FaultCategory
    var severity: FaultSeverity
    var notes: String
    var status: FaultStatus
    let reportedBy: String
    let reportedAt: Date
    var resolvedAt: Date?
    /// Court coordinate captured when the fault was reported (fallback if the court record is missing)
    let latitude: Double
    let longitude: Double
    /// true when the reporter's GPS was within ~150 m of the court at report time
    let verifiedOnSite: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
