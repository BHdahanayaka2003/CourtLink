//
//  LocationPickerView.swift
//  CourtLink
//
//  Owner picks an exact location: search a place, use GPS, or move the map under the pin.
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

/// Everything the form needs once the owner has chosen a spot on the map.
struct PickedPlace {
    var coordinate: CLLocationCoordinate2D
    /// Venue / point-of-interest name when one is known (e.g. "Royal Arena"); nil for a bare street pin.
    var name: String?
    /// Street-level address, e.g. "12 Galle Road"
    var address: String
    /// District / neighbourhood, e.g. "Bambalapitiya" or "Colombo 07"
    var area: String

    /// One-line summary shown under the map
    var summary: String {
        [name, address, area].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
    }

    /// Builds a place from a CoreLocation / MapKit placemark.
    static func from(_ mark: CLPlacemark, coordinate: CLLocationCoordinate2D, fallbackName: String? = nil) -> PickedPlace {
        let street = [mark.subThoroughfare, mark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        // Street if we have one, otherwise the placemark's own name (unless it is just the venue name)
        var addressParts: [String] = []
        if !street.isEmpty {
            addressParts.append(street)
        } else if let n = mark.name, n != fallbackName {
            addressParts.append(n)
        }
        if let sub = mark.subLocality, !addressParts.contains(sub) { addressParts.append(sub) }
        if let city = mark.locality, !addressParts.contains(city) { addressParts.append(city) }
        
        let area = mark.subLocality ?? mark.locality ?? mark.administrativeArea ?? ""
        let poi = fallbackName ?? mark.areasOfInterest?.first
        return PickedPlace(
            coordinate: coordinate,
            name: poi,
            address: addressParts.joined(separator: ", "),
            area: area
        )
    }
}

/// Turns the pin position into a readable place, cancelling stale lookups as the map moves.
@MainActor
final class PlaceResolver: ObservableObject {
    @Published var place: PickedPlace?
    @Published var isResolving = false

    private let geocoder = CLGeocoder()

    func resolve(_ coordinate: CLLocationCoordinate2D) {
        geocoder.cancelGeocode()
        isResolving = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] marks, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isResolving = false
                if let mark = marks?.first {
                    self.place = PickedPlace.from(mark, coordinate: coordinate)
                }
            }
        }
    }

    /// Use a search result exactly as MapKit describes it (has the real venue name).
    func use(_ item: MKMapItem) {
        geocoder.cancelGeocode()
        isResolving = false
        place = PickedPlace.from(item.placemark, coordinate: item.placemark.coordinate, fallbackName: item.name)
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()

    let title: String
    /// Called with the full place (name + address + area + coordinate)
    let onConfirmPlace: (PickedPlace) -> Void
    @StateObject private var resolver = PlaceResolver()

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D
    @State private var query: String = ""
    @State private var results: [MKMapItem] = []
    @State private var useSatellite: Bool = false
    @State private var waitingForGPS: Bool = false
    @State private var isSearching: Bool = false

    /// Coordinate-only convenience (used for pinning individual courts and fault reports).
    init(title: String, initial: CLLocationCoordinate2D, onConfirm: @escaping (CLLocationCoordinate2D) -> Void) {
        self.init(title: title, initial: initial, onConfirmPlace: { onConfirm($0.coordinate) })
    }

    /// Full-place version used by the facility form to auto-fill name and address.
    init(title: String, initial: CLLocationCoordinate2D, onConfirmPlace: @escaping (PickedPlace) -> Void) {
        self.title = title
        self.onConfirmPlace = onConfirmPlace
        _center = State(initialValue: initial)
        _position = State(initialValue: .region(
            MKCoordinateRegion(center: initial, span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $position) {
                    UserAnnotation()
                }
                .mapStyle(useSatellite ? MapStyle.hybrid : MapStyle.standard)
                .onMapCameraChange(frequency: .continuous) { context in
                    center = context.region.center
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    refreshPlace(at: context.region.center)
                }
                .ignoresSafeArea(edges: .bottom)

                // Fixed pin in the middle of the map: the map moves, the pin stays.
                VStack {
                    Spacer()
                    Image(systemName: "mappin")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(CourtLinkTheme.accentOrange)
                        .shadow(radius: 3)
                        .offset(y: -3)
                    Spacer()
                }
                .allowsHitTesting(false)

                VStack(spacing: 8) {
                    searchBar
                    if !results.isEmpty { resultsList }
                    Spacer()
                    bottomPanel
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { refreshPlace(at: center) }
            .onChange(of: locationService.location) { _, newValue in
                guard waitingForGPS, let loc = newValue else { return }
                waitingForGPS = false
                move(to: loc.coordinate, span: 0.002)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search address or place", text: $query)
                .submitLabel(.search)
                .onSubmit { Task { await search() } }
            if isSearching { ProgressView() }
            if !query.isEmpty {
                Button { query = ""; results = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.97))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.1), radius: 6, y: 2)
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(results.prefix(5), id: \.self) { item in
                Button {
                    resolver.use(item)
                    move(to: item.placemark.coordinate, span: 0.002)
                    results = []
                    query = item.name ?? query
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Unknown").font(.subheadline.bold()).foregroundColor(.primary)
                        Text(item.placemark.title ?? "").font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                Divider()
            }
        }
        .background(Color(.systemBackground).opacity(0.97))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.1), radius: 6, y: 2)
    }

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    waitingForGPS = true
                    locationService.request()
                    if let loc = locationService.location, locationService.isAuthorized {
                        waitingForGPS = false
                        move(to: loc.coordinate, span: 0.002)
                    }
                } label: {
                    Label("My Location", systemImage: "location.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(.systemGray6)).cornerRadius(10)
                }
                Button { useSatellite.toggle() } label: {
                    Label(useSatellite ? "Map" : "Satellite", systemImage: useSatellite ? "map" : "globe.asia.australia.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(.systemGray6)).cornerRadius(10)
                }
                Spacer()
                Text(String(format: "%.5f, %.5f", center.latitude, center.longitude))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            // Live preview of what will be filled into the form
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "text.badge.checkmark")
                    .foregroundColor(CourtLinkTheme.primaryGreen)
                if let place = resolver.place, !resolver.isResolving {
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = place.name, !name.isEmpty {
                            Text(name).font(.subheadline.bold())
                        }
                        Text(place.address.isEmpty ? "No street address found here" : place.address)
                            .font(.caption).foregroundColor(.secondary)
                        if !place.area.isEmpty {
                            Text(place.area).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Finding address…").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button {
                var place = resolver.place ?? PickedPlace(coordinate: center, name: nil, address: "", area: "")
                place.coordinate = center   // always the exact pin position
                onConfirmPlace(place)
                dismiss()
            } label: {
                Text("Confirm This Location")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(CourtLinkTheme.primaryGreen)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        .padding(.bottom, 8)
    }

    /// Re-resolve the address after the map settles, unless a searched venue is still under the pin.
    private func refreshPlace(at coordinate: CLLocationCoordinate2D) {
        if let current = resolver.place, !resolver.isResolving {
            let a = CLLocation(latitude: current.coordinate.latitude, longitude: current.coordinate.longitude)
            let b = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if current.name != nil, a.distance(from: b) < 25 { return }
        }
        resolver.resolve(coordinate)
    }

    private func move(to coordinate: CLLocationCoordinate2D, span: Double) {
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            ))
        }
        center = coordinate
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        if let response = try? await MKLocalSearch(request: request).start() {
            results = response.mapItems
        } else {
            results = []
        }
        isSearching = false
    }
}
