// PetTabView.swift
// Pet tab: emotional home surface — hero card, reminders, yearly stats, last visit, health tip.

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct PetTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var tabRouter: MainTabRouter
    @Query(sort: \Pet.dateAdded) private var allPets: [Pet]
    @Query(sort: \PetReminder.nextDueDate) private var allReminders: [PetReminder]
    @Query(sort: \PetWeightEntry.entryDate, order: .reverse) private var weightEntries: [PetWeightEntry]
    @Query(sort: \VetVisitLog.visitDate, order: .reverse) private var vetVisits: [VetVisitLog]
    @Query private var healthTipPreferences: [HealthTipPreferences]

    #if os(iOS)
    @ObservedObject private var appleHealthService = AppleHealthService.shared
    @State private var showAppleHealthPrePrompt = false
    #endif

    @State private var showingSettings = false
    @State private var showingEditPet = false
    @State private var showingPetsList = false
    @State private var showingAddPet = false
    @State private var showingTipJar = false
    #if os(iOS)
    /// Sheet presentation for Care Card (`Identifiable` wrapper so `.sheet(item:)` is reliable).
    @State private var careCardPresentedPet: CareCardSheetPet?
    #endif
    @State private var showingPhotoPicker = false
    @State private var petForPhotoPicker: Pet?
    @State private var showingVisitDetail = false
    @State private var visitForDetail: VetVisitLog?
    @State private var pendingProfileEditAfterCareCard = false

    @State private var showComingUpInfoSheet = false
    @State private var showComingUpInfoPopover = false
    @State private var comingUpDismissalsVersion = 0

    private var sortedPets: [Pet] {
        allPets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var resolvedActivePet: Pet? {
        guard let id = ActivePetResolver.resolvedPetId(pets: sortedPets) else {
            return sortedPets.first
        }
        return sortedPets.first { $0.id == id } ?? sortedPets.first
    }

    private var currentHealthTipPreferences: HealthTipPreferences {
        if let prefs = healthTipPreferences.first {
            if let pet = resolvedActivePet, prefs.petSpecies != pet.species {
                prefs.petSpecies = pet.species
            }
            return prefs
        }
        let species = resolvedActivePet?.species ?? "Dog"
        let newPrefs = HealthTipPreferences(petSpecies: species)
        modelContext.insert(newPrefs)
        return newPrefs
    }

    private var shouldShowHealthTip: Bool {
        HealthTipService.shouldShowTip(preferences: currentHealthTipPreferences)
    }

    private var todaysHealthTip: HealthTip {
        HealthTipService.getTipForToday(preferences: currentHealthTipPreferences)
    }

    private var adaptiveCardShadowColor: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.42 : 0.08)
    }

    private static var tabBarScrollClearance: CGFloat { 76 }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    petTabHeaderSection

                    if let pet = resolvedActivePet {
                        petHeroCard(for: pet)

                        comingUpRemindersSection(for: pet)

                        thisYearStatsSection(for: pet)

                        lastVetVisitSection(for: pet)

                        dailyTipSection
                    } else {
                        addPetEmptyCard
                    }

                    tipJarNudge
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: PetTabView.tabBarScrollClearance)
                    .accessibilityHidden(true)
            }
            .background(petTabPageBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                FeaturePetScope.claimOrphanRecordsIfNeeded(
                    activePetId: resolvedActivePet?.id ?? sortedPets.first?.id,
                    modelContext: modelContext
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavBarCircleIconButton(
                        systemImage: "plus",
                        accessibilityLabel: "Add pet",
                        gradientColors: [
                            Color("BrandOrange").opacity(0.9),
                            Color("BrandOrange").opacity(0.75)
                        ],
                        adaptiveShadow: adaptiveCardShadowColor
                    ) {
                        HapticManager.shared.light()
                        showingAddPet = true
                    }
                    NavBarCircleIconButton(
                        systemImage: "gearshape.fill",
                        accessibilityLabel: "Settings",
                        adaptiveShadow: adaptiveCardShadowColor
                    ) {
                        HapticManager.shared.light()
                        showingSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingEditPet) {
                Group {
                    if let pet = resolvedActivePet {
                        EditPetView(pet: pet)
                    } else {
                        EmptyView()
                    }
                }
                .onAppear {
                    if resolvedActivePet == nil { showingEditPet = false }
                }
            }
            .sheet(isPresented: $showingPetsList) {
                PetsListView()
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
            .sheet(isPresented: $showingTipJar) {
                LucysTipJarView()
            }
            #if os(iOS)
            .sheet(item: $careCardPresentedPet) { item in
                CareCardView(pet: item.pet, onEditProfileRequested: {
                    pendingProfileEditAfterCareCard = true
                })
                .onDisappear {
                    if pendingProfileEditAfterCareCard {
                        pendingProfileEditAfterCareCard = false
                        showingEditPet = true
                    }
                }
            }
            #endif
            #if os(iOS)
            .sheet(isPresented: $showingPhotoPicker) {
                ImagePickerView(
                    source: .photoLibrary,
                    onImageSelected: { image in
                        guard let pet = petForPhotoPicker else { return }
                        if let data = image.jpegData(compressionQuality: 0.88) {
                            pet.profileImage = data
                            try? modelContext.save()
                        }
                        petForPhotoPicker = nil
                        showingPhotoPicker = false
                    },
                    onCancel: {
                        petForPhotoPicker = nil
                        showingPhotoPicker = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingVisitDetail) {
                NavigationStack {
                    if let visit = visitForDetail {
                        VetVisitDetailView(visit: visit)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Close") {
                                        showingVisitDetail = false
                                        visitForDetail = nil
                                    }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showAppleHealthPrePrompt) {
                AppleHealthPrePromptSheet(
                    petName: resolvedActivePet?.name ?? "your pet",
                    onConnect: {
                        Task {
                            await appleHealthService.requestReadAuthorization()
                            await MainActor.run { showAppleHealthPrePrompt = false }
                        }
                    },
                    onNotNow: {
                        UserDefaults.standard.set(true, forKey: AppleHealthUserDefaultsKeys.hasPromptedHealthKit)
                        showAppleHealthPrePrompt = false
                    }
                )
            }
            #endif
        }
        #if os(iOS)
        .task {
            await appleHealthService.refreshSummaryIfStale()
        }
        #endif
    }

    // MARK: - Background

    private var petTabPageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground),
                    Color(.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [
                    Color("BrandSoftBlue").opacity(colorScheme == .dark ? 0.1 : 0.22),
                    Color("BrandCream").opacity(colorScheme == .dark ? 0.06 : 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Header

    private var petTabHeaderSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Petpal")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("BrandOrange"), Color("BrandBlue")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                let greet = timeGreetingLine()
                if !greet.isEmpty {
                    Text(greet)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Button {
                HapticManager.shared.light()
                Task { @MainActor in
                    showingPetsList = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Switch Pet")
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color("BrandOrange"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                .shadow(color: adaptiveCardShadowColor, radius: 6, x: 0, y: 2)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Switch Pet")
        }
        .padding(.vertical, 8)
    }

    private func timeGreetingLine() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let part: String
        if hour < 12 { part = "Good morning" }
        else if hour < 17 { part = "Good afternoon" }
        else { part = "Good evening" }
        if let name = inferredOwnerFirstName() {
            return "\(part), \(name)"
        }
        return part
    }

    private func inferredOwnerFirstName() -> String? {
        #if canImport(UIKit)
        let raw = UIDevice.current.name
        if let range = raw.range(of: "'s ", options: .caseInsensitive) {
            let first = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !first.isEmpty, first.count < 48 { return first }
        }
        #endif
        return nil
    }

    // MARK: - Hero card

    @ViewBuilder
    private func petHeroCard(for pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                heroPhotoArea(for: pet)
                    .frame(height: 185)
                    .clipped()

                Button {
                    HapticManager.shared.light()
                    showingEditPet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("BrandDark"))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white))
                        .shadow(color: adaptiveCardShadowColor.opacity(0.55), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit pet profile")
                .padding(12)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(pet.name.isEmpty ? "Your Pet" : pet.name)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Color.primary)

                Text(breedSpeciesSubtitle(for: pet))
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)

                if let nextManual = pet.nextVetAppointmentDate {
                    Text("Next vet appointment · \(nextManual.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }

                #if os(iOS)
                Button {
                    HapticManager.shared.light()
                    careCardPresentedPet = CareCardSheetPet(pet: pet)
                } label: {
                    Label("View Care Card", systemImage: "person.text.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color("BrandOrange"))
                )
                .padding(.top, 14)
                #endif
            }
            .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: adaptiveCardShadowColor, radius: 14, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), lineWidth: 1)
        )
    }

    private func heroPhotoArea(for pet: Pet) -> some View {
        ZStack {
            Group {
                #if canImport(UIKit)
                if let data = pet.profileImage, let ui = UIImage(data: data), data.count > 0 {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .blur(radius: 22)
                    Color.black.opacity(0.22)
                } else {
                    LinearGradient(
                        colors: [Color("BrandOrange"), Color("BrandBlue")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                #else
                LinearGradient(
                    colors: [Color("BrandOrange"), Color("BrandBlue")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                #endif
            }
            .allowsHitTesting(false)

            #if canImport(UIKit)
            ZStack {
                Group {
                    if let data = pet.profileImage, let ui = UIImage(data: data), data.count > 0 {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white, lineWidth: 4))
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            HapticManager.shared.light()
                            petForPhotoPicker = pet
                            showingPhotoPicker = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color("BrandOrange"))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.white))
                                .shadow(color: adaptiveCardShadowColor.opacity(0.75), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Change pet photo")
                    }
                    .padding([.trailing, .bottom], 4)
                }
                .frame(width: 120, height: 120)
            }
            #endif

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Text(heroAgeBreedBadge(for: pet))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .padding(.leading, 12)
                        .padding(.bottom, 12)
                    Spacer(minLength: 0)
                }
            }
            .zIndex(20)
        }
    }

    private func breedSpeciesSubtitle(for pet: Pet) -> String {
        let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        if breed.isEmpty { return pet.species }
        return "\(breed) · \(pet.species)"
    }

    private func heroAgeBreedBadge(for pet: Pet) -> String {
        let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedPart = breed.isEmpty ? pet.species : breed
        if let birth = pet.dateOfBirth {
            let cal = Calendar.current
            let c = cal.dateComponents([.year, .month], from: cal.startOfDay(for: birth), to: cal.startOfDay(for: Date()))
            let y = c.year ?? 0
            let m = c.month ?? 0
            if y > 0 || m > 0 {
                return "\(y) yrs \(m) mo · \(breedPart)"
            }
        }
        return "Age — · \(breedPart)"
    }

    private static func weightInLbsString(recentWeight: PetWeightEntry?, fallbackPet: Pet) -> String {
        if let entry = recentWeight {
            let lbs = WeightUnit.lbs.value(fromKg: entry.weightKg)
            return String(format: "%.1f lbs", lbs)
        }
        if fallbackPet.weight > 0 {
            let unit = WeightUnit(rawValue: fallbackPet.weightUnit.lowercased()) ?? .lbs
            let kg = unit.toKg(fallbackPet.weight)
            let lbs = WeightUnit.lbs.value(fromKg: kg)
            return String(format: "%.1f lbs", lbs)
        }
        return "—"
    }

    // MARK: - Coming Up (Pet reminders, next 7 days)

    private static let dismissedRemindersKey = "dismissedComingUpReminders_v1"

    private static let comingUpInfoMessage = "This is where reminders you add in Reminders (under Tracking on the Health tab) will show up 7 days before their due date — for medications, vaccines, vet visits, or anything else. You'll still get your push notification on the actual reminder time."

    private func pruneStaleDismissals() {
        var dict = UserDefaults.standard.dictionary(forKey: Self.dismissedRemindersKey) as? [String: TimeInterval] ?? [:]
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600).timeIntervalSince1970
        dict = dict.filter { $0.value > cutoff }
        UserDefaults.standard.set(dict, forKey: Self.dismissedRemindersKey)
    }

    private func isDismissed(_ reminder: PetReminder) -> Bool {
        let dict = UserDefaults.standard.dictionary(forKey: Self.dismissedRemindersKey) as? [String: TimeInterval] ?? [:]
        guard let savedTimestamp = dict[reminder.id.uuidString] else { return false }
        return abs(savedTimestamp - reminder.nextDueDate.timeIntervalSince1970) < 1.0
    }

    private func dismissReminder(_ reminder: PetReminder) {
        var dict = UserDefaults.standard.dictionary(forKey: Self.dismissedRemindersKey) as? [String: TimeInterval] ?? [:]
        dict[reminder.id.uuidString] = reminder.nextDueDate.timeIntervalSince1970
        UserDefaults.standard.set(dict, forKey: Self.dismissedRemindersKey)
        comingUpDismissalsVersion &+= 1
    }

    /// Same pet scoping as Reminders, plus orphan `petId == nil` rows tied to the app-wide active pet (see `FeaturePetScope.claimOrphanRecordsIfNeeded`).
    private func reminderMatchesComingUpPet(_ reminder: PetReminder, pet: Pet) -> Bool {
        if let rid = reminder.petId {
            return rid == pet.id
        }
        if sortedPets.count == 1, let only = sortedPets.first {
            return pet.id == only.id
        }
        return FeaturePetScope.resolvedPetId(pets: sortedPets) == pet.id
    }

    private func comingUpPetReminders(for pet: Pet) -> [PetReminder] {
        let now = Date()
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        guard let lastEligibleDayStart = cal.date(byAdding: .day, value: 7, to: startOfToday) else { return [] }
        return allReminders
            .filter { reminder in
                guard reminderMatchesComingUpPet(reminder, pet: pet) else { return false }
                guard !reminder.isCompleted else { return false }
                guard !isDismissed(reminder) else { return false }
                let dueDay = cal.startOfDay(for: reminder.nextDueDate)
                guard dueDay >= startOfToday else { return false }
                guard dueDay <= lastEligibleDayStart else { return false }
                return true
            }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private func comingUpDateLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func comingUpCategorySubtitle(_ reminder: PetReminder) -> String? {
        let c = reminder.category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty, c.caseInsensitiveCompare("General") != .orderedSame else { return nil }
        return c
    }

    @ViewBuilder
    private func comingUpInfoExplanationText() -> some View {
        Text(Self.comingUpInfoMessage)
            .font(.body)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func comingUpRemindersSection(for pet: Pet) -> some View {
        let _ = comingUpDismissalsVersion
        let name = pet.name.isEmpty ? "your pet" : pet.name
        let reminders = comingUpPetReminders(for: pet)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Coming up for \(name)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 8)
                Button {
                    HapticManager.shared.light()
                    #if os(iOS)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        showComingUpInfoPopover = true
                    } else {
                        showComingUpInfoSheet = true
                    }
                    #else
                    showComingUpInfoSheet = true
                    #endif
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About coming up reminders")
                .popover(isPresented: $showComingUpInfoPopover) {
                    comingUpInfoExplanationText()
                        .padding()
                        .frame(minWidth: 280)
                }
            }

            if reminders.isEmpty {
                Text("No upcoming reminders")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                List {
                    ForEach(reminders, id: \.id) { reminder in
                        Button {
                            HapticManager.shared.light()
                            tabRouter.openHealthTabReminders()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Reminder" : reminder.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                    .multilineTextAlignment(.leading)
                                if let sub = comingUpCategorySubtitle(reminder) {
                                    Text(sub)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(comingUpDateLabel(for: reminder.nextDueDate))
                                    .font(.subheadline)
                                    .foregroundStyle(Color("BrandOrange"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.visible)
                        .listRowBackground(Color(.systemBackground))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                HapticManager.shared.light()
                                dismissReminder(reminder)
                            } label: {
                                Label("Dismiss", systemImage: "eye.slash")
                            }
                            .tint(.gray)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .environment(\.defaultMinListRowHeight, 56)
                .frame(height: CGFloat(reminders.count) * 76)
            }
        }
        .task(id: pet.id) {
            FeaturePetScope.claimOrphanRecordsIfNeeded(activePetId: pet.id, modelContext: modelContext)
        }
        .onAppear {
            pruneStaleDismissals()
        }
        .sheet(isPresented: $showComingUpInfoSheet) {
            NavigationStack {
                comingUpInfoExplanationText()
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .navigationTitle("Coming up")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Dismiss") {
                                showComingUpInfoSheet = false
                            }
                        }
                    }
            }
            #if os(iOS)
            .presentationDetents([.fraction(0.3), .medium])
            #endif
        }
    }

    // MARK: - Year stats

    private func thisYearStatsSection(for pet: Pet) -> some View {
        let pid = pet.id
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let visitsThisYear = vetVisits.filter { v in
            PetRecordFilter.matches(v.petId, selectedPetId: pid) && cal.component(.year, from: v.visitDate) == year
        }.count
        let name = pet.name.isEmpty ? "your pet" : pet.name
        let weightStat = Self.yearWeightStatPresentation(weightEntries: weightEntries, pet: pet)

        let yearStatColumns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        #if os(iOS)
        let activityValue: String = {
            if appleHealthService.isConnected, let mi = appleHealthService.summary?.totalMilesThisYear {
                return String(format: "%.1f mi", mi)
            }
            return "—"
        }()
        #else
        let activityValue = "—"
        #endif

        return VStack(alignment: .leading, spacing: 10) {
            Text("This year with \(name)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.primary)

            LazyVGrid(columns: yearStatColumns, spacing: 10) {
                yearStatCard(
                    value: "\(visitsThisYear)",
                    label: "Vet visits this year",
                    icon: "cross.case.fill",
                    iconColor: Color("BrandOrange"),
                    valueColor: Color.primary
                )

                yearStatCard(
                    value: weightStat.value,
                    label: weightStat.label,
                    icon: "scalemass.fill",
                    iconColor: Color("BrandOrange"),
                    valueColor: weightStat.valueColor
                )

                yearStatCard(
                    value: activityValue,
                    label: "Walks & Activity",
                    icon: "figure.walk",
                    iconColor: Color("BrandBlue"),
                    valueColor: Color.primary
                )
            }
        }
    }

    /// Weight change vs earliest weigh-in this calendar year, or current weight when insufficient data.
    private static func yearWeightStatPresentation(weightEntries: [PetWeightEntry], pet: Pet) -> (value: String, valueColor: Color, label: String) {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let pid = pet.id
        let petEntries = weightEntries
            .filter { PetRecordFilter.matches($0.petId, selectedPetId: pid) && $0.weightKg > 0 }
            .sorted { $0.entryDate > $1.entryDate }

        if petEntries.isEmpty {
            let s = weightInLbsString(recentWeight: nil, fallbackPet: pet)
            return (s, .primary, "Current weight")
        }
        if petEntries.count == 1 {
            let lbs = WeightUnit.lbs.value(fromKg: petEntries[0].weightKg)
            return (String(format: "%.1f lbs", lbs), .primary, "Current weight")
        }

        let thisYearAscending = petEntries
            .filter { cal.component(.year, from: $0.entryDate) == year }
            .sorted { $0.entryDate < $1.entryDate }

        if thisYearAscending.isEmpty {
            let newest = petEntries[0]
            let lbs = WeightUnit.lbs.value(fromKg: newest.weightKg)
            return (String(format: "%.1f lbs", lbs), .primary, "Current weight")
        }

        let oldestThisYear = thisYearAscending[0]
        let newest = petEntries[0]
        let newestLbs = WeightUnit.lbs.value(fromKg: newest.weightKg)
        let oldestLbs = WeightUnit.lbs.value(fromKg: oldestThisYear.weightKg)
        let delta = newestLbs - oldestLbs

        if abs(delta) <= 1 {
            return ("Stable", Color.teal, "Weight this year")
        }
        if delta > 1 {
            return (String(format: "+%.1f lbs", delta), Color("BrandOrange"), "Weight this year")
        }
        return (String(format: "-%.1f lbs", abs(delta)), Color("BrandGreen"), "Weight this year")
    }

    private func yearStatCard(value: String, label: String, icon: String, iconColor: Color, valueColor: Color) -> some View {
        yearStatCardContent(value: value, label: label, icon: icon, iconColor: iconColor, valueColor: valueColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: adaptiveCardShadowColor.opacity(0.45), radius: 8, x: 0, y: 3)
    }

    private func yearStatCardContent(value: String, label: String, icon: String, iconColor: Color, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: false)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: false)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    // MARK: - Last visit

    private func lastVetVisitSection(for pet: Pet) -> some View {
        let pid = pet.id
        let visits = vetVisits.filter { PetRecordFilter.matches($0.petId, selectedPetId: pid) }
            .sorted { $0.visitDate > $1.visitDate }
        let last = visits.first

        return VStack(alignment: .leading, spacing: 10) {
            Text("Last vet visit")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.primary)

            if let v = last {
                Button {
                    HapticManager.shared.light()
                    visitForDetail = v
                    showingVisitDetail = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(v.reason.isEmpty ? (v.clinicName.isEmpty ? "Visit" : v.clinicName) : v.reason)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Text(v.visitDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        if !v.notes.isEmpty {
                            Text(v.notes)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        let dr = pet.vetName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let clinic = v.clinicName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let bottom = dr.isEmpty ? clinic : (clinic.isEmpty ? "Dr. \(dr)" : "Dr. \(dr) · \(clinic)")
                        if !bottom.isEmpty {
                            Text(bottom)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: adaptiveCardShadowColor.opacity(0.45), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.up")
                        .foregroundStyle(.secondary)
                    Text("No visits logged yet. Import a vet record or add manually in Health.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    // MARK: - Health tip

    private var dailyTipSection: some View {
        Group {
            if shouldShowHealthTip {
                healthTipSection
            } else {
                fallbackDailyTipCard
            }
        }
    }

    private var healthTipSection: some View {
        ZStack(alignment: .topTrailing) {
            HealthTipCard(tip: todaysHealthTip, frequency: currentHealthTipPreferences.frequency)
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))

            Button {
                withAnimation {
                    var prefs = currentHealthTipPreferences
                    HealthTipService.markTipAsShown(preferences: &prefs)
                    try? modelContext.save()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(10)
        }
    }

    /// Shown when `HealthTipService` does not surface a tip (e.g. already shown today).
    private var fallbackDailyTipCard: some View {
        let tips = Self.fallbackPetHealthTips
        let dayOrdinal = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let idx = abs(dayOrdinal) % tips.count
        return VStack(alignment: .leading, spacing: 10) {
            Text("Today's tip")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color("BrandOrange"))
                .textCase(.uppercase)
                .tracking(0.6)
            Text(tips[idx])
                .font(.subheadline)
                .foregroundStyle(Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), lineWidth: 1)
        )
        .shadow(color: adaptiveCardShadowColor.opacity(0.35), radius: 8, x: 0, y: 3)
    }

    private static let fallbackPetHealthTips: [String] = [
        "Annual wellness exams catch issues early—schedule yours if you haven't this year.",
        "Keep fresh water available at all times; change bowls daily to prevent bacteria.",
        "Heartworm prevention is monthly in many regions—confirm your plan with your vet.",
        "Dental disease is common: ask your vet about brushing or approved dental chews.",
        "Store medications out of reach and follow the labeled dose—never guess.",
        "Update your pet's microchip info when you move or change phone numbers.",
        "Know your nearest 24-hour emergency vet before you need it—save the number now."
    ]

    // MARK: - Tip jar

    private var tipJarNudge: some View {
        Button {
            HapticManager.shared.soft()
            showingTipJar = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 13))
                Text("Enjoying Petpal? Buy us a coffee")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Enjoying Petpal? Buy us a coffee. Opens optional tip jar.")
    }

    // MARK: - Empty add pet

    private var addPetEmptyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    Image(systemName: "pawprint.circle.fill")
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
                    Text("Add a pet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    Text("Create a profile to unlock Petpal’s tools.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color("BrandOrange").opacity(colorScheme == .dark ? 0.07 : 0.1),
                                    .clear,
                                    Color("BrandBlue").opacity(colorScheme == .dark ? 0.07 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                )
                .shadow(color: adaptiveCardShadowColor, radius: 20, x: 0, y: 8)
        )
    }
}

#if os(iOS)
/// Stable identity for presenting `CareCardView` from the Pet tab hero (`.sheet(item:)`).
private struct CareCardSheetPet: Identifiable {
    let id: UUID
    let pet: Pet

    init(pet: Pet) {
        self.id = pet.id
        self.pet = pet
    }
}
#endif
