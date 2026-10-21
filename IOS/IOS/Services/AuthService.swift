//
//  AuthService.swift
//  CourtLink
//
//  Login / sign-up / Face ID.
//  - Passwords:  Firebase Authentication (salted + hashed by Firebase, never stored by the app)
//  - Profiles:   Firestore  users/{uid}  (username, name, phone, role, faceIDEnabled)
//  - Face ID:    LocalAuthentication + Keychain (secret stays on the device)
//
//  Firebase Auth needs an email, so the username is mapped to "<username>@courtlink.app".
//

import SwiftUI
import Combine
import LocalAuthentication
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum AuthFailure: LocalizedError {
    case backendMissing
    case message(String)

    var errorDescription: String? {
        switch self {
        case .backendMissing:
            return "FirebaseAuth is not linked. In Xcode add the FirebaseAuth package product to the IOS target."
        case .message(let text):
            return text
        }
    }
}

struct PendingFaceIDOffer: Equatable {
    let username: String
    let password: String
}

final class AuthService: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isRestoring: Bool = true
    @Published var isBusy: Bool = false
    @Published var errorMessage: String?
    @Published var faceIDOffer: PendingFaceIDOffer?

    private let lastFaceIDKey = "lastFaceIDUsername"
    private let emailDomain = "courtlink.app"

    init() {
        Task { await restoreSession() }
    }

    // MARK: - Biometric helpers
    var biometricsAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var biometryName: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType == .touchID ? "Touch ID" : "Face ID"
    }

    var lastFaceIDUsername: String? {
        UserDefaults.standard.string(forKey: lastFaceIDKey)
    }

    /// Face ID login button is shown only when a locked secret exists on this device.
    var canUseFaceIDLogin: Bool {
        guard biometricsAvailable, let name = lastFaceIDUsername else { return false }
        return BiometricKeychain.exists(account: name)
    }

    /// True when the signed-in user has Face ID enabled on THIS device.
    var faceIDActiveOnThisDevice: Bool {
        guard let user = currentUser else { return false }
        return user.faceIDEnabled && BiometricKeychain.exists(account: user.username.lowercased())
    }

    // MARK: - Session
    func restoreSession() async {
        defer { isRestoring = false }
        #if canImport(FirebaseAuth)
        guard let fbUser = Auth.auth().currentUser else { return }
        let uname = (fbUser.email ?? "").components(separatedBy: "@").first ?? ""
        if let profile = try? await fetchProfile(uid: fbUser.uid) {
            currentUser = profile
        } else {
            currentUser = fallbackProfile(uid: fbUser.uid, username: uname)
        }
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
        currentUser = nil
        faceIDOffer = nil
        errorMessage = nil
    }

    // MARK: - Log in
    @discardableResult
    func signIn(username: String, password: String) async -> Bool {
        let uname = username.trimmingCharacters(in: .whitespaces)
        guard !uname.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your username and password."
            return false
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let uid: String
            do {
                uid = try await backendSignIn(email: pseudoEmail(uname), password: password)
            } catch let signInError {
                // First run: create the default owner account when its credentials are used.
                guard isDefaultOwner(uname, password: password) else { throw signInError }
                do {
                    uid = try await backendCreate(email: pseudoEmail(uname), password: password)
                } catch {
                    throw signInError
                }
            }

            var profile = try? await fetchProfile(uid: uid)
            if profile == nil {
                let created = fallbackProfile(uid: uid, username: uname)
                try? await saveProfile(created)
                profile = created
            }
            currentUser = profile

            if biometricsAvailable && !BiometricKeychain.exists(account: uname.lowercased()) {
                faceIDOffer = PendingFaceIDOffer(username: uname, password: password)
            }
            return true
        } catch {
            errorMessage = friendlyMessage(error)
            return false
        }
    }

    // MARK: - Customer sign-up
    @discardableResult
    func registerCustomer(
        fullName: String,
        username: String,
        email: String,
        phone: String,
        password: String,
        confirmPassword: String,
        shouldEnableFaceID: Bool
    ) async -> Bool {
        let uname = username.trimmingCharacters(in: .whitespaces)
        let name = fullName.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else { errorMessage = "Please enter your full name."; return false }
        guard isValidUsername(uname) else {
            errorMessage = "Username must be 3-20 characters: letters, numbers, dot or underscore."
            return false
        }
        guard uname.lowercased() != DefaultOwner.username.lowercased() else {
            errorMessage = "That username is reserved. Please choose another."
            return false
        }
        guard password.count >= 6 else { errorMessage = "Password must be at least 6 characters."; return false }
        guard password == confirmPassword else { errorMessage = "Passwords do not match."; return false }

        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let uid = try await backendCreate(email: pseudoEmail(uname), password: password)
            let profile = AppUser(
                id: uid,
                username: uname,
                fullName: name,
                email: email.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces),
                role: .customer,
                faceIDEnabled: false
            )
            do {
                try await saveProfile(profile)
            } catch {
                print("Profile save failed (check Firestore rules): \(error.localizedDescription)")
            }
            currentUser = profile
            if shouldEnableFaceID && biometricsAvailable {
                _ = await enableFaceID(username: uname, password: password)
            }
            return true
        } catch {
            errorMessage = friendlyMessage(error)
            return false
        }
    }

    // MARK: - Face ID
    @discardableResult
    func signInWithFaceID() async -> Bool {
        guard let uname = lastFaceIDUsername else {
            errorMessage = "Face ID is not set up on this device yet. Log in with your password first."
            return false
        }
        let context = LAContext()
        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Log in to CourtLink"
            )
        } catch {
            return false // cancelled or failed - stay on the login screen
        }
        guard let password = BiometricKeychain.load(account: uname, context: context) else {
            errorMessage = "Face ID login is no longer available. Please log in with your password."
            return false
        }
        return await signIn(username: uname, password: password)
    }

    @discardableResult
    func enableFaceID(username: String, password: String) async -> Bool {
        let uname = username.lowercased()
        let context = LAContext()
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            errorMessage = "\(biometryName) is not available on this device."
            return false
        }
        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Enable \(biometryName) for CourtLink"
            )
        } catch {
            return false
        }
        guard BiometricKeychain.save(password: password, account: uname) else {
            errorMessage = "Could not save \(biometryName) login. Make sure a device passcode is set."
            return false
        }
        UserDefaults.standard.set(uname, forKey: lastFaceIDKey)

        if var user = currentUser, user.username.lowercased() == uname {
            user.faceIDEnabled = true
            currentUser = user
            await updateFaceIDFlag(uid: user.id, enabled: true)
        }
        return true
    }

    /// Used by Settings: re-check the password, then enable Face ID.
    func enableFaceIDVerifyingPassword(_ password: String) async -> Bool {
        guard let user = currentUser else { return false }
        errorMessage = nil
        do {
            _ = try await backendSignIn(email: pseudoEmail(user.username), password: password)
        } catch {
            errorMessage = "Incorrect password."
            return false
        }
        return await enableFaceID(username: user.username, password: password)
    }

    func disableFaceID() {
        guard var user = currentUser else { return }
        BiometricKeychain.delete(account: user.username.lowercased())
        if lastFaceIDUsername == user.username.lowercased() {
            UserDefaults.standard.removeObject(forKey: lastFaceIDKey)
        }
        user.faceIDEnabled = false
        currentUser = user
        Task { await updateFaceIDFlag(uid: user.id, enabled: false) }
    }

    func acceptFaceIDOffer() {
        guard let offer = faceIDOffer else { return }
        faceIDOffer = nil
        Task { _ = await enableFaceID(username: offer.username, password: offer.password) }
    }

    func declineFaceIDOffer() {
        faceIDOffer = nil
    }

    // MARK: - Helpers
    private func pseudoEmail(_ username: String) -> String {
        "\(username.trimmingCharacters(in: .whitespaces).lowercased())@\(emailDomain)"
    }

    private func isValidUsername(_ username: String) -> Bool {
        let pattern = "^[A-Za-z0-9._]{3,20}$"
        return username.range(of: pattern, options: .regularExpression) != nil
    }

    private func isDefaultOwner(_ username: String, password: String) -> Bool {
        username.lowercased() == DefaultOwner.username.lowercased() && password == DefaultOwner.password
    }

    private func fallbackProfile(uid: String, username: String) -> AppUser {
        let isOwner = username.lowercased() == DefaultOwner.username.lowercased()
        return AppUser(
            id: uid,
            username: isOwner ? DefaultOwner.username : username,
            fullName: isOwner ? DefaultOwner.fullName : username,
            email: "",
            phone: "",
            role: isOwner ? .owner : .customer,
            faceIDEnabled: false
        )
    }

    private func friendlyMessage(_ error: Error) -> String {
        if let failure = error as? AuthFailure { return failure.errorDescription ?? "Something went wrong." }
        #if canImport(FirebaseAuth)
        let ns = error as NSError
        // Full details in the Xcode console (the real cause is often inside userInfo)
        print("AUTH ERROR code=\(ns.code) domain=\(ns.domain)\nuserInfo=\(ns.userInfo)")
        if ns.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: ns.code) {
            switch code {
            case .internalError:
                let detail = (ns.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription
                    ?? (ns.userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] as? [String: Any])?["message"] as? String
                    ?? ns.localizedDescription
                return "Firebase internal error (\(detail)). Check that Authentication > Email/Password is enabled in Firebase Console and that GoogleService-Info.plist matches your project."
            case .keychainError:
                return "Keychain error. In the Simulator, erase the simulator (Device > Erase All Content and Settings) or run on a real device."
            case .appNotAuthorized, .invalidAPIKey:
                return "Firebase API key or app is not authorised. Re-download GoogleService-Info.plist from Firebase Console."

            case .wrongPassword, .invalidCredential, .userNotFound, .invalidEmail:
                return "Incorrect username or password."
            case .emailAlreadyInUse:
                return "That username is already taken."
            case .weakPassword:
                return "Password is too weak. Use at least 6 characters."
            case .networkError:
                return "No internet connection. Please try again."
            case .tooManyRequests:
                return "Too many attempts. Please wait a moment and try again."
            case .operationNotAllowed:
                return "Email/Password sign-in is not enabled. Enable it in Firebase Console > Authentication > Sign-in method."
            default:
                break
            }
        }
        #endif
        return error.localizedDescription
    }

    // MARK: - Backend: Firebase Auth
    private func backendSignIn(email: String, password: String) async throws -> String {
        #if canImport(FirebaseAuth)
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user.uid
        #else
        throw AuthFailure.backendMissing
        #endif
    }

    private func backendCreate(email: String, password: String) async throws -> String {
        #if canImport(FirebaseAuth)
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user.uid
        #else
        throw AuthFailure.backendMissing
        #endif
    }

    // MARK: - Backend: Firestore profile
    private func fetchProfile(uid: String) async throws -> AppUser? {
        #if canImport(FirebaseFirestore)
        let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
        guard let d = snapshot.data() else { return nil }
        return AppUser(
            id: uid,
            username: d["username"] as? String ?? "",
            fullName: d["fullName"] as? String ?? "",
            email: d["email"] as? String ?? "",
            phone: d["phone"] as? String ?? "",
            role: AccountRole(rawValue: d["role"] as? String ?? "") ?? .customer,
            faceIDEnabled: d["faceIDEnabled"] as? Bool ?? false
        )
        #else
        return nil
        #endif
    }

    private func saveProfile(_ user: AppUser) async throws {
        #if canImport(FirebaseFirestore)
        try await Firestore.firestore().collection("users").document(user.id).setData([
            "uid": user.id,
            "username": user.username,
            "usernameLower": user.username.lowercased(),
            "fullName": user.fullName,
            "email": user.email,
            "phone": user.phone,
            "role": user.role.rawValue,
            "faceIDEnabled": user.faceIDEnabled,
            "createdAt": FieldValue.serverTimestamp()
        ])
        #endif
    }

    private func updateFaceIDFlag(uid: String, enabled: Bool) async {
        #if canImport(FirebaseFirestore)
        try? await Firestore.firestore().collection("users").document(uid).updateData([
            "faceIDEnabled": enabled
        ])
        #endif
    }
}

