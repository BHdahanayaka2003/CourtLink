//
//  NotificationService.swift
//  CourtLink
//
//  Manages all local push notifications for CourtLink.
//
//  Triggers:
//  ┌─────────────────────────────────────────────────────────────────────┐
//  │ CUSTOMER                                                            │
//  │  • Booking confirmed          – immediate                           │
//  │  • Booking reminder           – 1 hour before the slot starts       │
//  │  • Booking cancelled          – immediate                           │
//  │                                                                     │
//  │ OWNER                                                               │
//  │  • New booking at facility    – immediate                           │
//  │  • Court fault reported       – immediate                           │
//  │  • Fault status updated       – immediate                           │
//  └─────────────────────────────────────────────────────────────────────┘

import UserNotifications
import SwiftUI

// MARK: - Notification Category / Action identifiers
private enum Category {
    static let booking  = "BOOKING"
    static let fault    = "FAULT"
    static let owner    = "OWNER_BOOKING"
}

private enum ActionID {
    static let viewBooking = "VIEW_BOOKING"
    static let cancelBooking = "CANCEL_BOOKING"
    static let viewFault   = "VIEW_FAULT"
}

// MARK: - NotificationService
final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    @Published var permissionGranted: Bool = false

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permission Request
    /// Call once on app launch (inside AppDelegate / IOSApp).
    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
                if granted {
                    self?.registerCategories()
                }
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                }
            }
        }
        // Refresh current status without prompting
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.permissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Register Interactive Categories
    private func registerCategories() {
        // Customer booking actions
        let viewBookingAction = UNNotificationAction(
            identifier: ActionID.viewBooking,
            title: "View Booking",
            options: [.foreground]
        )
        let cancelBookingAction = UNNotificationAction(
            identifier: ActionID.cancelBooking,
            title: "Cancel Booking",
            options: [.destructive, .foreground]
        )
        let bookingCategory = UNNotificationCategory(
            identifier: Category.booking,
            actions: [viewBookingAction, cancelBookingAction],
            intentIdentifiers: [],
            options: []
        )

        // Owner fault actions
        let viewFaultAction = UNNotificationAction(
            identifier: ActionID.viewFault,
            title: "View Fault",
            options: [.foreground]
        )
        let faultCategory = UNNotificationCategory(
            identifier: Category.fault,
            actions: [viewFaultAction],
            intentIdentifiers: [],
            options: []
        )

        // Owner new-booking category (no extra actions needed)
        let ownerCategory = UNNotificationCategory(
            identifier: Category.owner,
            actions: [viewBookingAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([bookingCategory, faultCategory, ownerCategory])
    }

    // MARK: - UNUserNotificationCenterDelegate
    /// Show notifications even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped – action: \(response.actionIdentifier), info: \(userInfo)")
        completionHandler()
    }

    // MARK: - Badge Reset
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    // =========================================================
    // MARK: - CUSTOMER Notifications
    // =========================================================

    /// Fires immediately when a booking is confirmed.
    func notifyBookingConfirmed(booking: Booking) {
        let content = UNMutableNotificationContent()
        content.title = "✅ Booking Confirmed"
        content.body  = "\(booking.facilityName) — \(booking.timeSlot) on \(booking.formattedDate)"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = Category.booking
        content.userInfo = ["bookingId": booking.id]
        content.subtitle = "Court \(booking.courtNumber) • Rs. \(booking.price)"

        schedule(content: content, id: "booking-confirmed-\(booking.id)", delay: 1)
    }

    /// Fires 1 hour before the booked slot starts.
    func scheduleBookingReminder(booking: Booking) {
        guard let fireDate = slotStartDate(for: booking) else { return }
        let reminderDate = fireDate.addingTimeInterval(-3600) // 1 hour before

        // Only schedule if reminder is still in the future
        guard reminderDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "⏰ Upcoming Booking Reminder"
        content.body  = "\(booking.facilityName) starts in 1 hour — \(booking.timeSlot)"
        content.subtitle = "Court \(booking.courtNumber)"
        content.sound = .default
        content.categoryIdentifier = Category.booking
        content.userInfo = ["bookingId": booking.id]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "booking-reminder-\(booking.id)",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error = error {
                print("Reminder schedule error: \(error.localizedDescription)")
            }
        }
    }

    /// Fires immediately when a booking is cancelled.
    func notifyBookingCancelled(booking: Booking) {
        // Cancel the pending reminder for this booking
        center.removePendingNotificationRequests(
            withIdentifiers: ["booking-reminder-\(booking.id)"]
        )

        let content = UNMutableNotificationContent()
        content.title = "❌ Booking Cancelled"
        content.body  = "\(booking.facilityName) — \(booking.timeSlot) on \(booking.formattedDate) has been cancelled."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("cancel.caf"))
        content.categoryIdentifier = Category.booking
        content.userInfo = ["bookingId": booking.id]

        schedule(content: content, id: "booking-cancelled-\(booking.id)", delay: 1)
    }

    // =========================================================
    // MARK: - OWNER Notifications
    // =========================================================

    /// Fires when a new booking is made at the owner's facility.
    func notifyOwnerNewBooking(booking: Booking) {
        let content = UNMutableNotificationContent()
        content.title = "📋 New Booking Received"
        content.body  = "\(booking.customerName) booked Court \(booking.courtNumber) — \(booking.timeSlot) on \(booking.formattedDate)"
        content.subtitle = "\(booking.facilityName) • Rs. \(booking.price)"
        content.sound = .defaultCritical
        content.categoryIdentifier = Category.owner
        content.userInfo = ["bookingId": booking.id, "facilityId": booking.facilityId]

        schedule(content: content, id: "owner-new-booking-\(booking.id)", delay: 1)
    }

    /// Fires when a court fault is reported.
    func notifyOwnerFaultReported(fault: CourtFault, facilityName: String) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Court Fault Reported"
        content.body  = "Court \(fault.courtNumber) at \(facilityName): \(fault.category.rawValue) — \(fault.severity.title)"
        content.subtitle = fault.notes.isEmpty ? nil : fault.notes
        content.sound = .defaultCritical
        content.badge = 1
        content.categoryIdentifier = Category.fault
        content.userInfo = ["faultId": fault.id, "facilityId": fault.facilityId]

        schedule(content: content, id: "fault-reported-\(fault.id)", delay: 1)
    }

    /// Fires when a fault's status is updated (e.g. resolved / in-progress).
    func notifyOwnerFaultStatusUpdated(fault: CourtFault, facilityName: String) {
        let content = UNMutableNotificationContent()

        switch fault.status {
        case .resolved:
            content.title = "✅ Fault Resolved"
            content.body  = "Court \(fault.courtNumber) at \(facilityName): \(fault.category.rawValue) — \(fault.severity.title) has been resolved."
            content.sound = .default
        case .inProgress:
            content.title = "🔧 Fault In Progress"
            content.body  = "Repair started on Court \(fault.courtNumber) at \(facilityName): \(fault.category.rawValue.capitalized)"
            content.sound = .default
        case .reported:
            content.title = "📝 Fault Status Updated"
            content.body  = "Court \(fault.courtNumber) at \(facilityName): marked as Reported."
            content.sound = .default
        }

        content.categoryIdentifier = Category.fault
        content.userInfo = ["faultId": fault.id, "facilityId": fault.facilityId]

        schedule(content: content, id: "fault-status-\(fault.id)-\(fault.status.rawValue)", delay: 1)
    }

    // =========================================================
    // MARK: - Private helpers
    // =========================================================

    private func schedule(content: UNMutableNotificationContent, id: String, delay: TimeInterval) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("Notification schedule error (\(id)): \(error.localizedDescription)")
            }
        }
    }

    /// Parses the booked slot's start time from the booking date and timeSlot string.
    /// TimeSlot format: "06:00 PM - 07:00 PM"
    private func slotStartDate(for booking: Booking) -> Date? {
        let timeString = booking.timeSlot.components(separatedBy: " - ").first ?? ""
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let time = formatter.date(from: timeString) else { return nil }

        let bookingDay = Calendar.current.startOfDay(for: booking.date)
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(byAdding: timeComponents, to: bookingDay)
    }
}
