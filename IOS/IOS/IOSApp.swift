//
//  IOSApp.swift
//  IOS
//
//  Created by Cobsccomp251p-062 on 2026-10-03.
//

import SwiftUI
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        print("Firebase configured successfully!")

        // Request notification permission and register the delegate
        NotificationService.shared.requestPermission()
        UNUserNotificationCenter.current().delegate = NotificationService.shared

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationService.shared.clearBadge()
    }
}
#endif

@main
struct IOSApp: App {
    #if canImport(FirebaseCore)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
