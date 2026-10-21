//
//  IOSApp.swift
//  IOS
//
//  Created by Cobsccomp251p-062 on 2026-10-03.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        print("Firebase configured successfully!")
        return true
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
