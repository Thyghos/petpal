// MockPetFriendlyData.swift
// Petpal - Mock Data for Testing

import Foundation
import CoreLocation

#if DEBUG

extension PetFriendlyPlacesService {

    /// Populate with mock data for all tab types (map + list tabs)
    func loadMockDataAllTypes(near location: CLLocation) {
        let types: [PetFriendlyPlace.PlaceType] = [.hotel, .restaurant, .park, .petCare]
        let all = types.flatMap { generateMockPlaces(near: location, type: $0, count: 6) }
        self.places = all.sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }
    }

    /// Populate with mock data for testing without API keys
    func loadMockData(near location: CLLocation, type: PetFriendlyPlace.PlaceType) {
        let mockPlaces = generateMockPlaces(near: location, type: type, count: 8)
        self.places = mockPlaces
    }
    
    private func generateMockPlaces(
        near location: CLLocation,
        type: PetFriendlyPlace.PlaceType,
        count: Int
    ) -> [PetFriendlyPlace] {
        var places: [PetFriendlyPlace] = []
        
        for i in 0..<count {
            let offsetLat = Double.random(in: -0.05...0.05)
            let offsetLon = Double.random(in: -0.05...0.05)
            let coordinate = CLLocationCoordinate2D(
                latitude: location.coordinate.latitude + offsetLat,
                longitude: location.coordinate.longitude + offsetLon
            )
            
            let placeLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = location.distance(from: placeLocation)
            
            let source: PetFriendlyPlace.PlaceSource = [.appleMap, .googlePlaces, .bringFido, .geoapify].randomElement()!
            
            places.append(
                PetFriendlyPlace(
                    id: "\(source)-mock-\(i)",
                    name: mockName(for: type, index: i),
                    type: type,
                    coordinate: coordinate,
                    address: mockAddress(index: i),
                    phoneNumber: mockPhoneNumber(),
                    rating: Double.random(in: 3.5...5.0),
                    priceLevel: Int.random(in: 1...4),
                    amenities: mockAmenities(for: type),
                    distance: distance,
                    photoURLs: [],
                    website: URL(string: "https://example.com"),
                    source: source
                )
            )
        }
        
        return places.sorted { ($0.distance ?? 0) < ($1.distance ?? 0) }
    }
    
    private func mockName(for type: PetFriendlyPlace.PlaceType, index: Int) -> String {
        switch type {
        case .veterinary:
            return ["Paws & Claws Vet", "Happy Tails Animal Hospital", "Pet Care Veterinary Clinic",
                    "Four Paws Emergency Vet", "Whiskers & Wags Vet", "Companion Animal Hospital",
                    "VCA Pet Hospital", "Banfield Pet Hospital"][index % 8]
        case .hotel:
            return ["The Pawington Hotel", "Kimpton Pet-Friendly Hotel", "La Quinta Inn & Suites",
                    "Best Western Pet Lodge", "Marriott Pet Suites", "Holiday Inn Dog Resort",
                    "Hotel Indigo Pet Paradise", "Fairmont Pet-Friendly Resort"][index % 8]
        case .restaurant:
            return ["The Barking Dog Cafe", "Pawsitive Dining", "Woof & Brew Bistro",
                    "Tail Waggers Terrace", "The Leash & Lunch", "Bone Appetit Restaurant",
                    "Fetch Kitchen & Bar", "The Hungry Hound Cafe"][index % 8]
        case .park:
            return ["Wagging Tails Dog Park", "Bark Central Park", "Paws Playground",
                    "Off-Leash Haven", "Canine Corner Park", "Doggy Paradise Park",
                    "Happy Paws Recreation Area", "Furry Friends Park"][index % 8]
        case .petStore:
            return ["Pet Supplies Plus", "Petco", "PetSmart", "Pet Valu",
                    "The Pet Boutique", "Wag N' Wash", "Pet Food Express", "Hollywood Feed"][index % 8]
        case .grooming:
            return ["Pampered Paws Grooming", "The Dog Spa", "Furry Fashion Grooming",
                    "Paws & Reflect Salon", "Shear Pawfection", "Pretty Paws Grooming",
                    "The Grooming Lounge", "Bark & Bath"][index % 8]
        case .daycare:
            return ["Dogtopia Daycare", "Camp Bow Wow", "Paws & Play Daycare",
                    "Happy Hounds Daycare", "The Dog House Daycare", "Pawsitive Experience",
                    "Furry Friends Daycare", "Tail Waggers Daycare"][index % 8]
        case .petCare:
            return ["Rover Dog Walking", "Wag! Pet Care", "Fetch! Pet Services",
                    "Pawsitive Walks", "Trusted Tails Pet Sitting", "Happy Paws Pet Care",
                    "The Dog Butler", "PetSitters Plus"][index % 8]
        }
    }
    
    private func mockAddress(index: Int) -> String {
        let streets = ["Main St", "Oak Ave", "Maple Dr", "Park Blvd", "Pine St", "Cedar Ln", "Elm Ave", "Lake Rd"]
        let number = Int.random(in: 100...9999)
        return "\(number) \(streets[index % streets.count])"
    }
    
    private func mockPhoneNumber() -> String {
        let areaCode = Int.random(in: 200...999)
        let exchange = Int.random(in: 200...999)
        let number = Int.random(in: 1000...9999)
        return "(\(areaCode)) \(exchange)-\(number)"
    }
    
    private func mockAmenities(for type: PetFriendlyPlace.PlaceType) -> [String] {
        switch type {
        case .veterinary:
            return ["Emergency Care", "Surgery", "Dental", "Boarding", "Pet Pharmacy"].shuffled().prefix(3).map { $0 }
        case .hotel:
            return ["Pet Beds", "Dog Park", "Pet Sitting", "Pet Spa", "Welcome Treats", "No Pet Fee"].shuffled().prefix(3).map { $0 }
        case .restaurant:
            return ["Outdoor Seating", "Water Bowls", "Dog Menu", "Treats", "Shaded Patio"].shuffled().prefix(3).map { $0 }
        case .park:
            return ["Off-Leash Area", "Water Station", "Agility Course", "Small Dog Area", "Waste Stations", "Benches"].shuffled().prefix(3).map { $0 }
        case .petStore:
            return ["Pet Food", "Toys", "Grooming Supplies", "Pet Apparel", "Natural Products"].shuffled().prefix(3).map { $0 }
        case .grooming:
            return ["Bathing", "Haircut", "Nail Trim", "Teeth Brushing", "De-Shedding"].shuffled().prefix(3).map { $0 }
        case .daycare:
            return ["Supervised Play", "Training Classes", "Webcams", "Individual Attention", "Climate Controlled"].shuffled().prefix(3).map { $0 }
        case .petCare:
            return ["Dog Walking", "Pet Sitting", "Overnight Boarding", "Drop-in Visits", "GPS Tracking", "Insured & Bonded"].shuffled().prefix(3).map { $0 }
        }
    }
}

// MARK: - Preview Helper

extension PetFriendlyPlace {
    static func mockPlace(type: PlaceType = .veterinary) -> PetFriendlyPlace {
        PetFriendlyPlace(
            id: "mock-1",
            name: "Mock \(type.rawValue)",
            type: type,
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "123 Main St",
            phoneNumber: "(555) 123-4567",
            rating: 4.5,
            priceLevel: 2,
            amenities: ["Pet Friendly", "Great Service"],
            distance: 1500,
            photoURLs: [],
            website: URL(string: "https://example.com"),
            source: .appleMap
        )
    }
    
    static var mockPlaces: [PetFriendlyPlace] {
        [
            mockPlace(type: .veterinary),
            mockPlace(type: .hotel),
            mockPlace(type: .restaurant),
            mockPlace(type: .park)
        ]
    }
}

#endif
