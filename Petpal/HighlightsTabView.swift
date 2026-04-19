// Highlights tab: monthly albums, recaps, milestones, Year in Review.

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct HighlightsTabView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabRouter: MainTabRouter
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]
    @Query(sort: \PetMonthlyPhoto.addedDate, order: .reverse) private var allMonthlyPhotos: [PetMonthlyPhoto]
    @Query(sort: \YearInReviewRecord.generatedDate, order: .reverse) private var allYearReviews: [YearInReviewRecord]

    #if os(iOS)
    @ObservedObject private var appleHealthService = AppleHealthService.shared
    #endif

    @Environment(\.modelContext) private var modelContext

    private var sortedPets: [Pet] {
        pets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var scopedPetId: UUID? {
        FeaturePetScope.resolvedPetId(pets: sortedPets)
    }

    private var scopedPet: Pet? {
        guard let id = scopedPetId else { return nil }
        return sortedPets.first { $0.id == id }
    }

    private var currentCalendarYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var yearReviewsForPet: [YearInReviewRecord] {
        guard let pid = scopedPetId else { return [] }
        return allYearReviews.filter { $0.petId == pid }.sorted { $0.year > $1.year }
    }

    private var yearReviewForCurrentYear: YearInReviewRecord? {
        yearReviewsForPet.first { $0.year == currentCalendarYear }
    }

    #if os(iOS)
    @State private var selectedAlbumMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedAlbumYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showingMonthPicker = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color("BrandBlue"), Color("BrandPurple")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Highlights")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color("BrandDark"))
                        Text("Stories, albums, and your pet’s year in review.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("Monthly recaps and Year in Review open in preview first—review stats, edit text, then share when you’re ready.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }

                #if os(iOS)
                if appleHealthService.isConnected, let miles = appleHealthService.summary?.totalMilesThisYear, miles > 0 {
                    Section("Activity") {
                        Text(
                            String(
                                format: "About %.1f miles of walking and running from Apple Health this year (your general activity) — Highlights use this alongside walks you log with your pet in Petpal.",
                                miles
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                #endif

                #if os(iOS)
                if let petForAlbums = scopedPet {
                    Section("Monthly albums") {
                        VStack(alignment: .leading, spacing: 14) {
                            Button {
                                showingMonthPicker = true
                            } label: {
                                HStack(spacing: 12) {
                                    albumDropdownThumbnail(petId: petForAlbums.id)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(albumDropdownTitle(petId: petForAlbums.id))
                                            .font(.headline)
                                            .foregroundStyle(Color("BrandDark"))
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.down")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                MonthlyPhotoAlbumView(pet: petForAlbums, month: selectedAlbumMonth, year: selectedAlbumYear)
                            } label: {
                                Text("View \(monthWord(selectedAlbumMonth)) Album")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            NavigationLink {
                                MonthlyRecapPreviewView(pet: petForAlbums, month: selectedAlbumMonth, year: selectedAlbumYear)
                            } label: {
                                Text("Preview & edit \(monthWord(selectedAlbumMonth)) recap")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(16)
                        .modifier(ModernCard(cornerRadius: 18))
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Year in Review") {
                    if let pet = scopedPet {
                        if let existing = yearReviewForCurrentYear {
                            NavigationLink {
                                YearInReviewPreviewView(pet: pet, record: existing)
                            } label: {
                                Label("View \(String(currentCalendarYear)) Review", systemImage: "party.popper.fill")
                            }
                        } else {
                            NavigationLink {
                                YearInReviewGeneratePreviewView(pet: pet, year: currentCalendarYear)
                            } label: {
                                Label("Preview \(String(currentCalendarYear)) in Review", systemImage: "rectangle.and.text.magnifyingglass")
                            }
                        }

                        ForEach(yearReviewsForPet.filter { $0.year != currentCalendarYear }, id: \.id) { rec in
                            NavigationLink {
                                YearInReviewPreviewView(pet: pet, record: rec)
                            } label: {
                                Text("View \(String(rec.year)) Review")
                            }
                        }
                    } else {
                        Text("Select a pet to see Year in Review.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                #endif

                Section {
                    NavigationLink {
                        MilestoneCardsListView()
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Milestone Cards")
                                    .font(.headline)
                                    .foregroundStyle(Color("BrandDark"))
                                Text("Create a card to share your pet on social media. You’ll preview the card before saving.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Swipe left on a card to delete it.")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(cardRowBackground)
                    .accessibilityHint("Opens milestone cards. Swipe left on a card to delete, or long-press a card for Delete in the menu.")
                }

            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color("BrandCream"),
                        Color("BrandSoftBlue").opacity(0.2),
                        Color("BrandCream")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Highlights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                        tabRouter.selectedTab = 0
                    }
                }
                if !sortedPets.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        FeaturePetScopePetSwitcherMenu(pets: sortedPets, pillStyle: .navigationBar)
                    }
                }
            }
            #if os(iOS)
            .task {
                await appleHealthService.refreshSummaryIfStale()
            }
            #endif
        }
        #if os(iOS)
        .sheet(isPresented: $showingMonthPicker) {
            if let pet = scopedPet {
                AlbumMonthYearPickerSheet(
                    choices: albumChoices(for: pet.id),
                    petId: pet.id,
                    allPhotos: allMonthlyPhotos,
                    selectedMonth: $selectedAlbumMonth,
                    selectedYear: $selectedAlbumYear
                )
            }
        }
        #endif
    }

    private func monthWord(_ m: Int) -> String {
        let idx = max(0, min(11, m - 1))
        return DateFormatter().monthSymbols[idx]
    }

    #if os(iOS)
    private func albumChoices(for petId: UUID) -> [(month: Int, year: Int)] {
        let cal = Calendar.current
        let now = Date()
        let cy = cal.component(.year, from: now)
        let cm = cal.component(.month, from: now)
        var seen = Set<String>()
        var result: [(Int, Int)] = []
        for p in allMonthlyPhotos where p.petId == petId {
            let key = "\(p.year)-\(p.month)"
            if seen.insert(key).inserted {
                result.append((p.month, p.year))
            }
        }
        let curKey = "\(cy)-\(cm)"
        if !seen.contains(curKey) {
            result.append((cm, cy))
        }
        result.sort { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            return a.0 > b.0
        }
        return result
    }

    private func photoCountForAlbum(petId: UUID, month: Int, year: Int) -> Int {
        allMonthlyPhotos.filter { $0.petId == petId && $0.month == month && $0.year == year }.count
    }

    private func albumDropdownTitle(petId: UUID) -> String {
        let c = photoCountForAlbum(petId: petId, month: selectedAlbumMonth, year: selectedAlbumYear)
        return "\(monthWord(selectedAlbumMonth)) \(String(selectedAlbumYear)) · \(c) photo\(c == 1 ? "" : "s")"
    }

    @ViewBuilder
    private func albumDropdownThumbnail(petId: UUID) -> some View {
        if let p = firstPhoto(for: petId, month: selectedAlbumMonth, year: selectedAlbumYear),
           let ui = UIImage(data: p.photoData) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.15))
                Image(systemName: "camera.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func firstPhoto(for petId: UUID, month: Int, year: Int) -> PetMonthlyPhoto? {
        allMonthlyPhotos
            .filter { $0.petId == petId && $0.month == month && $0.year == year }
            .sorted { $0.addedDate < $1.addedDate }
            .first
    }
    #endif

    private var cardRowBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(HighlightsTabView.secondaryGroupedFill)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private static var secondaryGroupedFill: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color.gray.opacity(0.12)
        #endif
    }

}

#if os(iOS)
private struct AlbumMonthYearPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let choices: [(month: Int, year: Int)]
    let petId: UUID
    let allPhotos: [PetMonthlyPhoto]
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(choices.enumerated()), id: \.offset) { _, pair in
                    let m = pair.month
                    let y = pair.year
                    let count = allPhotos.filter { $0.petId == petId && $0.month == m && $0.year == y }.count
                    Button {
                        selectedMonth = m
                        selectedYear = y
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            monthThumb(petId: petId, month: m, year: y)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(monthWord(m)) \(String(y))")
                                    .font(.headline)
                                    .foregroundStyle(Color("BrandDark"))
                                Text("\(count) photo\(count == 1 ? "" : "s")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if m == selectedMonth && y == selectedYear {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color("BrandBlue"))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func monthWord(_ month: Int) -> String {
        let idx = max(0, min(11, month - 1))
        return DateFormatter().monthSymbols[idx]
    }

    @ViewBuilder
    private func monthThumb(petId: UUID, month: Int, year: Int) -> some View {
        let first = allPhotos
            .filter { $0.petId == petId && $0.month == month && $0.year == year }
            .sorted { $0.addedDate < $1.addedDate }
            .first
        if let p = first, let ui = UIImage(data: p.photoData) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.15))
                .overlay {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
#endif
