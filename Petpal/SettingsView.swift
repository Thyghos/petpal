// SettingsView.swift
// Petpal - Settings View

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var healthTipPreferences: [HealthTipPreferences]
    @Query(sort: \VetVisitLog.visitDate, order: .reverse) private var vetVisits: [VetVisitLog]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    @AppStorage("hasAcceptedVetAIDisclaimer") private var hasAcceptedVetAIDisclaimer = false
    @AppStorage("vaccineReminderLookaheadDays") private var vaccineReminderLookaheadDays: Int = 30

    @State private var showingAbout = false
    #if os(iOS)
    @ObservedObject private var appleHealthService = AppleHealthService.shared
    @State private var showingDataBackup = false
    @State private var showingDevTipJar = false
    @State private var showAppleHealthPrePrompt = false
    @State private var showAppleHealthDetail = false
    #endif

    private var activePetForSettings: Pet? {
        guard let id = FeaturePetScope.resolvedPetId(pets: pets) else { return pets.first }
        return pets.first { $0.id == id }
    }

    private var displayPetName: String {
        FeaturePetScope.currentPetName(pets: pets)
    }

    private var displaySpecies: String {
        activePetForSettings?.species ?? "Dog"
    }

    private var displayBreed: String {
        activePetForSettings?.breed ?? ""
    }

    private var displayWeight: Double {
        activePetForSettings?.weight ?? 0
    }

    private var displayWeightUnit: String {
        activePetForSettings?.weightUnit ?? "lbs"
    }

    var currentHealthTipPreferences: HealthTipPreferences {
        let species = displaySpecies
        if let prefs = healthTipPreferences.first {
            if prefs.petSpecies != species {
                prefs.petSpecies = species
            }
            return prefs
        } else {
            let newPrefs = HealthTipPreferences(petSpecies: species)
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
        lines.append("Pet: \(displayPetName) (\(displaySpecies))")
        if !displayBreed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Breed: \(displayBreed)")
        }
        if displayWeight > 0 {
            lines.append("Weight: \(displayWeight) \(displayWeightUnit)")
        }
        lines.append("Logged vet visits for \(displayPetName) in Petpal: \(scopedVetVisitCount)")
        if pets.count > 1, vetVisits.count != scopedVetVisitCount {
            lines.append("(All pets combined: \(vetVisits.count) visits in this app)")
        }
        lines.append("")
        lines.append("We use Petpal for health history and reminders. With iCloud enabled, Petpal can sync data across your iPhone and iPad on the same Apple ID. You can also export a backup file from Settings → Backup & restore.")
        return lines.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandCream").opacity(0.3)
                    .ignoresSafeArea()
                
                List {
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
                        Text("Receive helpful pet care tips tailored to your \(displaySpecies.lowercased()). Tips appear on your Pet tab.")
                    }

                    Section {
                        Picker(selection: $vaccineReminderLookaheadDays) {
                            Text("1 week").tag(7)
                            Text("2 weeks").tag(14)
                            Text("1 month").tag(30)
                            Text("2 months").tag(60)
                            Text("3 months").tag(90)
                            Text("6 months").tag(180)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "syringe.fill")
                                    .foregroundStyle(Color("BrandBlue"))
                                    .frame(width: 28, alignment: .center)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Vaccine reminder window")
                                        .foregroundStyle(Color("BrandDark"))
                                    Text("Show upcoming vaccines on your home screen")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color("BrandOrange"))
                    } header: {
                        Text("Reminders")
                    } footer: {
                        Text("Certificates expiring within this window appear on the Pet tab under Coming up, next to your other reminders.")
                    }

                    #if os(iOS)
                    Section {
                        Button {
                            showingDataBackup = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                    .foregroundStyle(Color("BrandBlue"))
                                    .frame(width: 28)
                                Text("Backup & restore")
                                    .foregroundStyle(Color("BrandDark"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Your data")
                    } footer: {
                        Text("Export a file to move data to another device, or import a backup. When you’re signed into iCloud, Petpal can sync across your devices on the same Apple ID.")
                    }

                    Section {
                        Button {
                            HapticManager.shared.selection()
                            if appleHealthService.isConnected {
                                showAppleHealthDetail = true
                            } else {
                                showAppleHealthPrePrompt = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "figure.walk.circle.fill")
                                    .foregroundStyle(Color("BrandBlue"))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Apple Health")
                                        .foregroundStyle(Color("BrandDark"))
                                    if appleHealthService.isConnected {
                                        if let last = appleHealthService.lastSyncDate {
                                            Text("Connected · \(last.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption)
                                                .foregroundStyle(Color.green)
                                        } else {
                                            Text("Connected")
                                                .font(.caption)
                                                .foregroundStyle(Color.green)
                                        }
                                    } else {
                                        Text("Not connected")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Integrations")
                    } footer: {
                        Text("Petpal can read walk and activity summaries from the Health app on this iPhone. Data stays on your device.")
                    }
                    #endif

                    Section {
                        ShareLink(
                            item: petOverviewShareText,
                            subject: Text("Petpal — \(displayPetName)"),
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
                        Text("Send a text summary so a partner or sitter knows how you’re using Petpal. For full data on another device, use Backup & restore or stay signed into iCloud on both devices.")
                    }

                    #if os(iOS)
                    Section {
                        Button {
                            showingDevTipJar = true
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(Color("BrandPurple"))
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Developer Tip Jar")
                                        .foregroundStyle(Color("BrandDark"))
                                    Text("Optional support for Petpal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Support")
                    } footer: {
                        Text("Leave a tip if you’d like—nothing is locked behind it. Payments go through Apple.")
                    }
                    #endif

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
                        #if os(iOS)
                        Button {
                            showingDevTipJar = true
                        } label: {
                            HStack {
                                Image(systemName: "heart.circle.fill")
                                    .foregroundStyle(Color("BrandPurple"))
                                    .frame(width: 28)
                                Text("Support Petpal")
                                    .foregroundStyle(Color("BrandDark"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        #endif
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
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            #if os(iOS)
            .sheet(isPresented: $showingDataBackup) {
                NavigationStack {
                    DataBackupSettingsView()
                }
            }
            .sheet(isPresented: $showingDevTipJar) {
                DeveloperTipJarView()
            }
            .sheet(isPresented: $showAppleHealthPrePrompt) {
                AppleHealthPrePromptSheet(
                    petName: FeaturePetScope.currentPetName(pets: pets),
                    onConnect: {
                        Task {
                            await appleHealthService.requestReadAuthorization()
                            await MainActor.run {
                                showAppleHealthPrePrompt = false
                            }
                        }
                    },
                    onNotNow: {
                        UserDefaults.standard.set(true, forKey: AppleHealthUserDefaultsKeys.hasPromptedHealthKit)
                        showAppleHealthPrePrompt = false
                    }
                )
            }
            .sheet(isPresented: $showAppleHealthDetail) {
                AppleHealthSettingsDetailSheet(
                    service: appleHealthService,
                    onDisconnect: { showAppleHealthDetail = false }
                )
            }
            #endif
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appVersionText: String {
        // Use the installed bundle's version/build so the UI matches TestFlight/App Store.
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String
        if let build, !build.isEmpty, build != "?" {
            return "Version \(short) (Build \(build))"
        }
        return "Version \(short)"
    }
    
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
                            PetpalAppIconThumbnail(size: 96)

                            Text("Petpal")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(Color("BrandDark"))
                            
                            Text(appVersionText)
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
        .modelContainer(for: [HealthTipPreferences.self, Pet.self, VetVisitLog.self], inMemory: true)
}
