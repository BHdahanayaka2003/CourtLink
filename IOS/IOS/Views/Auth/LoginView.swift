//
//  LoginView.swift
//  CourtLink
//
//  Log in (owner or customer) / customer sign-up, with Face ID quick login.
//

import SwiftUI
import Firebase

struct LoginView: View {
    @EnvironmentObject var auth: AuthService

    private enum Mode: String, CaseIterable { case login = "Log In", signup = "Sign Up" }
    private enum Field: Hashable { case username, password, fullName, phone, email, newPassword, confirm }

    @State private var mode: Mode = .login
    @FocusState private var focus: Field?

    // Log in
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false

    // Sign up
    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var wantsFaceID = true

    private var isInputValid: Bool {
        switch mode {
        case .login:
            return !username.isEmpty && !password.isEmpty
        case .signup:
            let emailValid = email.isEmpty || email.contains("@")
            return !fullName.isEmpty &&
                !username.isEmpty &&
                !newPassword.isEmpty &&
                newPassword.count >= 6 &&
                confirmPassword == newPassword &&
                emailValid
        }
    }

    var body: some View {
        ZStack {
            CourtLinkTheme.heroGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header

                    VStack(spacing: 18) {
                        Picker("", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: mode) { _, _ in auth.errorMessage = nil }

                        if mode == .login { loginForm } else { signupForm }

                        if let message = auth.errorMessage {
                            Label(message, systemImage: "exclamationmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundColor(CourtLinkTheme.statusError)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        primaryButton

                        if mode == .login && auth.canUseFaceIDLogin {
                            faceIDButton
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.2), radius: 16, y: 6)

                    Text(mode == .login
                         ? "Facility owners and players log in here."
                         : "Sign up as a player. Facility owner accounts are created by CourtLink.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 40)
            }
        }
        .onAppear {
            // Quick runtime diagnostic to surface common Firebase misconfiguration
            if FirebaseApp.app() == nil {
                #if DEBUG
                print("[LoginView] FirebaseApp is not configured. Call FirebaseApp.configure() at app launch and ensure GoogleService-Info.plist is included in the app target.")
                #endif
                auth.errorMessage = "Firebase is not configured. Ensure GoogleService-Info.plist matches your project and FirebaseApp.configure() is called at launch."
            }
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.white.opacity(0.15)).frame(width: 84, height: 84)
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.white)
            }
            Text("CourtLink")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text("Book courts. Manage facilities.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: Login form
    private var loginForm: some View {
        VStack(spacing: 14) {
            inputField(icon: "person.fill") {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }
            inputField(icon: "lock.fill") {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye").foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: Sign-up form
    private var signupForm: some View {
        VStack(spacing: 14) {
            inputField(icon: "person.text.rectangle.fill") {
                TextField("Full name", text: $fullName)
                    .focused($focus, equals: .fullName)
            }
            inputField(icon: "at") {
                TextField("Choose a username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .username)
            }
            inputField(icon: "phone.fill") {
                TextField("Phone (e.g. +94 77 123 4567)", text: $phone)
                    .keyboardType(.phonePad)
                    .focused($focus, equals: .phone)
            }
            inputField(icon: "envelope.fill") {
                TextField("Email (optional)", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .focused($focus, equals: .email)
            }
            inputField(icon: "lock.fill") {
                SecureField("Create password (min 6 characters)", text: $newPassword)
                    .textContentType(.newPassword)
                    .focused($focus, equals: .newPassword)
            }
            inputField(icon: "lock.rotation") {
                SecureField("Confirm password", text: $confirmPassword)
                    .textContentType(.password)
                    .focused($focus, equals: .confirm)
            }

            if auth.biometricsAvailable {
                Toggle(isOn: $wantsFaceID) {
                    Label("Log in with \(auth.biometryName)", systemImage: "faceid")
                        .font(.subheadline.bold())
                }
                .tint(CourtLinkTheme.primaryGreen)
            }
        }
    }

    // MARK: Buttons
    private var primaryButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if auth.isBusy { ProgressView().tint(.white) }
                Text(mode == .login ? "Log In" : "Create Account")
                    .font(.headline.bold())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(CourtLinkTheme.orangeButtonGradient)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .disabled(auth.isBusy || !isInputValid)
        .opacity(auth.isBusy || !isInputValid ? 0.7 : 1)
    }

    private var faceIDButton: some View {
        Button {
            Task { await auth.signInWithFaceID() }
        } label: {
            Label("Log in with \(auth.biometryName)", systemImage: "faceid")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(CourtLinkTheme.primaryGreen.opacity(0.1))
                .foregroundColor(CourtLinkTheme.primaryGreen)
                .cornerRadius(16)
        }
        .disabled(auth.isBusy)
    }

    // MARK: Helpers
    private func inputField<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(CourtLinkTheme.primaryGreen)
                .frame(width: 22)
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    private func submit() {
        focus = nil

        // Early validation
        auth.errorMessage = nil
        switch mode {
        case .login:
            if username.isEmpty || password.isEmpty {
                auth.errorMessage = "Enter both username and password."
                return
            }
        case .signup:
            let emailValid = email.isEmpty || email.contains("@")
            if fullName.isEmpty || username.isEmpty || newPassword.count < 6 || confirmPassword != newPassword || !emailValid {
                auth.errorMessage = "Please complete all required fields and ensure passwords match (min 6 chars)."
                return
            }
        }

        Task {
            if mode == .login {
                await auth.signIn(username: username, password: password)
            } else {
                await auth.registerCustomer(
                    fullName: fullName,
                    username: username,
                    email: email,
                    phone: phone,
                    password: newPassword,
                    confirmPassword: confirmPassword,
                    shouldEnableFaceID: wantsFaceID
                )
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(AuthService())
}
