//
//  Facility.swift
//  CourtLink
//

import SwiftUI
import CoreLocation

struct Facility: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var sport: SportType
    var address: String
    var area: String
    var latitude: Double
    var longitude: Double
    var pricePerHour: Int 
    var rating: Double
    var reviewsCount: Int
    var openingHours: String
    var amenities: [String]
    var description: String
    var courtsCount: Int
    var imageSystemName: String
    var isFeatured: Bool
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var formattedPrice: String {
        "Rs. \(pricePerHour)"
    }
}
