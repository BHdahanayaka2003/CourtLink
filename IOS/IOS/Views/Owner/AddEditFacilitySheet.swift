//
//  AddEditFacilitySheet.swift
//  CourtLink
//
//  Dedicated form to Add a New Stadium / Facility or Edit an existing one,
//  syncing directly to Firebase Firestore.
//

import SwiftUI
import CoreLocation

struct AddEditFacilitySheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var dataStore: CourtLinkDataStore
    
    // Existing facility if editing, nil if adding new
    let existingFacility: Facility?
    
    @State private var name: String = ""
    @State private var selectedSport: SportType = .badminton
    @State private var address: String = ""
    @State private var area: String = "Colombo 07"
    @State private var priceText: String = "1500"
    @State private var courtsCount: Int = 2
    @State private var openingHours: String = "06:00 AM - 10:00 PM"
    @State private var description: String = ""
    @State private var selectedAmenities: Set<String> = ["Parking", "Locker Room", "Showers"]
    
    // Real map location (replaces the old random coordinates)
    @State private var latitude: Double = 6.9080
    @State private var longitude: Double = 79.8660
    @State private var hasPickedLocation: Bool = false
    @State private var showLocationPicker: Bool = false
    /// Last values we filled from the map, so we never overwrite something the owner typed themselves
    @State private var autoFilledName: String = ""
    @State private var autoFilledFromMap: Bool = false
    
    @State private var isSaving: Bool = false
    @State private var showSuccessAlert: Bool = false
    @State private var errorMessage: String = ""
    
    let availableAmenities = [
        "Parking", "Locker Room", "Equipment Rental", "Showers",
        "Wi-Fi", "Cafeteria", "Floodlights", "First Aid", "Spectator Seating"
    ]
    
    init(facility: Facility? = nil) {
        self.existingFacility = facility
        if let f = facility {
            _name = State(initialValue: f.name)
            _selectedSport = State(initialValue: f.sport)
            _address = State(initialValue: f.address)
            _area = State(initialValue: f.area)
            _priceText = State(initialValue: "\(f.pricePerHour)")
            _courtsCount = State(initialValue: f.courtsCount)
            _openingHours = State(initialValue: f.openingHours)
            _description = State(initialValue: f.description)
            _selectedAmenities = State(initialValue: Set(f.amenities))
            _latitude = State(initialValue: f.latitude)
            _longitude = State(initialValue: f.longitude)
            _hasPickedLocation = State(initialValue: true)
        }
    }
    
    var isEditing: Bool {
        existingFacility != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Stadium / Facility Details
                Section(header: Text("Stadium Information")) {
                    TextField("Stadium / Facility Name (e.g. Royal Arena)", text: $name)
                    
                    Picker("Sport Type", selection: $selectedSport) {
                        ForEach(SportType.allCases) { sport in
                            HStack {
                                Image(systemName: sport.iconName)
                                Text(sport.rawValue)
                            }
                            .tag(sport)
                        }
                    }
                    
                    TextField("Street Address", text: $address)
                    TextField("District / Area (e.g. Colombo 07, Dehiwala)", text: $area)
                }
                
                // Exact map location
                Section(header: Text("Location on Map"), footer: Text(autoFilledFromMap
                    ? "Name, address and area were filled in from the map. You can still edit them."
                    : "Pick the spot on the map and the name and address are filled in for you.")) {
                    Button(action: { showLocationPicker = true }) {
                        HStack {
                            Image(systemName: hasPickedLocation ? "mappin.circle.fill" : "mappin.and.ellipse")
                                .foregroundColor(hasPickedLocation ? CourtLinkTheme.primaryGreen : CourtLinkTheme.accentOrange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hasPickedLocation ? "Location set" : "Pick location on map")
                                    .foregroundColor(.primary)
                                if hasPickedLocation {
                                    Text(String(format: "%.5f, %.5f", latitude, longitude))
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                
                // Pricing & Court Count
                Section(header: Text("Courts & Pricing")) {
                    HStack {
                        Text("Hourly Rate (Rs.)")
                        Spacer()
                        TextField("Price", text: $priceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Stepper("Number of Courts: \(courtsCount)", value: $courtsCount, in: 1...20)
                    
                    TextField("Operating Hours", text: $openingHours)
                }
                
                // Amenities Selection
                Section(header: Text("Amenities Available")) {
                    ForEach(availableAmenities, id: \.self) { amenity in
                        Button(action: {
                            if selectedAmenities.contains(amenity) {
                                selectedAmenities.remove(amenity)
                            } else {
                                selectedAmenities.insert(amenity)
                            }
                        }) {
                            HStack {
                                Text(amenity)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedAmenities.contains(amenity) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(CourtLinkTheme.primaryGreen)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Description
                Section(header: Text("Description & Rules")) {
                    TextEditor(text: $description)
                        .frame(height: 90)
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                // Submit Button
                Section {
                    Button(action: saveFacility) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isEditing ? "Update Stadium in Database" : "Save Stadium to Database")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 50)
                        .background(isSaving ? Color.gray : CourtLinkTheme.primaryGreen)
                        .cornerRadius(14)
                    }
                    .listRowInsets(EdgeInsets())
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle(isEditing ? "Edit Stadium" : "Add New Stadium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(
                    title: "Stadium Location",
                    initial: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    onConfirmPlace: { place in
                        applyPickedPlace(place)
                    }
                )
            }
            .alert("Success!", isPresented: $showSuccessAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text(isEditing ? "Stadium details updated in database!" : "New stadium has been successfully added to the database and is live for bookings!")
            }
        }
    }
    
    /// Copies the map selection into the form. Address and area always follow the pin;
    /// the name is only replaced if it is empty or was auto-filled earlier.
    private func applyPickedPlace(_ place: PickedPlace) {
        latitude = place.coordinate.latitude
        longitude = place.coordinate.longitude
        hasPickedLocation = true
        errorMessage = ""
        
        if !place.address.isEmpty { address = place.address }
        if !place.area.isEmpty { area = place.area }
        
        if let placeName = place.name, !placeName.isEmpty {
            let current = name.trimmingCharacters(in: .whitespaces)
            if current.isEmpty || current == autoFilledName {
                name = placeName
                autoFilledName = placeName
            }
        }
        autoFilledFromMap = true
    }
    
    private func saveFacility() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a stadium name."
            return
        }
        
        guard hasPickedLocation else {
            errorMessage = "Please set the stadium location on the map."
            return
        }
        
        let price = Int(priceText) ?? 1500
        isSaving = true
        errorMessage = ""
        
        if let existing = existingFacility {
            // Update Existing
            var updated = existing
            updated.name = trimmedName
            updated.sport = selectedSport
            updated.address = address
            updated.area = area
            updated.pricePerHour = price
            updated.courtsCount = courtsCount
            updated.openingHours = openingHours
            updated.description = description.isEmpty ? "Premium \(selectedSport.rawValue) facility in \(area)." : description
            updated.amenities = Array(selectedAmenities)
            updated.latitude = latitude
            updated.longitude = longitude
            
            dataStore.updateFacility(facility: updated)
            isSaving = false
            showSuccessAlert = true
        } else {
            // Add New Facility
            let newId = "fac-\(Int.random(in: 100...999))"
            let newFacility = Facility(
                id: newId,
                name: trimmedName,
                sport: selectedSport,
                address: address.isEmpty ? "Colombo, Sri Lanka" : address,
                area: area.isEmpty ? "Colombo" : area,
                latitude: latitude,
                longitude: longitude,
                pricePerHour: price,
                rating: 5.0,
                reviewsCount: 1,
                openingHours: openingHours.isEmpty ? "06:00 AM - 10:00 PM" : openingHours,
                amenities: Array(selectedAmenities),
                description: description.isEmpty ? "Modern \(selectedSport.rawValue) facility with all required equipment." : description,
                courtsCount: courtsCount,
                imageSystemName: selectedSport.iconName,
                isFeatured: true
            )
            
            dataStore.addFacility(facility: newFacility)
            isSaving = false
            showSuccessAlert = true
        }
    }
}

#Preview {
    AddEditFacilitySheet()
        .environmentObject(CourtLinkDataStore())
}
