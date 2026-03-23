// PetFriendlyPlacesService.swift
// Petpal - Pet-Friendly Places Integration

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Place Model

struct PetFriendlyPlace: Identifiable, Hashable {
    let id: String
    let name: String
    let type: PlaceType
    let coordinate: CLLocationCoordinate2D
    let address: String?
    let phoneNumber: String?
    let rating: Double?
    let priceLevel: Int?
    let amenities: [String]
    let distance: Double?
    let photoURLs: [URL]
    let website: URL?
    let source: PlaceSource
    
    enum PlaceType: String, CaseIterable {
        case veterinary = "Veterinary"
        case hotel = "Hotel"
        case restaurant = "Restaurant"
        case park = "Park"
        case petStore = "Pet Store"
        case grooming = "Grooming"
        case daycare = "Daycare"
        case petCare = "Pet Care" // Dog walkers, pet sitters, boarding
        
        var icon: String {
            switch self {
            case .veterinary: return "cross.case.fill"
            case .hotel: return "bed.double.fill"
            case .restaurant: return "fork.knife"
            case .park: return "tree.fill"
            case .petStore: return "cart.fill"
            case .grooming: return "scissors"
            case .daycare: return "house.fill"
            case .petCare: return "figure.walk"
            }
        }
        
        var displayName: String {
            switch self {
            case .petCare: return "Dog Walking & Pet Sitting"
            default: return rawValue
            }
        }
        
        var description: String {
            switch self {
            case .veterinary: return "Veterinary clinics and animal hospitals"
            case .hotel: return "Pet-friendly hotels and lodging"
            case .restaurant: return "Restaurants that welcome pets"
            case .park: return "Dog parks and pet play areas"
            case .petStore: return "Pet supply stores"
            case .grooming: return "Pet grooming services"
            case .daycare: return "Pet daycare facilities"
            case .petCare: return "Dog walkers, pet sitters, and boarding"
            }
        }
    }
    
    enum PlaceSource {
        case appleMap
        case googlePlaces
        case bringFido
        case geoapify
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PetFriendlyPlace, rhs: PetFriendlyPlace) -> Bool {
        lhs.id == rhs.id
    }
    
    // Convert to MKMapItem for compatibility
    var mapItem: MKMapItem {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // MKAddress in iOS 26 is created without parameters
        let item = MKMapItem(location: location, address: nil)
        item.name = name
        item.phoneNumber = phoneNumber
        return item
    }
}

// MARK: - Pet-Friendly Places Service

class PetFriendlyPlacesService: ObservableObject {
    @Published var places: [PetFriendlyPlace] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Configuration
    private let googleAPIKey: String?
    private let bringFidoAPIKey: String?
    private let geoapifyAPIKey: String?

    init(googleAPIKey: String? = nil, bringFidoAPIKey: String? = nil, geoapifyAPIKey: String? = nil) {
        self.googleAPIKey = googleAPIKey
        self.bringFidoAPIKey = bringFidoAPIKey
        self.geoapifyAPIKey = geoapifyAPIKey
    }
    
    // MARK: - Search Methods

    /// Search all tab types (hotels, restaurants, parks, pet care) and merge results.
    /// Use this for map + tab views so all categories appear instead of overwriting.
    func searchNearbyAllTypes(location: CLLocation, radius: Double = 5000) async {
        isLoading = true
        errorMessage = nil

        async let hotels: [PetFriendlyPlace] = fetchPlacesForType(location: location, type: .hotel, radius: radius)
        async let restaurants: [PetFriendlyPlace] = fetchPlacesForType(location: location, type: .restaurant, radius: radius)
        async let parks: [PetFriendlyPlace] = fetchPlacesForType(location: location, type: .park, radius: radius)
        async let petCare: [PetFriendlyPlace] = fetchPlacesForType(location: location, type: .petCare, radius: radius)

        let allPlaces = await hotels + restaurants + parks + petCare
        places = removeDuplicates(allPlaces).sorted { p1, p2 in
            (p1.distance ?? .infinity) < (p2.distance ?? .infinity)
        }
        isLoading = false
    }

    func searchNearby(
        location: CLLocation,
        type: PetFriendlyPlace.PlaceType,
        radius: Double = 5000
    ) async {
        isLoading = true
        errorMessage = nil
        let results = await fetchPlacesForType(location: location, type: type, radius: radius)
        places = removeDuplicates(results).sorted { p1, p2 in
            (p1.distance ?? .infinity) < (p2.distance ?? .infinity)
        }
        isLoading = false
    }

    private func fetchPlacesForType(
        location: CLLocation,
        type: PetFriendlyPlace.PlaceType,
        radius: Double
    ) async -> [PetFriendlyPlace] {
        var allPlaces: [PetFriendlyPlace] = []
        let applePlaces = await searchAppleMaps(location: location, type: type, radius: radius)
        allPlaces.append(contentsOf: applePlaces)
        if googleAPIKey != nil {
            let googlePlaces = await searchGooglePlaces(location: location, type: type, radius: radius)
            allPlaces.append(contentsOf: googlePlaces)
        }
        if bringFidoAPIKey != nil {
            let bringFidoPlaces = await searchBringFido(location: location, type: type, radius: radius)
            allPlaces.append(contentsOf: bringFidoPlaces)
        }
        if geoapifyAPIKey != nil {
            let geoapifyPlaces = await searchGeoapify(location: location, type: type, radius: radius)
            allPlaces.append(contentsOf: geoapifyPlaces)
        }
        return allPlaces
    }
    
    // MARK: - Apple Maps Search
    
    private func searchAppleMaps(
        location: CLLocation,
        type: PetFriendlyPlace.PlaceType,
        radius: Double
    ) async -> [PetFriendlyPlace] {
        let query = searchQuery(for: type, petFriendly: true)
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            return response.mapItems.compactMap { item in
                convertToPlace(mapItem: item, type: type, userLocation: location, source: .appleMap)
            }
        } catch {
            print("Apple Maps search error: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Google Places Search
    
    private func searchGooglePlaces(
        location: CLLocation,
        type: PetFriendlyPlace.PlaceType,
        radius: Double
    ) async -> [PetFriendlyPlace] {
        guard let apiKey = googleAPIKey else { return [] }
        
        let placeType = googlePlaceType(for: type)
        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location.coordinate.latitude),\(location.coordinate.longitude)&radius=\(Int(radius))&type=\(placeType)&keyword=pet+friendly&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
            
            return response.results.compactMap { result in
                convertGooglePlace(result, type: type, userLocation: location)
            }
        } catch {
            print("Google Places search error: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - BringFido Search
    
    private func searchBringFido(
        location: CLLocation,
        type: PetFriendlyPlace.PlaceType,
        radius: Double
    ) async -> [PetFriendlyPlace] {
        guard let apiKey = bringFidoAPIKey else { return [] }
        
        // BringFido API endpoint (this is a placeholder - check their actual API documentation)
        let category = bringFidoCategory(for: type)
        let urlString = "https://www.bringfido.com/api/v2/search?lat=\(location.coordinate.latitude)&lon=\(location.coordinate.longitude)&radius=\(Int(radius/1609.34))&category=\(category)&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(BringFidoResponse.self, from: data)
            
            return response.places.compactMap { place in
                convertBringFidoPlace(place, type: type, userLocation: location)
            }
        } catch {
            print("BringFido search error: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func searchQuery(for type: PetFriendlyPlace.PlaceType, petFriendly: Bool) -> String {
        let base: String
        switch type {
        case .veterinary:
            return "veterinarian"
        case .hotel:
            base = "hotel"
        case .restaurant:
            base = "restaurant"
        case .park:
            return "dog park"
        case .petStore:
            return "pet store"
        case .grooming:
            return "pet grooming"
        case .daycare:
            return "pet daycare"
        case .petCare:
            return "dog walker pet sitter"
        }
        
        return petFriendly ? "pet friendly \(base)" : base
    }
    
    private func googlePlaceType(for type: PetFriendlyPlace.PlaceType) -> String {
        switch type {
        case .veterinary: return "veterinary_care"
        case .hotel: return "lodging"
        case .restaurant: return "restaurant"
        case .park: return "park"
        case .petStore: return "pet_store"
        case .grooming: return "pet_store"
        case .daycare: return "pet_store"
        case .petCare: return "pet_store"
        }
    }
    
    private func bringFidoCategory(for type: PetFriendlyPlace.PlaceType) -> String {
        switch type {
        case .veterinary: return "vet"
        case .hotel: return "lodging"
        case .restaurant: return "restaurant"
        case .park: return "park"
        case .petStore: return "store"
        case .grooming: return "grooming"
        case .daycare: return "daycare"
        case .petCare: return "boarding"
        }
    }

    private func geoapifyCategory(for type: PetFriendlyPlace.PlaceType) -> String {
        switch type {
        case .veterinary: return "healthcare.veterinary"
        case .hotel: return "accommodation.hotel"
        case .restaurant: return "catering.restaurant"
        case .park: return "leisure.park"
        case .petStore: return "commercial.pet"
        case .grooming, .daycare, .petCare: return "commercial.pet"
        }
    }

    // MARK: - Geoapify Search

    private func searchGeoapify(
        location: CLLocation,
        type: PetFriendlyPlace.PlaceType,
        radius: Double
    ) async -> [PetFriendlyPlace] {
        guard let apiKey = geoapifyAPIKey else { return [] }
        let category = geoapifyCategory(for: type)
        let lon = location.coordinate.longitude
        let lat = location.coordinate.latitude
        let filter = "circle:\(lon),\(lat),\(Int(radius))"
        let bias = "proximity:\(lon),\(lat)"
        let conditions = "dogs.yes,dogs.leashed"
        var components = URLComponents(string: "https://api.geoapify.com/v2/places")!
        components.queryItems = [
            URLQueryItem(name: "categories", value: category),
            URLQueryItem(name: "conditions", value: conditions),
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "bias", value: bias),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "apiKey", value: apiKey)
        ]
        guard let url = components.url else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GeoapifyResponse.self, from: data)
            return response.features.compactMap { feature in
                convertGeoapifyPlace(feature, type: type, userLocation: location)
            }
        } catch {
            print("Geoapify search error: \(error.localizedDescription)")
            return []
        }
    }

    private func convertGeoapifyPlace(
        _ feature: GeoapifyFeature,
        type: PetFriendlyPlace.PlaceType,
        userLocation: CLLocation
    ) -> PetFriendlyPlace? {
        guard let coords = feature.geometry?.coordinates, coords.count >= 2 else { return nil }
        let lon = coords[0]
        let lat = coords[1]
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let placeLocation = CLLocation(latitude: lat, longitude: lon)
        let name = feature.properties?.name ?? "Unknown"
        let placeId = feature.properties?.place_id ?? "\(lat)-\(lon)"
        return PetFriendlyPlace(
            id: "geoapify-\(placeId)",
            name: name,
            type: type,
            coordinate: coordinate,
            address: feature.properties?.formatted ?? feature.properties?.address_line1,
            phoneNumber: nil,
            rating: nil,
            priceLevel: nil,
            amenities: defaultAmenities(for: type),
            distance: feature.properties?.distance ?? userLocation.distance(from: placeLocation),
            photoURLs: [],
            website: nil,
            source: .geoapify
        )
    }
    
    private func convertToPlace(
        mapItem: MKMapItem,
        type: PetFriendlyPlace.PlaceType,
        userLocation: CLLocation,
        source: PetFriendlyPlace.PlaceSource
    ) -> PetFriendlyPlace? {
        let itemLocation = mapItem.location
        let coordinate = itemLocation.coordinate
        
        // Convert MKAddress to String if available
        // Note: In iOS 26, MKAddress is a simple struct, so we use the address property directly
        let addressString = mapItem.address?.description
        
        return PetFriendlyPlace(
            id: "\(source)-\(mapItem.name ?? "")-\(coordinate.latitude)-\(coordinate.longitude)",
            name: mapItem.name ?? "Unknown",
            type: type,
            coordinate: coordinate,
            address: addressString,
            phoneNumber: mapItem.phoneNumber,
            rating: nil,
            priceLevel: nil,
            amenities: defaultAmenities(for: type),
            distance: userLocation.distance(from: itemLocation),
            photoURLs: [],
            website: mapItem.url,
            source: source
        )
    }
    
    private func convertGooglePlace(
        _ place: GooglePlace,
        type: PetFriendlyPlace.PlaceType,
        userLocation: CLLocation
    ) -> PetFriendlyPlace {
        let placeLocation = CLLocation(
            latitude: place.geometry.location.lat,
            longitude: place.geometry.location.lng
        )
        
        var amenities = defaultAmenities(for: type)
        if place.types.contains("dog_friendly") || place.types.contains("pet_friendly") {
            amenities.append("Pet Friendly")
        }
        
        return PetFriendlyPlace(
            id: "google-\(place.place_id)",
            name: place.name,
            type: type,
            coordinate: CLLocationCoordinate2D(
                latitude: place.geometry.location.lat,
                longitude: place.geometry.location.lng
            ),
            address: place.vicinity,
            phoneNumber: nil,
            rating: place.rating,
            priceLevel: place.price_level,
            amenities: amenities,
            distance: userLocation.distance(from: placeLocation),
            photoURLs: [],
            website: nil,
            source: .googlePlaces
        )
    }
    
    private func convertBringFidoPlace(
        _ place: BringFidoPlace,
        type: PetFriendlyPlace.PlaceType,
        userLocation: CLLocation
    ) -> PetFriendlyPlace {
        let placeLocation = CLLocation(latitude: place.lat, longitude: place.lon)
        
        return PetFriendlyPlace(
            id: "bringfido-\(place.id)",
            name: place.name,
            type: type,
            coordinate: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon),
            address: place.address,
            phoneNumber: place.phone,
            rating: place.rating,
            priceLevel: nil,
            amenities: place.amenities ?? defaultAmenities(for: type),
            distance: userLocation.distance(from: placeLocation),
            photoURLs: place.photos?.compactMap { URL(string: $0) } ?? [],
            website: place.website.flatMap { URL(string: $0) },
            source: .bringFido
        )
    }
    
    private func defaultAmenities(for type: PetFriendlyPlace.PlaceType) -> [String] {
        switch type {
        case .veterinary:
            return ["Emergency Care", "Pet Pharmacy", "Grooming"]
        case .hotel:
            return ["Pet Beds", "Dog Park", "Pet Sitting"]
        case .restaurant:
            return ["Outdoor Seating", "Water Bowls", "Treats"]
        case .park:
            return ["Off-Leash Area", "Water Station", "Waste Stations"]
        case .petStore:
            return ["Pet Supplies", "Treats", "Toys"]
        case .grooming:
            return ["Bathing", "Nail Trim", "Haircut"]
        case .daycare:
            return ["Supervised Play", "Training", "Socialization"]
        case .petCare:
            return ["Dog Walking", "Pet Sitting", "Overnight Boarding", "Drop-in Visits"]
        }
    }
    
    private func removeDuplicates(_ places: [PetFriendlyPlace]) -> [PetFriendlyPlace] {
        var seen = Set<String>()
        var unique: [PetFriendlyPlace] = []
        
        for place in places {
            let key = "\(place.name.lowercased())-\(Int(place.coordinate.latitude * 1000))-\(Int(place.coordinate.longitude * 1000))"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(place)
            }
        }
        
        return unique
    }
}

// MARK: - Google Places API Models

struct GooglePlacesResponse: Codable {
    let results: [GooglePlace]
    let status: String
}

struct GooglePlace: Codable {
    let place_id: String
    let name: String
    let geometry: GoogleGeometry
    let vicinity: String?
    let rating: Double?
    let price_level: Int?
    let types: [String]
}

struct GoogleGeometry: Codable {
    let location: GoogleLocation
}

struct GoogleLocation: Codable {
    let lat: Double
    let lng: Double
}

// MARK: - BringFido API Models

struct BringFidoResponse: Codable {
    let places: [BringFidoPlace]
}

struct BringFidoPlace: Codable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let address: String?
    let phone: String?
    let rating: Double?
    let amenities: [String]?
    let photos: [String]?
    let website: String?
}

// MARK: - Geoapify Places API Models (GeoJSON FeatureCollection)

struct GeoapifyResponse: Codable {
    let type: String?
    let features: [GeoapifyFeature]
}

struct GeoapifyFeature: Codable {
    let type: String?
    let geometry: GeoapifyGeometry?
    let properties: GeoapifyProperties?
}

struct GeoapifyGeometry: Codable {
    let type: String?
    let coordinates: [Double]?
}

struct GeoapifyProperties: Codable {
    let name: String?
    let place_id: String?
    let formatted: String?
    let address_line1: String?
    let address_line2: String?
    let city: String?
    let postcode: String?
    let country: String?
    let distance: Double?
}
