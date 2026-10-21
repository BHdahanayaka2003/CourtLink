//
//  FaceIDSettingsCard.swift
//  CourtLink
//
//  Profile / settings card: turn Face ID login on or off for the signed-in account.
//

import SwiftUI

struct FaceIDSettingsCard: View {
    @EnvironmentObject var auth: AuthService

    @State private var showPasswordSheet = false
    @State private var password = ""
    @State private var isWorking = false

    var body: some View {
        if auth.biometricsAvailable {
            HStack(spacing: 12) {
                Image(systemName: "faceid")
                    .font(.title2)
                    .foregroundColor(CourtLinkTheme.primaryGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(auth.biometryName) Login").font(.headline)
                    Text("Log in quickly and securely on this device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { auth.faceIDActiveOnThisDevice },
                    set: { newValue in
                        if newValue {
                            password = ""
                            auth.errorMessage = nil
                            showPasswordSheet = true
                        } else {
                            auth.disableFaceID()
                        }
                    }
                ))
                .labelsHidden()
                .tint(CourtLinkTheme.primaryGreen)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .padding(.horizontal)
            .sheet(isPresented: $showPasswordSheet) { passwordSheet }
        }
    }

    private var passwordSheet: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Confirm your password once. It is then locked in the iPhone Keychain behind \(auth.biometryName).")) {
                    SecureField("Current password", text: $password)
                }
                if let message = auth.errorMessage {
                    Section { Text(message).foregroundColor(.red).font(.caption) }
                }
                Section {
                    Button {
                        isWorking = true
                        Task {
                            let ok = await auth.enableFaceIDVerifyingPassword(password)
                            isWorking = false
                            if ok { showPasswordSheet = false }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isWorking { ProgressView() }
                            Text("Enable \(auth.biometryName)").bold()
                            Spacer()
                        }
                    }
                    .disabled(password.isEmpty || isWorking)
                }
            }
            .navigationTitle("Enable \(auth.biometryName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPasswordSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
