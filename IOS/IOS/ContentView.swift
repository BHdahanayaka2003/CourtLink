//
//  ContentView.swift
//  CourtLink
//
//  Created by Cobsccomp251p-062 on 2026-10-03.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dataStore = CourtLinkDataStore()
    @StateObject private var auth = AuthService()
    
    var body: some View {
        Group {
            if auth.isRestoring {
                ZStack {
                    CourtLinkTheme.heroGradient.ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            } else if let user = auth.currentUser {
                MainTabView()
                    .onAppear { apply(user) }
            } else {
                LoginView()
            }
        }
        .environmentObject(dataStore)
        .environmentObject(auth)
        .onChange(of: auth.currentUser) { _, user in
            if let user { apply(user) }
        }
        .alert(
            "Enable \(auth.biometryName)?",
            isPresented: Binding(
                get: { auth.faceIDOffer != nil },
                set: { if !$0 { auth.declineFaceIDOffer() } }
            )
        ) {
            Button("Enable") { auth.acceptFaceIDOffer() }
            Button("Not Now", role: .cancel) { auth.declineFaceIDOffer() }
        } message: {
            Text("Use \(auth.biometryName) to log in quickly next time.")
        }
    }
    
   
    private func apply(_ user: AppUser) {
        dataStore.userName = user.fullName.isEmpty ? user.username : user.fullName
        dataStore.userEmail = user.email.isEmpty ? "@\(user.username)" : user.email
        dataStore.userPhone = user.phone
        dataStore.isOwnerMode = (user.role == .owner)
    }
}

#Preview {
    ContentView()
}
