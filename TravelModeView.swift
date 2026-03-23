// TravelModeView.swift
// Petpal - Travel Mode
 
import SwiftUI
import MapKit
import CoreLocation
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct TravelModeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var position: MapCameraPosition = .automatic
    @State private var searchResults: [MKMapItem] = []
    @State private var selectedPlace: MKMapItem?
    @State private var selectedPetPlace: PetFriendlyPlace?
    @State private var route: MKRoute?
    @State private var showingRouteSheet = false
    @StateObject private var locationManager = LocationManager()
    @StateObject private var placesService = PetFriendlyPlacesService(
        googleAPIKey: APIConfiguration.googlePlacesAPIKey,
        bringFidoAPIKey: APIConfiguration.bringFidoAPIKey,
        geoapifyAPIKey: APIConfiguration.geoapifyAPIKey
    )
    
    // Development: Set to true to use mock data without API keys
    private let useMockData = false

    /// Debounce: avoid re-running searches on every GPS tick (causes cycling/blinking).
    private static let placesRefreshCooldown: TimeInterval = 30
    @State private var lastPlacesRefreshTime: Date?
    @State private var hasPerformedInitialPlacesLoad = false

    /// Map camera center so BringFido matches the visible area (falls back to search location).
    @State private var mapAreaCenter: CLLocationCoordinate2D?
    #if os(iOS)
    @State private var showBringFidoSafari = false
    @State private var bringFidoSafariURL: URL?
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color("BrandCream"), Color("BrandSoftBlue")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Text("Find pet friendly places near you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search location or route...", text: $searchText)
                            .onSubmit {
                                performSearch()
                            }
                    }
                    .padding()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 8)
                    .padding()
                    
                    // Tab Picker
                    Picker("Travel Tab", selection: $selectedTab) {
                        Text("Map").tag(0)
                        Text("Hotels").tag(1)
                        Text("Dining").tag(2)
                        Text("Parks").tag(3)
                        Text("Pet Care").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    TabView(selection: $selectedTab) {
                        mapView
                            .tag(0)
                        
                        hotelsView
                            .tag(1)
                        
                        diningView
                            .tag(2)
                        
                        parksView
                            .tag(3)
                        
                        petCareView
                            .tag(4)
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #else
                    .tabViewStyle(.automatic)
                    #endif
                }
            }
            .onChange(of: locationManager.location?.coordinate.latitude) { _, _ in
                guard locationForSearch() != nil else { return }
                let now = Date()
                if !hasPerformedInitialPlacesLoad {
                    hasPerformedInitialPlacesLoad = true
                    lastPlacesRefreshTime = now
                    Task { await refreshAllPlaceTabs() }
                    return
                }
                guard let last = lastPlacesRefreshTime else {
                    lastPlacesRefreshTime = now
                    Task { await refreshAllPlaceTabs() }
                    return
                }
                guard now.timeIntervalSince(last) >= Self.placesRefreshCooldown else { return }
                lastPlacesRefreshTime = now
                Task { await refreshAllPlaceTabs() }
            }
            .onChange(of: locationManager.authorizationStatus) { _, status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    hasPerformedInitialPlacesLoad = false
                    lastPlacesRefreshTime = nil
                    Task { await refreshAllPlaceTabs() }
                }
            }
            .navigationTitle("Travel Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            findNearestVet()
                        } label: {
                            Label("Find Nearest Vet", systemImage: "cross.case")
                        }
                        Button {
                            if let selected = selectedPlace {
                                planRoute(to: selected)
                            }
                        } label: {
                            Label("Plan Route", systemImage: "map")
                        }
                        .disabled(selectedPlace == nil)
                        Button {
                            // Save favorite
                        } label: {
                            Label("Save Favorite", systemImage: "star")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    // MARK: - Map View
    private var mapView: some View {
        VStack(spacing: 0) {
            Map(position: $position, selection: $selectedPlace) {
                // User's location
                if let userLocation = locationManager.location {
                    Annotation("Your Location", coordinate: userLocation.coordinate) {
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.3))
                                .frame(width: 30, height: 30)
                            Circle()
                                .fill(.blue)
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                
                // Search results markers (from manual search)
                ForEach(searchResults, id: \.self) { item in
                    Marker(item.name ?? "Location", coordinate: coordinate(of: item))
                        .tint(.red)
                        .tag(item)
                }
                
                // Pet-friendly places markers
                ForEach(placesService.places) { place in
                    Marker(place.name, systemImage: place.type.icon, coordinate: place.coordinate)
                        .tint(colorForPlaceType(place.type))
                        .tag(place.mapItem)
                }
                
                // Route
                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 5)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                mapAreaCenter = context.region.center
            }
            .onChange(of: selectedPlace) { oldValue, newValue in
                if let place = newValue {
                    position = .camera(
                        MapCamera(
                            centerCoordinate: coordinate(of: place),
                            distance: 1000
                        )
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if placesService.isLoading {
                    ProgressView("Searching pet-friendly places...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
            #if os(iOS)
            .overlay(alignment: .bottomTrailing) {
                bringFidoOnMapButton
                    .padding(.trailing, 10)
                    .padding(.bottom, 10)
            }
            #endif
            
            // Quick Actions
            VStack(spacing: 12) {
                quickActionButton(icon: "cross.case.fill", title: "Nearest Vet", color: Color("BrandBlue")) {
                    findNearestVet()
                }
                
                if let selected = selectedPlace {
                    quickActionButton(icon: "map.fill", title: "Plan Route to \(selected.name ?? "Location")", color: Color("BrandGreen")) {
                        planRoute(to: selected)
                    }
                }
                
                quickActionButton(icon: "location.fill", title: "My Location", color: Color("BrandOrange")) {
                    centerOnUserLocation()
                }
            }
            .padding()
            .background(Color.white)
        }
        .onAppear {
            locationManager.requestLocation()
            centerOnUserLocation()
        }
        .sheet(isPresented: $showingRouteSheet) {
            if let route = route, let destination = selectedPlace {
                RouteDetailSheet(route: route, destination: destination)
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showBringFidoSafari, onDismiss: { bringFidoSafariURL = nil }) {
            if let url = bringFidoSafariURL {
                InAppSafariView(url: url)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        #endif
    }

    #if os(iOS)
    private var bringFidoOnMapButton: some View {
        Menu {
            ForEach(BringFidoBrowseSection.allCases) { section in
                Button {
                    Task { await openBringFido(section: section) }
                } label: {
                    Label(section.rawValue, systemImage: section.systemImage)
                }
            }
            Divider()
            Button {
                bringFidoSafariURL = BringFidoWebLink.home
                showBringFidoSafari = true
            } label: {
                Label("BringFido home", systemImage: "house.fill")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "safari.fill")
                    .font(.subheadline.weight(.semibold))
                Text("BringFido")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        }
        .accessibilityLabel("Open BringFido for this map area")
    }

    private func openBringFido(section: BringFidoBrowseSection) async {
        let coord = mapBrowseCoordinate
        let url = await BringFidoWebLink.resolveURL(for: coord, section: section)
        await MainActor.run {
            bringFidoSafariURL = url
            showBringFidoSafari = true
        }
    }

    private var mapBrowseCoordinate: CLLocationCoordinate2D {
        if let c = mapAreaCenter { return c }
        if let loc = locationForSearch() { return loc.coordinate }
        return CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    }
    #endif
    
    private func colorForPlaceType(_ type: PetFriendlyPlace.PlaceType) -> Color {
        switch type {
        case .veterinary: return Color("BrandBlue")
        case .hotel: return .purple
        case .restaurant: return Color("BrandOrange")
        case .park: return Color("BrandGreen")
        case .petStore: return .pink
        case .grooming: return .cyan
        case .daycare: return .indigo
        case .petCare: return .teal
        }
    }
    
    // MARK: - Hotels View
    private var hotelsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if placesService.isLoading {
                    ProgressView("Finding pet-friendly hotels...")
                        .padding()
                } else if placesService.places.isEmpty {
                    ContentUnavailableView {
                        Label("No Hotels Found", systemImage: "bed.double.fill")
                    } description: {
                        Text("Try searching in a different area")
                    }
                    .padding()
                } else {
                    ForEach(placesService.places.filter { $0.type == .hotel }) { place in
                        petFriendlyPlaceCard(place)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Dining View
    private var diningView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if placesService.isLoading {
                    ProgressView("Finding pet-friendly restaurants...")
                        .padding()
                } else if placesService.places.isEmpty {
                    ContentUnavailableView {
                        Label("No Restaurants Found", systemImage: "fork.knife")
                    } description: {
                        Text("Try searching in a different area")
                    }
                    .padding()
                } else {
                    ForEach(placesService.places.filter { $0.type == .restaurant }) { place in
                        petFriendlyPlaceCard(place)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Parks View
    private var parksView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if placesService.isLoading {
                    ProgressView("Finding dog parks...")
                        .padding()
                } else if placesService.places.isEmpty {
                    ContentUnavailableView {
                        Label("No Parks Found", systemImage: "tree.fill")
                    } description: {
                        Text("Try searching in a different area")
                    }
                    .padding()
                } else {
                    ForEach(placesService.places.filter { $0.type == .park }) { place in
                        petFriendlyPlaceCard(place)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Pet Care View
    private var petCareView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card with information
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "figure.walk")
                            .font(.title)
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dog Walking & Pet Sitting")
                                .font(.headline)
                            Text("Professional pet care services")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    
                    Text("Find trusted dog walkers, pet sitters, and boarding facilities near you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.teal.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                if placesService.isLoading {
                    ProgressView("Finding pet care services...")
                        .padding()
                } else if placesService.places.isEmpty {
                    ContentUnavailableView {
                        Label("No Pet Care Services Found", systemImage: "figure.walk")
                    } description: {
                        Text("Try searching in a different area or check back later")
                    } actions: {
                        Button("Search Again") {
                            Task { await refreshAllPlaceTabs() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ForEach(placesService.places.filter { $0.type == .petCare }) { place in
                        petFriendlyPlaceCard(place)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Views
    private func quickActionButton(icon: String, title: String, color: Color, action: @escaping () -> Void = {}) -> some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
    
    private func petFriendlyPlaceCard(_ place: PetFriendlyPlace) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                    Text(place.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Source badge
                    HStack(spacing: 4) {
                        Image(systemName: sourceBadgeIcon(for: place.source))
                            .font(.caption2)
                        Text(sourceBadgeText(for: place.source))
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let rating = place.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    if let distance = place.distance {
                        Text(formatDistanceInMiles(distance))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Amenities
            if !place.amenities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(place.amenities, id: \.self) { amenity in
                            Text(amenity)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color("BrandOrange").opacity(0.15))
                                .foregroundStyle(Color("BrandOrange"))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    selectedPlace = place.mapItem
                    selectedTab = 0
                } label: {
                    Label("View on Map", systemImage: "map.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color("BrandBlue").opacity(0.15))
                        .foregroundStyle(Color("BrandBlue"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button {
                    planRoute(to: place.mapItem)
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color("BrandGreen").opacity(0.15))
                        .foregroundStyle(Color("BrandGreen"))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                if let phone = place.phoneNumber {
                    Button {
                        if let url = URL(string: "tel://\(phone)") {
                            #if os(iOS)
                            UIApplication.shared.open(url)
                            #elseif os(macOS)
                            NSWorkspace.shared.open(url)
                            #endif
                        }
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.caption)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color("BrandOrange").opacity(0.15))
                            .foregroundStyle(Color("BrandOrange"))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8)
    }
    
    private func sourceBadgeIcon(for source: PetFriendlyPlace.PlaceSource) -> String {
        switch source {
        case .appleMap: return "apple.logo"
        case .googlePlaces: return "globe"
        case .bringFido: return "pawprint.fill"
        case .geoapify: return "map.fill"
        }
    }
    
    private func sourceBadgeText(for source: PetFriendlyPlace.PlaceSource) -> String {
        switch source {
        case .appleMap: return "Apple Maps"
        case .googlePlaces: return "Google"
        case .bringFido: return "BringFido"
        case .geoapify: return "Geoapify"
        }
    }
    
    private func formatDistanceInMiles(_ meters: Double) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 {
            return String(format: "%.0f ft", meters * 3.28084)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
    
    // MARK: - Helper Functions
    
    /// Apple Maps search does not need a Google API key. Simulator uses a default coordinate when GPS is unset.
    private func locationForSearch() -> CLLocation? {
        if let loc = locationManager.location { return loc }
        #if targetEnvironment(simulator)
        return CLLocation(latitude: 37.7749, longitude: -122.4194)
        #else
        return nil
        #endif
    }

    private func refreshAllPlaceTabs() async {
        guard let location = locationForSearch() else { return }
        #if DEBUG
        if useMockData {
            placesService.loadMockDataAllTypes(near: location)
            return
        }
        #endif
        await placesService.searchNearbyAllTypes(location: location, radius: 10000)
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        guard let userLocation = locationForSearch() else {
            print("User location not available — allow Location access in Settings, or use the simulator with a custom location.")
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else {
                print("Search error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.searchResults = response.mapItems
                
                // Select the first result and zoom to it
                if let first = response.mapItems.first {
                    self.selectedPlace = first
                }
            }
        }
    }
    
    private func findNearestVet() {
        print("🏥 findNearestVet() called")
        print("🏥 Location manager status: \(locationManager.authorizationStatus.rawValue)")

        if let ready = locationForSearch() {
            print("✅ Using location for vet search: \(ready.coordinate.latitude), \(ready.coordinate.longitude)")
            searchForVets(at: ready)
            return
        }

        guard let userLocation = locationManager.location else {
            print("❌ User location not available - requesting location...")
            locationManager.requestLocation()
            
            // Wait a bit and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let location = self.locationManager.location {
                    print("✅ Location acquired: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    self.searchForVets(at: location)
                } else {
                    print("❌ Still no location - using default San Francisco location for testing")
                    #if targetEnvironment(simulator)
                    // Use default location for simulator testing
                    let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
                    self.searchForVets(at: defaultLocation)
                    #endif
                }
            }
            return
        }
        
        print("✅ Using location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
        searchForVets(at: userLocation)
    }
    
    private func searchForVets(at location: CLLocation) {
        print("🔍 Starting vet search at location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Use the new service for better results
        Task {
            await placesService.searchNearby(location: location, type: .veterinary, radius: 10000)
            
            print("📊 Search complete. Found \(placesService.places.count) places")
            
            if let nearest = placesService.places.first {
                print("✅ Nearest vet: \(nearest.name) at \(nearest.distance ?? 0)m away")
                selectedPlace = nearest.mapItem
                selectedTab = 0
                
                // Update map position
                position = .camera(
                    MapCamera(
                        centerCoordinate: nearest.coordinate,
                        distance: 1000
                    )
                )
            } else {
                print("⚠️ No vets found in search results")
            }
        }
    }
    
    private func coordinate(of mapItem: MKMapItem) -> CLLocationCoordinate2D {
        if #available(macOS 26.0, iOS 18.0, *) {
            return mapItem.location.coordinate
        } else {
            return mapItem.placemark.coordinate
        }
    }
    
    private func planRoute(to destination: MKMapItem) {
        guard let userLocation = locationForSearch() else {
            print("User location not available for routing")
            return
        }
        
        let request = MKDirections.Request()
        if #available(macOS 26.0, iOS 18.0, *) {
            request.source = MKMapItem(location: userLocation, address: nil)
        } else {
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation.coordinate))
        }
        request.destination = destination
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first else {
                print("Route error: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self.route = route
                self.showingRouteSheet = true
                
                // Adjust map to show the entire route
                let rect = route.polyline.boundingMapRect
                self.position = .rect(rect.insetBy(dx: -rect.size.width * 0.1, dy: -rect.size.height * 0.1))
            }
        }
    }
    
    private func centerOnUserLocation() {
        print("📍 centerOnUserLocation() called")
        print("📍 Location manager status: \(locationManager.authorizationStatus.rawValue)")
        
        guard let userLocation = locationManager.location else {
            print("❌ User location not available - requesting location...")
            locationManager.requestLocation()
            
            // Wait and try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let location = self.locationManager.location {
                    print("✅ Location acquired: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                    self.position = .camera(
                        MapCamera(
                            centerCoordinate: location.coordinate,
                            distance: 5000
                        )
                    )
                } else {
                    print("❌ Still no location available")
                    #if targetEnvironment(simulator)
                    print("💡 SIMULATOR TIP: Set location via Debug > Location > Custom Location")
                    print("💡 Or use: Features > Location > Apple")
                    // Use default location for simulator
                    let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                    self.position = .camera(
                        MapCamera(
                            centerCoordinate: defaultCoordinate,
                            distance: 5000
                        )
                    )
                    #endif
                }
            }
            return
        }
        
        print("✅ Centering on location: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
        position = .camera(
            MapCamera(
                centerCoordinate: userLocation.coordinate,
                distance: 5000
            )
        )
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        print("📍 LocationManager initialized")
    }
    
    func requestLocation() {
        print("📍 Requesting location authorization and updates...")
        print("📍 Current authorization: \(manager.authorizationStatus.rawValue)")
        
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        
        #if targetEnvironment(simulator)
        print("💡 SIMULATOR: Make sure to set a location via:")
        print("   Debug > Location > Custom Location (in Xcode)")
        print("   or Features > Location > Apple (in Simulator menu)")
        #endif
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.first {
            print("✅ Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
            print("   Accuracy: \(newLocation.horizontalAccuracy)m")
            location = newLocation
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                print("   Location access denied by user")
            case .locationUnknown:
                print("   Location temporarily unknown - will keep trying")
            default:
                print("   Error code: \(clError.code.rawValue)")
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 Authorization changed to: \(authorizationStatus.rawValue)")
        
        switch authorizationStatus {
        case .notDetermined:
            print("   Not determined - will prompt user")
        case .restricted:
            print("   ❌ Restricted by parental controls or system settings")
        case .denied:
            print("   ❌ User denied location access")
        case .authorizedAlways:
            print("   ✅ Authorized always")
            manager.startUpdatingLocation()
        case .authorizedWhenInUse:
            print("   ✅ Authorized when in use")
            manager.startUpdatingLocation()
        @unknown default:
            print("   Unknown authorization status")
        }
    }
}

// MARK: - Route Detail Sheet

struct RouteDetailSheet: View {
    let route: MKRoute
    let destination: MKMapItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationStack {
            List {
                Section("Destination") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(destination.name ?? "Unknown Location")
                            .font(.headline)
                        
                        if let address = destinationAddressTitle(destination) {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let phone = destination.phoneNumber {
                            Button {
                                if let url = URL(string: "tel://\(phone)") {
                                    openURL(url)
                                }
                            } label: {
                                Label(phone, systemImage: "phone.fill")
                            }
                        }
                    }
                }
                
                Section("Route Information") {
                    LabeledContent("Distance") {
                        Text(formatDistance(route.distance))
                    }
                    
                    LabeledContent("Travel Time") {
                        Text(formatTime(route.expectedTravelTime))
                    }
                }
                
                Section("Actions") {
                    Button {
                        openInMaps()
                    } label: {
                        Label("Open in Apple Maps", systemImage: "map.fill")
                    }
                }
                
                if !route.steps.isEmpty {
                    Section("Directions") {
                        ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(index + 1).")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    Text(step.instructions)
                                }
                                if step.distance > 0 {
                                    Text(formatDistance(step.distance))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Route Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func destinationAddressTitle(_ item: MKMapItem) -> String? {
        if #available(macOS 26.0, iOS 18.0, *) {
            return item.address?.fullAddress
        } else {
            return item.placemark.title
        }
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 {
            return String(format: "%.0f ft", meters * 3.28084)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func openInMaps() {
        destination.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

#Preview {
    TravelModeView()
}
