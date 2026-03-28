// HomeView.swift
// Petpal - Home Screen
 
import SwiftUI
import SwiftData
import PhotosUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
 
struct HomeView: View {
 
    @AppStorage("petName") private var petName: String = "Your Pet"
    @AppStorage("petSpecies") private var petSpecies: String = "Dog"
    @AppStorage("petBreed") private var petBreed: String = ""
    @AppStorage("petWeight") private var petWeight: Double = 0.0
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    @AppStorage("hasAcceptedVetAIDisclaimer") private var hasAcceptedVetAIDisclaimer = false
    
    @Query(sort: \Pet.dateAdded) private var allPets: [Pet]
    @Query(sort: \PetReminder.nextDueDate) private var reminders: [PetReminder]
    @Query private var tilePreferences: [TilePreferences]
    @Query private var healthTipPreferences: [HealthTipPreferences]
    @Environment(\.modelContext) private var modelContext
 
    @State private var pagerSelection: UUID = UUID()
    @State private var petUnderEdit: Pet?
    @State private var showingAddPet = false
    @State private var showingPetsList = false
    @State private var showingVetAI = false
    @State private var showingHealthHistory = false
    @State private var showingFoodRecommendations = false
    @State private var showingEmergencyQR = false
    @State private var showingReminders = false
    @State private var showingInsuranceTracker = false
    @State private var showingTravelMode = false
    @State private var showingGeneralDisclaimer = false
    @State private var showingVetAIDisclaimerSheet = false
    @State private var showingSettings = false
    @State private var showingDevTipJar = false
    @State private var healthTipDismissed = false
    
    private var sortedPets: [Pet] {
        allPets.sorted { $0.dateAdded < $1.dateAdded }
    }
    
    /// Pet whose data should scope home badges and tiles (pager or active flag).
    private var homeScopedPetId: UUID? {
        guard !sortedPets.isEmpty else { return nil }
        if sortedPets.contains(where: { $0.id == pagerSelection }) {
            return pagerSelection
        }
        return sortedPets.first(where: { $0.isActive })?.id ?? sortedPets.first?.id
    }
    
    var overdueRemindersCount: Int {
        let pid = homeScopedPetId
        return reminders.filter { r in
            r.isOverdue && PetRecordFilter.matches(r.petId, selectedPetId: pid)
        }.count
    }
    
    var currentTilePreferences: TilePreferences {
        if let prefs = tilePreferences.first {
            return prefs
        } else {
            let newPrefs = TilePreferences()
            modelContext.insert(newPrefs)
            return newPrefs
        }
    }
    
    var currentHealthTipPreferences: HealthTipPreferences {
        if let prefs = healthTipPreferences.first {
            // Update species if changed
            if prefs.petSpecies != petSpecies {
                prefs.petSpecies = petSpecies
            }
            return prefs
        } else {
            let newPrefs = HealthTipPreferences(petSpecies: petSpecies)
            modelContext.insert(newPrefs)
            return newPrefs
        }
    }
    
    var shouldShowHealthTip: Bool {
        !healthTipDismissed && HealthTipService.shouldShowTip(preferences: currentHealthTipPreferences)
    }
    
    var todaysHealthTip: HealthTip {
        HealthTipService.getTipForToday(preferences: currentHealthTipPreferences)
    }
    
    var visibleTiles: [HomeTile] {
        let prefs = currentTilePreferences
        return prefs.tileOrder.compactMap { id in
            guard !prefs.hiddenTiles.contains(id),
                  let tile = HomeTile.tile(for: id) else { return nil }
            return tile
        }
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color("BrandCream"),
                    Color("BrandSoftBlue").opacity(0.3),
                    Color("BrandCream")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
 
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    
                    // Disclaimer Banner (if not accepted)
                    if !hasAcceptedDisclaimer {
                        disclaimerBanner
                    }
                    
                    modernPetCard
                    
                    // Health Tip Card (if enabled and should show)
                    if shouldShowHealthTip {
                        healthTipSection
                    }
                    
                    featuresGrid
                    footerText
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .sheet(item: $petUnderEdit, onDismiss: {
            petUnderEdit = nil
        }) { pet in
            ModernEditPetSheet(pet: pet)
        }
        .sheet(isPresented: $showingAddPet) {
            AddPetView()
        }
        .sheet(isPresented: $showingPetsList) {
            PetsListView()
        }
        .sheet(isPresented: $showingGeneralDisclaimer) {
            DisclaimerView()
        }
        .sheet(isPresented: $showingVetAIDisclaimerSheet) {
            VetAIDisclaimerSheet(hasAcceptedVetAIDisclaimer: $hasAcceptedVetAIDisclaimer)
                .onDisappear {
                    if hasAcceptedVetAIDisclaimer {
                        showingVetAI = true
                    }
                }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingVetAI) {
            VetAIView()
        }
        .fullScreenCover(isPresented: $showingEmergencyQR) {
            EmergencyQRView()
        }
        .fullScreenCover(isPresented: $showingHealthHistory) {
            HealthHistoryView()
        }
        .fullScreenCover(isPresented: $showingFoodRecommendations) {
            FoodRecommendationsView()
        }
        .fullScreenCover(isPresented: $showingReminders) {
            RemindersView()
        }
        .fullScreenCover(isPresented: $showingInsuranceTracker) {
            InsuranceTrackerView()
        }
        .fullScreenCover(isPresented: $showingTravelMode) {
            TravelModeView()
        }
        #else
        .sheet(isPresented: $showingVetAI) { VetAIView() }
        .sheet(isPresented: $showingEmergencyQR) { EmergencyQRView() }
        .sheet(isPresented: $showingHealthHistory) { HealthHistoryView() }
        .sheet(isPresented: $showingFoodRecommendations) { FoodRecommendationsView() }
        .sheet(isPresented: $showingReminders) { RemindersView() }
        .sheet(isPresented: $showingInsuranceTracker) { InsuranceTrackerView() }
        .sheet(isPresented: $showingTravelMode) { TravelModeView() }
        #endif
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        #if os(iOS)
        .sheet(isPresented: $showingDevTipJar) {
            DeveloperTipJarView()
        }
        #endif
        .onAppear {
            reconcileActivePetAndPager()
        }
        .onChange(of: allPets.map(\.id)) { _, _ in
            reconcileActivePetAndPager()
        }
    }
    
    private func reconcileActivePetAndPager() {
        guard !sortedPets.isEmpty else { return }
        let noneActive = sortedPets.allSatisfy { !$0.isActive }
        if noneActive, let first = sortedPets.first {
            activatePet(first)
        }
        let target = sortedPets.first(where: { $0.isActive })?.id ?? sortedPets.first!.id
        if pagerSelection != target {
            pagerSelection = target
        }
    }
    
    private func activatePet(_ pet: Pet) {
        for p in allPets {
            p.isActive = (p.id == pet.id)
        }
        pet.syncToLegacyAppStorage()
        if let prefs = healthTipPreferences.first, prefs.petSpecies != pet.species {
            prefs.petSpecies = pet.species
        }
        try? modelContext.save()
    }
 
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText())
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Text("Petpal")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("BrandOrange"), Color("BrandBlue")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            Spacer()
            
            // Settings button with modern design
            Button {
                HapticManager.shared.light()
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("BrandBlue").opacity(0.8), Color("BrandPurple").opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                    )
            }
 
            ModernPillButton(
                title: "Add a pet",
                icon: "plus.circle.fill",
                color: Color("BrandOrange")
            ) {
                showingAddPet = true
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Disclaimer Banner
    private var disclaimerBanner: some View {
        Button {
            showingGeneralDisclaimer = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Medical Disclaimer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("BrandDark"))
                    
                    Text("Tap to read important information")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.1), Color.red.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Health Tip Section
    private var healthTipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Tip")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color("BrandDark"))
                
                Spacer()
                
                Button {
                    withAnimation {
                        healthTipDismissed = true
                        var prefs = currentHealthTipPreferences
                        HealthTipService.markTipAsShown(preferences: &prefs)
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 4)
            
            HealthTipCard(tip: todaysHealthTip, frequency: currentHealthTipPreferences.frequency)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
        }
    }
 
    // MARK: - Pet hero (pager or empty state)
    private var modernPetCard: some View {
        Group {
            if sortedPets.isEmpty {
                addFirstPetHeroCard
            } else {
                petPagerSection
            }
        }
    }
    
    private var addFirstPetHeroCard: some View {
        Button {
            HapticManager.shared.medium()
            showingAddPet = true
        } label: {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("BrandOrange").opacity(0.2),
                                    Color("BrandBlue").opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 92, height: 92)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("BrandOrange"), Color("BrandBlue")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add your first pet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("BrandDark"))
                    Text("Profiles power reminders, health history, insurance, and Vet AI for each pet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.35))
            }
            .padding(22)
            .background(heroCardBackground)
        }
        .buttonStyle(SmoothButtonStyle())
    }
    
    private var petPagerSection: some View {
        let selectionBinding = Binding<UUID>(
            get: {
                if sortedPets.contains(where: { $0.id == pagerSelection }) {
                    return pagerSelection
                }
                return sortedPets.first(where: { $0.isActive })?.id ?? sortedPets[0].id
            },
            set: { newId in
                pagerSelection = newId
                if let p = sortedPets.first(where: { $0.id == newId }) {
                    activatePet(p)
                }
            }
        )
        return VStack(spacing: 10) {
            TabView(selection: selectionBinding) {
                ForEach(sortedPets) { pet in
                    HomePetHeroPage(
                        pet: pet,
                        showSwipeHint: sortedPets.count > 1,
                        onEdit: {
                            HapticManager.shared.medium()
                            petUnderEdit = pet
                        },
                        onManagePets: { showingPetsList = true }
                    )
                    .tag(pet.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: sortedPets.count > 1 ? .automatic : .never))
            .frame(height: 220)
        }
    }
    
    private var heroCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("BrandOrange").opacity(0.08),
                            .clear,
                            Color("BrandBlue").opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: .black.opacity(0.08), radius: 25, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
 
    // MARK: - Features Grid
    private var featuresGrid: some View {
        VStack(alignment: .leading, spacing: 20) {
            ModernSectionHeader(
                "Features",
                icon: "square.grid.2x2",
                actionTitle: "Customize"
            ) {
                HapticManager.shared.selection()
                showingSettings = true
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(visibleTiles) { tile in
                    modernTileView(for: tile)
                }
            }
        }
    }
    
    @ViewBuilder
    private func modernTileView(for tile: HomeTile) -> some View {
        let gradientColors = tile.gradient.map { colorName in
            if colorName == "red" {
                return Color.red
            } else if colorName == "pink" {
                return Color.pink
            } else if colorName == "orange" {
                return Color.orange
            } else if colorName == "cyan" {
                return Color.cyan
            } else if colorName == "indigo" {
                return Color.indigo
            } else if colorName == "purple" {
                return Color.purple
            } else {
                return Color(colorName)
            }
        }
        
        let badge: Int? = tile.id == "reminders" ? (overdueRemindersCount > 0 ? overdueRemindersCount : nil) : nil
        
        Button {
            handleTileTap(tile.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: tile.icon)
                        .font(.system(size: tile.iconSize, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay(alignment: .topTrailing) {
                    if let count = badge, count > 0 {
                        Text(count > 99 ? "99+" : "\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 6, y: -6)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(tile.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("BrandDark"))
                        .lineLimit(1)
                    Text(tile.subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 140)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .help(tile.subtitle)
    }
    
    private func handleTileTap(_ tileId: String) {
        switch tileId {
        case "travel":
            showingTravelMode = true
        case "reminders":
            showingReminders = true
        case "emergency":
            showingEmergencyQR = true
        case "health":
            showingHealthHistory = true
        case "food":
            showingFoodRecommendations = true
        case "insurance":
            showingInsuranceTracker = true
        case "ai_vet":
            if hasAcceptedVetAIDisclaimer {
                showingVetAI = true
            } else {
                showingVetAIDisclaimerSheet = true
            }
        default:
            break
        }
    }
    
    private var footerText: some View {
        VStack(spacing: 10) {
            Text("Your pet's health, always at your fingertips.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            #if os(iOS)
            Button {
                showingDevTipJar = true
            } label: {
                Label("Developer Tip Jar", systemImage: "heart.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(Color("BrandPurple"))
            .accessibilityHint("Optional tips to support Petpal development")
            #endif

            HStack(spacing: 4) {
                Text("Made with")
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(Color("BrandPurple"))
                Text("for pet parents")
            }
            .font(.caption2)
            .foregroundStyle(.secondary.opacity(0.7))

            if let privacyURL = URL(string: "https://thyghos.github.io/petpal-privacy/") {
                Link("Privacy Policy", destination: privacyURL)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHint("Opens the privacy policy in Safari")
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
    
    private func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
}

// MARK: - Home pet hero page (one pet per pager page)

private struct HomePetHeroPage: View {
    let pet: Pet
    var showSwipeHint: Bool
    let onEdit: () -> Void
    let onManagePets: () -> Void
    
    private var speciesIcon: String {
        switch pet.species.lowercased() {
        case "cat": return "cat.fill"
        case "bird": return "bird.fill"
        case "rabbit": return "hare.fill"
        case "fish": return "fish.fill"
        case "reptile": return "lizard.fill"
        default: return "dog.fill"
        }
    }
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color("BrandOrange").opacity(0.4),
                                    Color("BrandBlue").opacity(0.2),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 60
                            )
                        )
                        .frame(width: 110, height: 110)
                        .blur(radius: 15)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("BrandOrange").opacity(0.15),
                                    Color("BrandBlue").opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 92, height: 92)
                    #if os(iOS)
                    if let data = pet.profileImage, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 85, height: 85)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.9), .white.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                    } else {
                        placeholderSpeciesIcon
                    }
                    #elseif os(macOS)
                    if let data = pet.profileImage, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 85, height: 85)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.9), .white.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                    } else {
                        placeholderSpeciesIcon
                    }
                    #endif
                    ZStack {
                        Circle()
                            .fill(Color("BrandOrange").opacity(0.3))
                            .frame(width: 32, height: 32)
                            .blur(radius: 4)
                        Circle()
                            .fill(Color("BrandOrange"))
                            .frame(width: 28, height: 28)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 32, y: 32)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(pet.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("BrandDark"))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color("BrandGreen"))
                            .frame(width: 8, height: 8)
                        Text(showSwipeHint ? "Swipe for your other pets" : "Tap to edit profile")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color("BrandGreen"))
                    }
                    if !pet.breed.isEmpty {
                        Text("\(pet.breed) • \(pet.species)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(pet.species)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if pet.weight > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "scalemass.fill")
                                .font(.caption2)
                            Text("\(Int(pet.weight)) \(pet.weightUnit)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary.opacity(0.3))
            }
            .padding(22)
            .background(HomePetHeroPageBackground())
        }
        .buttonStyle(SmoothButtonStyle())
        .contextMenu {
            Button("Manage pets", action: onManagePets)
        }
    }
    
    private var placeholderSpeciesIcon: some View {
        Image(systemName: speciesIcon)
            .font(.system(size: 38))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color("BrandOrange"), Color("BrandBlue")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 85, height: 85)
            .background(Circle().fill(Color("BrandOrange").opacity(0.1)))
            .overlay(
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.9), .white.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
            )
    }
}

private struct HomePetHeroPageBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 26)
                .fill(
                    LinearGradient(
                        colors: [
                            Color("BrandOrange").opacity(0.08),
                            .clear,
                            Color("BrandBlue").opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: .black.opacity(0.08), radius: 25, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.7), Color.white.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Modern Feature Card
 
struct ModernFeatureCard: View {
    let icon: String
    let title: String
    let gradient: [Color]
    var iconSize: CGFloat = 24
    var badge: Int? = nil
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    // Icon with gradient background
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: gradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 54, height: 54)
                            .shadow(color: gradient[0].opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: icon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("BrandDark"))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 140)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                )
                
                // Badge
                if let count = badge, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(6)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .red.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .offset(x: 8, y: -8)
                }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
 
// MARK: - Modern Edit Pet Sheet
 
struct ModernEditPetSheet: View {
    @Bindable var pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
 
    @State private var tempName: String = ""
    @State private var tempSpecies: String = ""
    @State private var tempBreed: String = ""
    @State private var tempWeight: String = ""
    @State private var tempWeightUnit: String = "lbs"
    @State private var selectedImage: PhotosPickerItem?
    @State private var tempAvatarData: Data?
    @State private var photoRemoved = false
    @State private var showBirthDate = false
    @State private var tempDateOfBirth: Date?
    @State private var showingDeleteConfirm = false
 
    let speciesOptions = ["Dog", "Cat", "Bird", "Rabbit", "Fish", "Reptile", "Other"]
    let weightUnits = ["lbs", "kg"]
    
    private var displayedAvatar: Data? {
        tempAvatarData ?? pet.profileImage
    }
 
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandCream").opacity(0.3)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar Selection
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color("BrandOrange").opacity(0.2),
                                                Color("BrandBlue").opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 140, height: 140)
                                
                                #if os(iOS)
                                if let data = displayedAvatar,
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 130, height: 130)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: tempSpecies == "Cat" ? "cat.fill" : "dog.fill")
                                        .font(.system(size: 50))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color("BrandOrange"), Color("BrandBlue")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                #elseif os(macOS)
                                if let data = displayedAvatar,
                                   let nsImage = NSImage(data: data) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 130, height: 130)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: tempSpecies == "Cat" ? "cat.fill" : "dog.fill")
                                        .font(.system(size: 50))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color("BrandOrange"), Color("BrandBlue")],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                #endif
                            }
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: 4)
                                    .frame(width: 130, height: 130)
                            )
                            
                            PhotosPicker(selection: $selectedImage, matching: .images) {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.callout)
                                    Text(displayedAvatar == nil ? "Add Photo" : "Change Photo")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color("BrandOrange"), Color("BrandOrange").opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color("BrandOrange").opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            .onChange(of: selectedImage) { _, newValue in
                                Task {
                                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                        tempAvatarData = data
                                        photoRemoved = false
                                    }
                                }
                            }
                            
                            if displayedAvatar != nil {
                                Button(role: .destructive) {
                                    tempAvatarData = nil
                                    selectedImage = nil
                                    photoRemoved = true
                                } label: {
                                    Text("Remove Photo")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(.vertical)
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            // Pet Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pet's Name")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                TextField("Enter name", text: $tempName)
                                    .font(.body)
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Species
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Species")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Picker("Species", selection: $tempSpecies) {
                                    ForEach(speciesOptions, id: \.self) { species in
                                        Text(species).tag(species)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding()
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Breed
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Breed (Optional)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                TextField("Enter breed", text: $tempBreed)
                                    .font(.body)
                                    .padding()
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Weight
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Weight")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    TextField("Weight", text: $tempWeight)
                                        #if os(iOS)
                                        .keyboardType(.decimalPad)
                                        #endif
                                        .font(.body)
                                        .padding()
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    Picker("Unit", selection: $tempWeightUnit) {
                                        ForEach(weightUnits, id: \.self) { unit in
                                            Text(unit).tag(unit)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 100)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date of birth")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                Toggle("Set birth date", isOn: $showBirthDate)
                                    .padding(.horizontal, 4)
                                if showBirthDate {
                                    DatePicker(
                                        "Birth date",
                                        selection: Binding(
                                            get: { tempDateOfBirth ?? birthDatePickerFallback },
                                            set: { tempDateOfBirth = $0 }
                                        ),
                                        in: ...Date(),
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.graphical)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            
                            Button(role: .destructive) {
                                showingDeleteConfirm = true
                            } label: {
                                Text("Delete pet")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Pet Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandOrange"))
                }
            }
            .confirmationDialog(
                "Delete \(pet.name)?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete pet", role: .destructive) {
                    deleteThisPet()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the pet from your list. You can add them again anytime.")
            }
            .onChange(of: showBirthDate) { _, isOn in
                if isOn && tempDateOfBirth == nil {
                    tempDateOfBirth = birthDatePickerFallback
                }
            }
            .onAppear {
                photoRemoved = false
                tempName = pet.name
                tempSpecies = pet.species.isEmpty ? "Dog" : pet.species
                tempBreed = pet.breed
                tempWeight = pet.weight > 0 ? String(Int(pet.weight)) : ""
                tempWeightUnit = pet.weightUnit
                tempAvatarData = pet.profileImage
                showBirthDate = pet.dateOfBirth != nil
                tempDateOfBirth = pet.dateOfBirth
            }
        }
    }
    
    private var birthDatePickerFallback: Date {
        Self.defaultBirthDateForPicker()
    }
    
    private static func defaultBirthDateForPicker() -> Date {
        let cal = Calendar.current
        let base = cal.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: base) ?? base
    }
    
    private func deleteThisPet() {
        let petId = pet.id
        let wasActive = pet.isActive
        let descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == petId })
        guard let toDelete = try? modelContext.fetch(descriptor).first else {
            dismiss()
            return
        }
        let others = (try? modelContext.fetch(FetchDescriptor<Pet>()))?.filter { $0.id != petId } ?? []
        modelContext.delete(toDelete)
        if wasActive, let next = others.first {
            for p in others {
                p.isActive = (p.id == next.id)
            }
            next.syncToLegacyAppStorage()
        } else if wasActive {
            UserDefaults.standard.removeObject(forKey: "activePetId")
        }
        try? modelContext.save()
        dismiss()
    }
    
    private func saveChanges() {
        let trimmed = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            pet.name = trimmed
        }
        pet.species = tempSpecies
        pet.breed = tempBreed
        pet.weightUnit = tempWeightUnit
        if let weight = Double(tempWeight) {
            pet.weight = weight
        }
        if let data = tempAvatarData {
            pet.profileImage = data
        } else if photoRemoved {
            pet.profileImage = nil
        }
        pet.dateOfBirth = showBirthDate ? tempDateOfBirth : nil
        if pet.isActive {
            pet.syncToLegacyAppStorage()
        }
        try? modelContext.save()
        dismiss()
    }
}

// Keep old ActionTile for compatibility
 
// Keep old ActionTile for compatibility
struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    var badgeCount: Int = 0
    @State private var isPressed = false
 
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(color)
                    }
                    
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(4)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
                Spacer()
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandDark"))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Legacy Edit Pet Sheet (deprecated, use ModernEditPetSheet)
 
struct EditPetSheet: View {
    @Binding var petName: String
    @Binding var petSpecies: String
    @Binding var petBreed: String
    @Binding var petWeight: Double
    @Binding var weightUnit: String
    @Environment(\.dismiss) private var dismiss
 
    @State private var tempName: String = ""
    @State private var tempSpecies: String = ""
    @State private var tempBreed: String = ""
    @State private var tempWeight: String = ""
    @State private var tempWeightUnit: String = "lbs"
 
    let speciesOptions = ["Dog", "Cat", "Bird", "Rabbit", "Fish", "Reptile", "Other"]
    let weightUnits = ["lbs", "kg"]
 
    var body: some View {
        NavigationStack {
            Form {
                Section("Pet Details") {
                    TextField("Pet's name", text: $tempName)
                    Picker("Species", selection: $tempSpecies) {
                        ForEach(speciesOptions, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Breed (optional)", text: $tempBreed)
                }
                Section("Weight") {
                    HStack {
                        TextField("Weight", text: $tempWeight)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Picker("Unit", selection: $tempWeightUnit) {
                            ForEach(weightUnits, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }
                }
            }
            .navigationTitle("Edit Pet Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !tempName.trimmingCharacters(in: .whitespaces).isEmpty {
                            petName = tempName
                        }
                        petSpecies = tempSpecies
                        petBreed = tempBreed
                        weightUnit = tempWeightUnit
                        if let weight = Double(tempWeight) { petWeight = weight }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                tempName = petName
                tempSpecies = petSpecies
                tempBreed = petBreed
                tempWeight = petWeight > 0 ? String(Int(petWeight)) : ""
                tempWeightUnit = weightUnit
            }
        }
        .presentationDetents([.medium, .large])
    }
}


#Preview {
    HomeView()
        .modelContainer(for: Pet.self, inMemory: true)
}
