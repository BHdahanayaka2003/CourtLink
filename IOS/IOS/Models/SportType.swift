//
//  SportType.swift
//  CourtLink
//

import SwiftUI

enum SportType: String, CaseIterable, Identifiable, Codable {
    case badminton = "Badminton"
    case tennis = "Tennis"
    case futsal = "Futsal"
    case swimming = "Swimming"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .badminton: return "figure.badminton"
        case .tennis: return "figure.tennis"
        case .futsal: return "figure.indoor.soccer"
        case .swimming: return "figure.pool.swim"
        }
    }
    
    var badgeColor: Color {
        switch self {
        case .badminton: return Color(red: 0.12, green: 0.60, blue: 0.40)
        case .tennis: return Color(red: 0.85, green: 0.55, blue: 0.10)
        case .futsal: return Color(red: 0.25, green: 0.45, blue: 0.85)
        case .swimming: return Color(red: 0.15, green: 0.65, blue: 0.85)
        }
    }
    
    var courtUnit: String {
        switch self {
        case .badminton, .tennis: return "Court"
        case .futsal: return "Pitch"
        case .swimming: return "Lane"
        }
    }
}
