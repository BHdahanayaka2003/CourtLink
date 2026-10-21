//
//  CourtLinkDataStore.swift
//  CourtLink
//

import SwiftUI
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

class CourtLinkDataStore: ObservableObject {
    @Published var facilities: [Facility] = []
    @Published var bookings: [Booking] = []
    @Published var selectedSport: SportType? = nil
    @Published var favoriteFacilityIds: Set<String> = []
    
    // Owner Mode State
    @Published var isOwnerMode: Bool = false
    @Published var ownerFacilityId: String = "fac-1" // Primary facility ID
    @Published var ownerFacilityIds: Set<String> = ["fac-1"] // All facilities owned by this user
    
    // User Info
    @Published var userName: String = "Budhwin Dahanayaka"
    @Published var userEmail: String = "budhwin@courtlink.lk"
    @Published var userPhone: String = "+94 77 123 4567"
    
    // Blocked Slots cache: [FacilityId-DateString-SlotId: Bool]
    @Published var blockedSlots: Set<String> = []
    
    // Court identity + fault tracking (see CourtLinkDataStore+Courts.swift)
    @Published var customCourts: [String: Court] = [:]   // owner-pinned court locations, keyed by court id
    @Published var courtFaults: [CourtFault] = []
    
    init() {
        loadSampleFacilities()
        loadSampleBookings()
        loadSampleFaults()
        fetchFacilitiesFromFirestore()
        listenForCourtsAndFaults()
    }
    
    // MARK: - Sample Facilities (Sri Lanka Locations)
    private func loadSampleFacilities() {
        facilities = [
            Facility(
                id: "fac-1",
                name: "District Sport Complex",
                sport: .badminton,
                address: "Albert Crescent, Cinnamon Gardens",
                area: "Colombo 07",
                latitude: 6.9080,
                longitude: 79.8660,
                pricePerHour: 1500,
                rating: 4.8,
                reviewsCount: 142,
                openingHours: "06:00 AM - 10:00 PM",
                amenities: ["Parking", "Locker Room", "Equipment Rental", "Showers", "Wi-Fi", "Cafeteria"],
                description: "State-of-the-art wooden flooring indoor badminton courts with BWF certified LED lighting and modern spectator stands.",
                courtsCount: 4,
                imageSystemName: "sportscourt.fill",
                isFeatured: true
            ),
            Facility(
                id: "fac-2",
                name: "Apex Badminton Academy",
                sport: .badminton,
                address: "High Level Road",
                area: "Nugegoda",
                latitude: 6.8710,
                longitude: 79.8985,
                pricePerHour: 1200,
                rating: 4.6,
                reviewsCount: 98,
                openingHours: "07:00 AM - 11:00 PM",
                amenities: ["Parking", "Locker Room", "Equipment Rental", "Showers"],
                description: "Synthetic rubber courts ideal for high-speed rallies, coaching sessions, and casual weekly games.",
                courtsCount: 3,
                imageSystemName: "figure.badminton",
                isFeatured: false
            ),
            Facility(
                id: "fac-3",
                name: "CR&FC Futsal Pitch",
                sport: .futsal,
                address: "Malalasekara Mawatha",
                area: "Colombo 07",
                latitude: 6.9015,
                longitude: 79.8692,
                pricePerHour: 4500,
                rating: 4.9,
                reviewsCount: 215,
                openingHours: "06:00 AM - 12:00 AM",
                amenities: ["Parking", "Locker Room", "Floodlights", "Showers", "Refreshments"],
                description: "All-weather FIFA approved synthetic turf pitch with professional floodlighting and perimeter netting.",
                courtsCount: 2,
                imageSystemName: "figure.indoor.soccer",
                isFeatured: true
            ),
            Facility(
                id: "fac-4",
                name: "Colombo Futsal Arena",
                sport: .futsal,
                address: "Marine Drive",
                area: "Dehiwala",
                latitude: 6.8520,
                longitude: 79.8630,
                pricePerHour: 3800,
                rating: 4.5,
                reviewsCount: 88,
                openingHours: "07:00 AM - 11:00 PM",
                amenities: ["Parking", "Locker Room", "Showers", "Sea Breeze Cafe"],
                description: "Breezy seaside indoor turf court with spectator gallery and convenient parking.",
                courtsCount: 2,
                imageSystemName: "figure.indoor.soccer",
                isFeatured: false
            ),
            Facility(
                id: "fac-5",
                name: "Torrington Tennis Club",
                sport: .tennis,
                address: "Torrington Square",
                area: "Colombo 07",
                latitude: 6.9030,
                longitude: 79.8680,
                pricePerHour: 2200,
                rating: 4.7,
                reviewsCount: 110,
                openingHours: "06:00 AM - 09:00 PM",
                amenities: ["Parking", "Clay Courts", "Racket Restringing", "Locker Room"],
                description: "Classic red clay tennis courts maintained in tournament grade condition right in the heart of Torrington.",
                courtsCount: 3,
                imageSystemName: "figure.tennis",
                isFeatured: true
            ),
            Facility(
                id: "fac-6",
                name: "Colombo Swimming Club",
                sport: .swimming,
                address: "148 Galle Road",
                area: "Galle Face, Colombo 03",
                latitude: 6.9150,
                longitude: 79.8490,
                pricePerHour: 1800,
                rating: 4.9,
                reviewsCount: 175,
                openingHours: "06:00 AM - 09:00 PM",
                amenities: ["Parking", "Changing Rooms", "Life Guards", "Poolside Dining", "Sauna"],
                description: "Olympic length 50m heated pool overlooking the Indian Ocean with certified lifeguards and dedicated lap lanes.",
                courtsCount: 8,
                imageSystemName: "figure.pool.swim",
                isFeatured: true
            )
        ]
        favoriteFacilityIds = ["fac-1", "fac-3"]
    }
    
    // MARK: - Firestore Real-Time Listener
    func fetchFacilitiesFromFirestore() {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("facilities").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let documents = snapshot?.documents, !documents.isEmpty else { return }
            
            let firestoreFacilities = documents.compactMap { doc -> Facility? in
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let sportRaw = data["sport"] as? String,
                      let sport = SportType(rawValue: sportRaw) else { return nil }
                
                return Facility(
                    id: doc.documentID,
                    name: name,
                    sport: sport,
                    address: data["address"] as? String ?? "",
                    area: data["area"] as? String ?? "Colombo",
                    latitude: data["latitude"] as? Double ?? 6.9080,
                    longitude: data["longitude"] as? Double ?? 79.8660,
                    pricePerHour: data["pricePerHour"] as? Int ?? 1500,
                    rating: data["rating"] as? Double ?? 4.8,
                    reviewsCount: data["reviewsCount"] as? Int ?? 10,
                    openingHours: data["openingHours"] as? String ?? "06:00 AM - 10:00 PM",
                    amenities: data["amenities"] as? [String] ?? ["Parking", "Locker Room"],
                    description: data["description"] as? String ?? "",
                    courtsCount: data["courtsCount"] as? Int ?? 1,
                    imageSystemName: data["imageSystemName"] as? String ?? "sportscourt.fill",
                    isFeatured: data["isFeatured"] as? Bool ?? false
                )
            }
            
            DispatchQueue.main.async {
                for f in firestoreFacilities {
                    if let idx = self.facilities.firstIndex(where: { $0.id == f.id }) {
                        self.facilities[idx] = f
                    } else {
                        self.facilities.insert(f, at: 0)
                        self.ownerFacilityIds.insert(f.id)
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - Sample Bookings
    private func loadSampleBookings() {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let pastDate = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        
        bookings = [
            Booking(
                id: "CL-20491",
                facilityId: "fac-1",
                facilityName: "District Sport Complex",
                facilityAddress: "Albert Crescent, Colombo 07",
                sport: .badminton,
                date: tomorrow,
                timeSlot: "06:00 PM - 07:00 PM",
                courtNumber: 1,
                price: 1500,
                status: .confirmed,
                customerName: userName,
                customerPhone: userPhone,
                createdAt: today
            ),
            Booking(
                id: "CL-19882",
                facilityId: "fac-3",
                facilityName: "CR&FC Futsal Pitch",
                facilityAddress: "Malalasekara Mawatha, Colombo 07",
                sport: .futsal,
                date: calendar.date(byAdding: .day, value: 4, to: today) ?? today,
                timeSlot: "08:00 PM - 09:00 PM",
                courtNumber: 1,
                price: 4500,
                status: .confirmed,
                customerName: userName,
                customerPhone: userPhone,
                createdAt: today
            ),
            Booking(
                id: "CL-15401",
                facilityId: "fac-5",
                facilityName: "Torrington Tennis Club",
                facilityAddress: "Torrington Square, Colombo 07",
                sport: .tennis,
                date: pastDate,
                timeSlot: "05:00 PM - 06:00 PM",
                courtNumber: 2,
                price: 2200,
                status: .completed,
                customerName: userName,
                customerPhone: userPhone,
                createdAt: pastDate
            )
        ]
    }
    
    // MARK: - Helper Methods
    func toggleFavorite(facilityId: String) {
        if favoriteFacilityIds.contains(facilityId) {
            favoriteFacilityIds.remove(facilityId)
        } else {
            favoriteFacilityIds.insert(facilityId)
        }
    }
    
    func isFavorite(facilityId: String) -> Bool {
        favoriteFacilityIds.contains(facilityId)
    }
    
    func bookSlot(
        facility: Facility,
        date: Date,
        slot: TimeSlot,
        courtNumber: Int
    ) -> Booking {
        let newBookingId = "CL-\(Int.random(in: 10000...99999))"
        let booking = Booking(
            id: newBookingId,
            facilityId: facility.id,
            facilityName: facility.name,
            facilityAddress: facility.address,
            sport: facility.sport,
            date: date,
            timeSlot: slot.timeLabel,
            courtNumber: courtNumber,
            price: facility.pricePerHour,
            status: .confirmed,
            customerName: userName,
            customerPhone: userPhone,
            createdAt: Date()
        )
        bookings.insert(booking, at: 0)
        
        // Sync to Firestore if available
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("bookings").document(booking.id).setData([
            "id": booking.id,
            "facilityId": booking.facilityId,
            "facilityName": booking.facilityName,
            "sport": booking.sport.rawValue,
            "date": Timestamp(date: booking.date),
            "timeSlot": booking.timeSlot,
            "courtNumber": booking.courtNumber,
            "price": booking.price,
            "status": booking.status.rawValue,
            "customerName": booking.customerName,
            "createdAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Firestore booking sync error: \(error.localizedDescription)")
            } else {
                print("Booking synced to Firestore successfully!")
            }
        }
        #endif
        
        return booking
    }
    
    func cancelBooking(bookingId: String) {
        if let index = bookings.firstIndex(where: { $0.id == bookingId }) {
            bookings[index].status = .cancelled
            
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            db.collection("bookings").document(bookingId).updateData([
                "status": BookingStatus.cancelled.rawValue
            ])
            #endif
        }
    }
    
    // MARK: - Owner Mode Actions
    var ownerFacility: Facility? {
        facilities.first(where: { $0.id == ownerFacilityId }) ?? facilities.first
    }
    
    var ownerFacilities: [Facility] {
        let matched = facilities.filter { ownerFacilityIds.contains($0.id) }
        return matched.isEmpty ? [facilities[0]] : matched
    }
    
    var ownerTodayBookings: [Booking] {
        bookings.filter { $0.facilityId == ownerFacilityId }
    }
    
    var ownerTodayRevenue: Int {
        ownerTodayBookings
            .filter { $0.status == .confirmed || $0.status == .completed }
            .reduce(0) { $0 + $1.price }
    }
    
    // MARK: - Add New Facility (Firestore + Local)
    func addFacility(facility: Facility) {
        facilities.insert(facility, at: 0)
        ownerFacilityIds.insert(facility.id)
        ownerFacilityId = facility.id
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("facilities").document(facility.id).setData([
            "id": facility.id,
            "name": facility.name,
            "sport": facility.sport.rawValue,
            "address": facility.address,
            "area": facility.area,
            "latitude": facility.latitude,
            "longitude": facility.longitude,
            "pricePerHour": facility.pricePerHour,
            "rating": facility.rating,
            "reviewsCount": facility.reviewsCount,
            "openingHours": facility.openingHours,
            "amenities": facility.amenities,
            "description": facility.description,
            "courtsCount": facility.courtsCount,
            "imageSystemName": facility.imageSystemName,
            "isFeatured": facility.isFeatured,
            "createdAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Error saving facility to Firestore: \(error.localizedDescription)")
            } else {
                print("Facility successfully saved to Firestore!")
            }
        }
        #endif
    }
    
    // MARK: - Update Existing Facility (Firestore + Local)
    func updateFacility(facility: Facility) {
        if let index = facilities.firstIndex(where: { $0.id == facility.id }) {
            facilities[index] = facility
        }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("facilities").document(facility.id).setData([
            "id": facility.id,
            "name": facility.name,
            "sport": facility.sport.rawValue,
            "address": facility.address,
            "area": facility.area,
            "latitude": facility.latitude,
            "longitude": facility.longitude,
            "pricePerHour": facility.pricePerHour,
            "rating": facility.rating,
            "reviewsCount": facility.reviewsCount,
            "openingHours": facility.openingHours,
            "amenities": facility.amenities,
            "description": facility.description,
            "courtsCount": facility.courtsCount,
            "imageSystemName": facility.imageSystemName,
            "isFeatured": facility.isFeatured,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                print("Error updating facility in Firestore: \(error.localizedDescription)")
            } else {
                print("Facility successfully updated in Firestore!")
            }
        }
        #endif
    }
    
    // Legacy support alias
    func updateOwnerFacility(updated: Facility) {
        updateFacility(facility: updated)
    }
    
    // MARK: - Add Court to Facility (+ Add Court button)
    func addCourt(to facilityId: String) {
        if let index = facilities.firstIndex(where: { $0.id == facilityId }) {
            facilities[index].courtsCount += 1
            let updated = facilities[index]
            
            #if canImport(FirebaseFirestore)
            let db = Firestore.firestore()
            db.collection("facilities").document(facilityId).updateData([
                "courtsCount": updated.courtsCount
            ])
            #endif
        }
    }
    
    // MARK: - Delete Facility
    func deleteFacility(facilityId: String) {
        facilities.removeAll { $0.id == facilityId }
        courtFaults.removeAll { $0.facilityId == facilityId }
        ownerFacilityIds.remove(facilityId)
        if ownerFacilityId == facilityId, let first = ownerFacilities.first {
            ownerFacilityId = first.id
        }
        
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        db.collection("facilities").document(facilityId).delete()
        #endif
    }
    
    func toggleBlockSlot(facilityId: String, dateString: String, slotId: String) {
        let key = "\(facilityId)_\(dateString)_\(slotId)"
        if blockedSlots.contains(key) {
            blockedSlots.remove(key)
        } else {
            blockedSlots.insert(key)
        }
    }
    
    func isSlotBlocked(facilityId: String, dateString: String, slotId: String) -> Bool {
        blockedSlots.contains("\(facilityId)_\(dateString)_\(slotId)")
    }
    
    // MARK: - Generate Time Slots for a Date
    func getTimeSlots(for facilityId: String, on date: Date) -> [TimeSlot] {
        let dateKey = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        
        let rawSlots: [(String, String, DayPeriod)] = [
            // Morning
            ("06:00 AM - 07:00 AM", "06:00", .morning),
            ("07:00 AM - 08:00 AM", "07:00", .morning),
            ("08:00 AM - 09:00 AM", "08:00", .morning),
            ("09:00 AM - 10:00 AM", "09:00", .morning),
            ("10:00 AM - 11:00 AM", "10:00", .morning),
            
            // Afternoon
            ("12:00 PM - 01:00 PM", "12:00", .afternoon),
            ("01:00 PM - 02:00 PM", "13:00", .afternoon),
            ("02:00 PM - 03:00 PM", "14:00", .afternoon),
            ("03:00 PM - 04:00 PM", "15:00", .afternoon),
            ("04:00 PM - 05:00 PM", "16:00", .afternoon),
            
            // Evening
            ("05:00 PM - 06:00 PM", "17:00", .evening),
            ("06:00 PM - 07:00 PM", "18:00", .evening),
            ("07:00 PM - 08:00 PM", "19:00", .evening),
            ("08:00 PM - 09:00 PM", "20:00", .evening),
            ("09:00 PM - 10:00 PM", "21:00", .evening)
        ]
        
        return rawSlots.enumerated().map { index, slotTuple in
            let slotId = "slot-\(index)"
            let isBlocked = isSlotBlocked(facilityId: facilityId, dateString: dateKey, slotId: slotId)
            // Mock some taken slots (e.g. 07:00 AM or 07:00 PM)
            let isMockTaken = (index == 1 || index == 11)
            
            return TimeSlot(
                id: slotId,
                timeLabel: slotTuple.0,
                startTimeString: slotTuple.1,
                period: slotTuple.2,
                isAvailable: !isBlocked && !isMockTaken,
                isBlockedByOwner: isBlocked
            )
        }
    }
}
