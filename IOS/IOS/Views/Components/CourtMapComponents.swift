//
//  CourtMapComponents.swift
//  CourtLink
//
//  Map pins that show court identity (number) and fault state.
//

import SwiftUI

struct CourtPin: View {
    let number: Int
    let status: CourtStatus
    var isFocused: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(status.color)
                    .frame(width: isFocused ? 38 : 30, height: isFocused ? 38 : 30)
                Text("\(number)")
                    .font(.system(size: isFocused ? 15 : 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)

            if status != .available {
                Image(systemName: status.badgeIcon)
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(Circle().fill(status == .closed ? CourtLinkTheme.statusError : CourtLinkTheme.statusWarning))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .offset(x: 6, y: -6)
            }
        }
        .animation(.spring(), value: isFocused)
    }
}

struct FaultSeverityBadge: View {
    let severity: FaultSeverity

    var body: some View {
        Text(severity.title)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(severity.color)
            .cornerRadius(6)
    }
}

struct FaultRow: View {
    let fault: CourtFault

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(fault.severity.color.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: fault.category.iconName)
                    .foregroundColor(fault.severity.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Court \(fault.courtNumber) • \(fault.category.rawValue)")
                        .font(.subheadline.bold())
                    FaultSeverityBadge(severity: fault.severity)
                }
                if !fault.notes.isEmpty {
                    Text(fault.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Label(fault.status.rawValue, systemImage: fault.status.iconName)
                    if fault.verifiedOnSite {
                        Label("On-site verified", systemImage: "location.fill")
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
