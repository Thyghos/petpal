// SettingsView.swift
// Petpal - Settings View

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var tilePreferences: [TilePreferences]
    @Query private var healthTipPreferences: [HealthTipPreferences]
    @Query(sort: \VetVisitLog.visitDate, order: .reverse) private var vetVisits: [VetVisitLog]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("petName") private var petName: String = "Your Pet"
    @AppStorage("petSpecies") private var petSpecies: String = "Dog"
    @AppStorage("petBreed") private var petBreed: String = ""
    @AppStorage("petWeight") private var petWeight: Double = 0.0
    @AppStorage("weightUnit") private var weightUnit: String = "lbs"
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    @AppStorage("hasAcceptedVetAIDisclaimer") private var hasAcceptedVetAIDisclaimer = false
    
    @State private var showingTileCustomization = false
    @State private var showingAbout = false
    
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
            return prefs
        } else {
            let newPrefs = HealthTipPreferences(petSpecies: petSpecies)
            modelContext.insert(newPrefs)
            return newPrefs
        }
    }

    /// Matches Health History: visits for the active pet profile only (not all pets).
    private var scopedVetVisitCount: Int {
        guard let pid = ActivePetStorage.activePetUUID else {
            return vetVisits.filter { $0.petId == nil }.count
        }
        return vetVisits.filter { $0.petId == pid }.count
    }

    private var petOverviewShareText: String {
        var lines: [String] = []
        lines.append("Petpal — quick pet overview")
        lines.append("Pet: \(petName) (\(petSpecies))")
        if !petBreed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Breed: \(petBreed)")
        }
        if petWeight > 0 {
            lines.append("Weight: \(petWeight) \(weightUnit)")
        }
        lines.append("Logged vet visits for \(petName) in Petpal: \(scopedVetVisitCount)")
        if pets.count > 1, vetVisits.count != scopedVetVisitCount {
            lines.append("(All pets combined: \(vetVisits.count) visits in this app)")
        }
        lines.append("")
        lines.append("We use Petpal for health history and reminders. Full two-way sync and push alerts when someone else edits records need a future cloud update—each phone keeps its own copy for now.")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandCream").opacity(0.3)
                    .ignoresSafeArea()
                
                List {
                    // Home Screen Section
                    Section {
                        Button {
                            showingTileCustomization = true
                        } label: {
                            HStack {
                                Image(systemName: "square.grid.2x2")
                                    .foregroundStyle(Color("BrandOrange"))
                                    .frame(width: 28)
                                Text("Customize Home Tiles")
                                    .foregroundStyle(Color("BrandDark"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Home Screen")
                    } footer: {
                        Text("Choose which tiles appear on your home screen and change their order.")
                    }
                    
                    // Health Tips Section
                    Section {
                        Toggle(isOn: Binding(
                            get: { currentHealthTipPreferences.isEnabled },
                            set: { newValue in
                                if let prefs = healthTipPreferences.first {
                                    prefs.isEnabled = newValue
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(Color("BrandBlue"))
                                    .frame(width: 28)
                                Text("Health Tips")
                                    .foregroundStyle(Color("BrandDark"))
                            }
                        }
                        .tint(Color("BrandOrange"))
                        
                        if currentHealthTipPreferences.isEnabled {
                            Picker("Frequency", selection: Binding(
                                get: { currentHealthTipPreferences.frequency },
                                set: { newValue in
                                    if let prefs = healthTipPreferences.first {
                                        prefs.frequency = newValue
                                    }
                                }
                            )) {
                                ForEach(TipFrequency.allCases, id: \.self) { frequency in
                                    Text(frequency.rawValue).tag(frequency)
                                }
                            }
                            .tint(Color("BrandOrange"))
                        }
                    } header: {
                        Text("Health Tips")
                    } footer: {
                        Text("Receive helpful pet care tips tailored to your \(petSpecies.lowercased()). Tips appear on your home screen.")
                    }

                    Section {
                        ShareLink(
                            item: petOverviewShareText,
                            subject: Text("Petpal — \(petName)"),
                            message: Text("Sharing our Petpal overview.")
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Color("BrandBlue"))
                                    .frame(width: 28)
                                Text("Share pet overview")
                                    .foregroundStyle(Color("BrandDark"))
                            }
                        }
                    } header: {
                        Text("Co-caregivers & family")
                    } footer: {
                        Text("Send a text summary so a partner or sitter knows how you’re using Petpal. Real-time shared editing plus push notifications when the other person updates a visit requires secure cloud sync (e.g. a Petpal account or iCloud)—not available in this version yet.")
                    }
                    
                    // Disclaimers Section
                    Section {
                        Toggle(isOn: $hasAcceptedDisclaimer) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                Text("Show Medical Disclaimer")
                                    .foregroundStyle(Color("BrandDark"))
                            }
                        }
                        .tint(Color("BrandOrange"))
                        
                        Toggle(isOn: $hasAcceptedVetAIDisclaimer) {
                            HStack {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                Text("Show Vet AI Disclaimer")
                                    .foregroundStyle(Color("BrandDark"))
                            }
                        }
                        .tint(Color("BrandOrange"))
                    } header: {
                        Text("Disclaimers")
                    } footer: {
                        Text("Toggle these off to hide disclaimer banners. You can always re-enable them here.")
                    }
                    
                    // About Section
                    Section {
                        Button {
                            showingAbout = true
                        } label: {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(Color("BrandPurple"))
                                    .frame(width: 28)
                                Text("About Petpal")
                                    .foregroundStyle(Color("BrandDark"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Link(destination: URL(string: "https://apps.apple.com/app/petpal")!) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.orange)
                                    .frame(width: 28)
                                Text("Rate Petpal")
                                    .foregroundStyle(Color("BrandDark"))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("About")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandOrange"))
                }
            }
            .sheet(isPresented: $showingTileCustomization) {
                TileCustomizationView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
}

// MARK: - Tile Customization View

struct TileCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var tilePreferences: [TilePreferences]
    @Environment(\.modelContext) private var modelContext
    
    @State private var tileOrder: [String] = []
    @State private var hiddenTiles: [String] = []
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif
    
    var visibleTiles: [HomeTile] {
        tileOrder.compactMap { id in
            guard !hiddenTiles.contains(id),
                  let tile = HomeTile.tile(for: id) else { return nil }
            return tile
        }
    }
    
    var hiddenTilesList: [HomeTile] {
        hiddenTiles.compactMap { HomeTile.tile(for: $0) }
    }
    
    var allTilesVisible: Bool {
        hiddenTiles.isEmpty
    }
    
    // Preset check computed properties
    var isEssentialPresetActive: Bool {
        let essentialTiles: Set<String> = ["reminders", "health", "travel"]
        let visibleSet = Set(tileOrder.filter { !hiddenTiles.contains($0) })
        return visibleSet == essentialTiles
    }
    
    var isMedicalPresetActive: Bool {
        let medicalTiles: Set<String> = ["health", "emergency", "insurance"]
        let visibleSet = Set(tileOrder.filter { !hiddenTiles.contains($0) })
        return visibleSet == medicalTiles
    }
    
    var isTravelPresetActive: Bool {
        let travelTiles: Set<String> = ["travel", "emergency"]
        let visibleSet = Set(tileOrder.filter { !hiddenTiles.contains($0) })
        return visibleSet == travelTiles
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandCream").opacity(0.3)
                    .ignoresSafeArea()
                
                List {
                    // Quick Toggle Section
                    Section {
                        HStack {
                            Button {
                                withAnimation {
                                    hiddenTiles = []
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "eye.fill")
                                        .foregroundStyle(Color("BrandGreen"))
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Show All Tiles")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color("BrandDark"))
                                        Text("Make all tiles visible")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if allTilesVisible {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color("BrandGreen"))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        HStack {
                            Button {
                                withAnimation {
                                    hiddenTiles = tileOrder
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "eye.slash.fill")
                                        .foregroundStyle(Color("BrandOrange"))
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Hide All Tiles")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Color("BrandDark"))
                                        Text("Hide all tiles from home")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !allTilesVisible && hiddenTiles.count == tileOrder.count {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color("BrandOrange"))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Quick Toggle")
                    } footer: {
                        Text("Show or hide all tiles at once.")
                    }
                    
                    // Presets Section
                    Section {
                        // Essential Only Preset
                        Button {
                            withAnimation {
                                applyEssentialPreset()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color("BrandPurple"))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Essential Only")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color("BrandDark"))
                                    Text("Reminders, Health History, Travel Mode")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isEssentialPresetActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color("BrandPurple"))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Medical Focus Preset
                        Button {
                            withAnimation {
                                applyMedicalPreset()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "cross.case.fill")
                                    .foregroundStyle(.pink)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Medical Focus")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color("BrandDark"))
                                    Text("Health History, Emergency QR, Insurance")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isMedicalPresetActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.pink)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Travel Ready Preset
                        Button {
                            withAnimation {
                                applyTravelPreset()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "airplane.departure")
                                    .foregroundStyle(Color("BrandBlue"))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Travel Ready")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color("BrandDark"))
                                    Text("Travel Mode, Emergency QR")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if isTravelPresetActive {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color("BrandBlue"))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("Presets")
                    } footer: {
                        Text("Quickly apply common tile configurations. You can further customize after applying.")
                    }
                    
                    Section {
                        ForEach(visibleTiles) { tile in
                            HStack(spacing: 16) {
                                Image(systemName: tile.icon)
                                    .foregroundStyle(Color(tile.gradient[0]))
                                    .frame(width: 28)
                                Text(tile.title)
                                    .foregroundStyle(Color("BrandDark"))
                                Spacer()
                                Button {
                                    withAnimation {
                                        hiddenTiles.append(tile.id)
                                    }
                                } label: {
                                    Image(systemName: "eye.slash.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .onMove { from, to in
                            // Move within visible tiles
                            var newOrder = tileOrder
                            let visibleIds = visibleTiles.map { $0.id }
                            
                            // Get the IDs being moved
                            let movedIds = from.map { visibleIds[$0] }
                            
                            // Remove moved items
                            newOrder.removeAll { movedIds.contains($0) }
                            
                            // Calculate new insertion index in full array
                            let targetId = visibleIds[min(to, visibleIds.count - 1)]
                            if let targetIndex = newOrder.firstIndex(of: targetId) {
                                newOrder.insert(contentsOf: movedIds, at: targetIndex)
                            }
                            
                            tileOrder = newOrder
                        }
                    } header: {
                        Text("Visible Tiles (\(visibleTiles.count))")
                    } footer: {
                        Text("Drag to reorder tiles. Tap the eye icon to hide a tile.")
                    }
                    
                    if !hiddenTilesList.isEmpty {
                        Section {
                            ForEach(hiddenTilesList) { tile in
                                HStack(spacing: 16) {
                                    Image(systemName: tile.icon)
                                        .foregroundStyle(Color(tile.gradient[0]).opacity(0.5))
                                        .frame(width: 28)
                                    Text(tile.title)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        withAnimation {
                                            hiddenTiles.removeAll { $0 == tile.id }
                                        }
                                    } label: {
                                        Image(systemName: "eye.fill")
                                            .foregroundStyle(Color("BrandGreen"))
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            Text("Hidden Tiles (\(hiddenTilesList.count))")
                        } footer: {
                            Text("Tap the eye icon to show a tile on your home screen.")
                        }
                    }
                    
                    Section {
                        Button {
                            withAnimation {
                                tileOrder = HomeTile.defaultOrder
                                hiddenTiles = []
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundStyle(Color("BrandOrange"))
                                Text("Reset to Default")
                                    .foregroundStyle(Color("BrandOrange"))
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                #if os(iOS)
                .environment(\.editMode, $editMode)
                #endif
            }
            .navigationTitle("Customize Tiles")
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
                        savePreferences()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandOrange"))
                }
                #if os(iOS)
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                        .foregroundStyle(Color("BrandBlue"))
                }
                #endif
            }
            .onAppear {
                loadPreferences()
            }
        }
    }
    
    private func loadPreferences() {
        if let prefs = tilePreferences.first {
            tileOrder = HomeTile.sanitizedTileOrder(prefs.tileOrder)
            hiddenTiles = HomeTile.sanitizedHiddenTiles(prefs.hiddenTiles)
        } else {
            tileOrder = HomeTile.defaultOrder
            hiddenTiles = []
        }
    }
    
    // Preset application functions
    private func applyEssentialPreset() {
        let essentialTiles: Set<String> = ["reminders", "health", "travel"]
        hiddenTiles = tileOrder.filter { !essentialTiles.contains($0) }
        
        // Reorder to put essential tiles at top
        var newOrder = tileOrder
        let essentialIds = ["reminders", "health", "travel"]
        for id in essentialIds.reversed() {
            if let index = newOrder.firstIndex(of: id) {
                newOrder.remove(at: index)
                newOrder.insert(id, at: 0)
            }
        }
        tileOrder = newOrder
    }
    
    private func applyMedicalPreset() {
        let medicalTiles: Set<String> = ["health", "emergency", "insurance"]
        hiddenTiles = tileOrder.filter { !medicalTiles.contains($0) }
        
        // Reorder to put medical tiles at top
        var newOrder = tileOrder
        let medicalIds = ["health", "emergency", "insurance"]
        for id in medicalIds.reversed() {
            if let index = newOrder.firstIndex(of: id) {
                newOrder.remove(at: index)
                newOrder.insert(id, at: 0)
            }
        }
        tileOrder = newOrder
    }
    
    private func applyTravelPreset() {
        let travelTiles: Set<String> = ["travel", "emergency"]
        hiddenTiles = tileOrder.filter { !travelTiles.contains($0) }
        
        // Reorder to put travel tiles at top
        var newOrder = tileOrder
        let travelIds = ["travel", "emergency"]
        for id in travelIds.reversed() {
            if let index = newOrder.firstIndex(of: id) {
                newOrder.remove(at: index)
                newOrder.insert(id, at: 0)
            }
        }
        tileOrder = newOrder
    }
    
    private func savePreferences() {
        let order = HomeTile.sanitizedTileOrder(tileOrder)
        let hidden = HomeTile.sanitizedHiddenTiles(hiddenTiles)
        if let prefs = tilePreferences.first {
            prefs.tileOrder = order
            prefs.hiddenTiles = hidden
            prefs.lastUpdated = Date()
        } else {
            let newPrefs = TilePreferences(tileOrder: order, hiddenTiles: hidden)
            modelContext.insert(newPrefs)
        }
        try? modelContext.save()
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color("BrandCream"), Color("BrandSoftBlue").opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // App Icon/Logo
                        VStack(spacing: 16) {
                            Image(systemName: "pawprint.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color("BrandOrange"), Color("BrandBlue")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Petpal")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(Color("BrandDark"))
                            
                            Text("Version 1.0")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                        
                        VStack(spacing: 20) {
                            Text("Your Pet's Health Companion")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("BrandDark"))
                            
                            Text("Petpal helps you keep your pet healthy and happy by organizing medical records, tracking appointments, and providing personalized care tips.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        VStack(spacing: 16) {
                            FeatureBullet(icon: "cross.case.fill", text: "Track health records and medications")
                            FeatureBullet(icon: "bell.badge.fill", text: "Never miss vet appointments")
                            FeatureBullet(icon: "qrcode.viewfinder", text: "Emergency QR codes for lost pets")
                            FeatureBullet(icon: "airplane.departure", text: "Travel mode for adventures")
                            FeatureBullet(icon: "sparkles", text: "AI-powered vet assistance")
                        }
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal)
                        
                        Text("Made with ❤️ for pet parents everywhere")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 32)
                    }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("BrandOrange"))
                }
            }
        }
    }
}

struct FeatureBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color("BrandOrange"))
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color("BrandDark"))
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [TilePreferences.self, HealthTipPreferences.self, Pet.self, VetVisitLog.self], inMemory: true)
}
