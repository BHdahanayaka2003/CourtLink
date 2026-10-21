//
//  CourtLinkTheme.swift
//  CourtLink - iOS Application Development
//
//  Design system matching Figma: Forest Green primary, Vibrant Orange accent,
//  clean card elevations, and modern typography.
//

import SwiftUI

struct CourtLinkTheme {
    // Primary Brand Colors
    static let primaryGreen = Color(red: 0.075, green: 0.306, blue: 0.208) // #134E35 (Figma Emerald Green)
    static let primaryGreenLight = Color(red: 0.12, green: 0.42, blue: 0.30)
    static let accentOrange = Color(red: 0.98, green: 0.42, blue: 0.12) // #FA6B1F (Figma CTA Orange)
    static let accentOrangeLight = Color(red: 1.0, green: 0.93, blue: 0.88)
    
    // Backgrounds & Surfaces
    static let backgroundLight = Color(red: 0.97, green: 0.975, blue: 0.98)
    static let cardBackground = Color(.systemBackground)
    static let secondaryCardBackground = Color(red: 0.94, green: 0.95, blue: 0.96)
    
    // Status Colors
    static let statusSuccess = Color(red: 0.15, green: 0.68, blue: 0.38)
    static let statusSuccessBg = Color(red: 0.90, green: 0.98, blue: 0.93)
    static let statusWarning = Color(red: 0.95, green: 0.60, blue: 0.10)
    static let statusError = Color(red: 0.92, green: 0.26, blue: 0.21)
    static let statusErrorBg = Color(red: 0.99, green: 0.92, blue: 0.92)
    
    // Gradients
    static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.22, blue: 0.15),
            Color(red: 0.09, green: 0.36, blue: 0.25)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let orangeButtonGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.45, blue: 0.15),
            Color(red: 0.95, green: 0.35, blue: 0.08)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - View Modifiers & Components
struct CourtLinkCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(CourtLinkTheme.cardBackground)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func courtLinkCard(padding: CGFloat = 16, cornerRadius: CGFloat = 16) -> some View {
        modifier(CourtLinkCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}
