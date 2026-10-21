//
//  AppUser.swift
//  CourtLink
//

import Foundation

enum AccountRole: String, Codable {
    case owner
    case customer
}

/// Profile stored in Firestore `users/{uid}`. The password is NEVER stored here
/// (Firebase Authentication keeps only a salted hash on Google's servers).
struct AppUser: Equatable, Identifiable {
    let id: String          // Firebase Auth uid
    var username: String
    var fullName: String
    var email: String
    var phone: String
    var role: AccountRole
    var faceIDEnabled: Bool
}

/// Default facility-owner account requested for the project.
/// It is created automatically the first time these credentials are used to log in.
enum DefaultOwner {
    static let username = "Budhvin2003"
    static let password = "Himsanda"
    static let fullName = "Budhwin Dahanayaka"
}
