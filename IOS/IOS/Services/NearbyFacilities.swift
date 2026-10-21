//
//  NearbyFacilities.swift
//  CourtLink
//
//  Distance helpers used by the customer screens to rank courts nearest-first.
//

import Foundation
import CoreLocation

/// A facility paired with its distance (in metres) from the customer.
struct NearbyFacility: Identifiable {
    let facility: Facility
    let distance: CLLocationDistance?
    var id: String { facility.id }

    var distanceText: String? {
        distance.map { NearbyFacility.format($0) }
    }

    /// "350 m" under 1 km, "2.4 km" under 10 km, "14 km" beyond.
    static func format(_ metres: CLLocationDistance) -> String {
        if metres < 1000 { return "\(Int((metres / 10).rounded()) * 10) m" }
        let km = metres / 1000
        return km < 10 ? String(format: "%.1f km", km) : String(format: "%.0f km", km)
    }

    /// Rough walking / driving time hint, e.g. "~6 min walk" or "~12 min drive".
    var travelHint: String? {
        guard let d = distance else { return nil }
        if d <= 1500 { return "~\(max(1, Int((d / 80).rounded()))) min walk" }   // ~4.8 km/h
        return "~\(max(2, Int((d / 400).rounded()))) min drive"                  // ~24 km/h city traffic
    }
}

extension Array where Element == Facility {
    /// Returns the facilities ordered nearest-first. Without a location fix the original
    /// order is kept and every distance is nil.
    func rankedByDistance(from location: CLLocation?) -> [NearbyFacility] {
        guard let location else { return map { NearbyFacility(facility: $0, distance: nil) } }
        return map { f in
            NearbyFacility(
                facility: f,
                distance: location.distance(from: CLLocation(latitude: f.latitude, longitude: f.longitude))
            )
        }
        .sorted { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
    }
}
