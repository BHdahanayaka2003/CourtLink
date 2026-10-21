//
//  Court.swift
//  CourtLink
//
//  Every court / pitch / lane now has a stable identity and its own map coordinate.
//

import SwiftUI
import CoreLocation

enum CourtStatus {
    case available
    case needsAttention   // open minor/moderate fault - still bookable
    case closed           // open critical fault - not bookable

    var color: Color {
        switch self {
        case .available: return CourtLinkTheme.statusSuccess
        case .needsAttention: return CourtLinkTheme.statusWarning
        case .closed: return CourtLinkTheme.statusError
        }
    }

    var title: String {
        switch self {
        case .available: return "Available"
        case .needsAttention: return "Needs Attention"
        case .closed: return "Closed - Faulty"
        }
    }

    var badgeIcon: String {
        switch self {
        case .available: return "checkmark"
        case .needsAttention: return "exclamationmark"
        case .closed: return "xmark"
        }
    }
}

struct Court: Identifiable, Hashable, Codable {
    /// Stable identity, e.g. "fac-1-C2". Never changes, so faults always point to the same court.
    let id: String
    let facilityId: String
    let number: Int
    var latitude: Double
    var longitude: Double
    /// true when the owner pinned this court manually; false when auto-placed near the facility
    var isCustomLocation: Bool = false

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func makeId(facilityId: String, number: Int) -> String {
        "\(facilityId)-C\(number)"
    }

    /// Human readable code such as "DSC-C2" (District Sport Complex, court 2)
    static func code(for facility: Facility, number: Int) -> String {
        let initials = facility.name
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(3)
            .map { String($0).uppercased() }
            .joined()
        return "\(initials.isEmpty ? "CRT" : initials)-C\(number)"
    }

    /// Auto-placement: courts are laid out on a small grid (~22 m spacing) around the
    /// facility coordinate so each one is a distinct, tappable point until the owner pins it.
    static func generated(for facility: Facility, number: Int) -> Court {
        let total = max(facility.courtsCount, 1)
        let cols = Int(ceil(sqrt(Double(total))))
        let index = number - 1
        let row = index / cols
        let col = index % cols
        let spacing = 0.00020
        let lat = facility.latitude - Double(row) * spacing
        let lon = facility.longitude + (Double(col) - Double(cols - 1) / 2.0) * spacing
        return Court(
            id: makeId(facilityId: facility.id, number: number),
            facilityId: facility.id,
            number: number,
            latitude: lat,
            longitude: lon,
            isCustomLocation: false
        )
    }
}
