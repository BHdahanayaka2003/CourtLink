//
//  LocationService.swift
//  CourtLink
//
//  Thin CoreLocation wrapper used for "use my current location" and on-site fault verification.
//

import Foundation
import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Human readable name of where the user currently is (e.g. "Bambalapitiya, Colombo")
    @Published var placeName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocoded: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Ask for permission if needed, otherwise request a fresh one-shot location.
    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    /// Distance in metres between the user and a coordinate (nil if no fix yet)
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let location else { return nil }
        return location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Looks up a readable place name, but only when the user moved more than ~300 m.
    private func reverseGeocodeIfNeeded(_ loc: CLLocation) {
        if let previous = lastGeocoded, previous.distance(from: loc) < 300 { return }
        lastGeocoded = loc
        geocoder.reverseGeocodeLocation(loc) { [weak self] marks, _ in
            guard let mark = marks?.first else { return }
            let parts = [mark.subLocality, mark.locality].compactMap { $0 }
            let name = parts.isEmpty ? (mark.name ?? "") : parts.joined(separator: ", ")
            Task { @MainActor in
                self?.placeName = name.isEmpty ? nil : name
            }
        }
    }

    // MARK: CLLocationManagerDelegate
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in
            self.location = last
            self.reverseGeocodeIfNeeded(last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
