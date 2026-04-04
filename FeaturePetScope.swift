// FeaturePetScope.swift
// Resolves which pet feature screens use and provides a header + in-tab pet switcher.

import SwiftUI
import SwiftData

enum FeaturePetScope {
    /// One-time: assign reminders / visits / policies with `petId == nil` to the active pet so they appear in exactly one profile (not under every pet).
    @MainActor
    static func claimOrphanRecordsIfNeeded(activePetId: UUID?, modelContext: ModelContext) {
        guard let pid = activePetId else { return }
        do {
            var changed = false
            for r in try modelContext.fetch(FetchDescriptor<PetReminder>()) where r.petId == nil {
                r.petId = pid
                changed = true
            }
            for v in try modelContext.fetch(FetchDescriptor<VetVisitLog>()) where v.petId == nil {
                v.petId = pid
                changed = true
            }
            for p in try modelContext.fetch(FetchDescriptor<PetInsuranceInfo>()) where p.petId == nil {
                p.petId = pid
                changed = true
            }
            if changed { try modelContext.save() }
        } catch {}
    }

    /// Active profile from UserDefaults, validated against stored pets, else the pet marked active in SwiftData, else single-pet fallback.
    static func resolvedPetId(pets: [Pet]) -> UUID? {
        ActivePetResolver.resolvedPetId(pets: pets)
    }

    static func currentPetName(pets: [Pet]) -> String {
        guard let id = resolvedPetId(pets: pets),
              let p = pets.first(where: { $0.id == id }) else {
            return "Your Pet"
        }
        return p.name.isEmpty ? "Your Pet" : p.name
    }

    static func activate(_ pet: Pet, allPets: [Pet], modelContext: ModelContext, healthTipPreferences: [HealthTipPreferences]) {
        for p in allPets {
            p.isActive = (p.id == pet.id)
        }
        pet.syncToLegacyAppStorage()
        if let prefs = healthTipPreferences.first, prefs.petSpecies != pet.species {
            prefs.petSpecies = pet.species
        }
        try? modelContext.save()
    }
}

/// Shown under the navigation area on feature screens: current pet name + optional switcher.
/// Pass the same `pets` array your screen already loads via `@Query` so the pet list stays in sync (a nested `@Query` here can miss pets when the parent has many SwiftData queries).
struct FeaturePetScopeHeader: View {
    @Environment(\.modelContext) private var modelContext
    let pets: [Pet]
    @Query private var healthTipPreferences: [HealthTipPreferences]

    var body: some View {
        let pid = FeaturePetScope.resolvedPetId(pets: pets)
        let current = pid.flatMap { id in pets.first { $0.id == id } } ?? pets.first

        Group {
            if let current {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Pet:")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text(current.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("BrandDark"))
                                .lineLimit(1)
                        }
                        Text("Everything below is saved to this pet. Use Switch pet to change profiles.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if pets.count > 1 {
                        Menu {
                            ForEach(pets, id: \.id) { p in
                                Button {
                                    FeaturePetScope.activate(p, allPets: pets, modelContext: modelContext, healthTipPreferences: healthTipPreferences)
                                } label: {
                                    Label(
                                        p.name,
                                        systemImage: p.id == current.id ? "checkmark" : "pawprint"
                                    )
                                }
                            }
                        } label: {
                            Label("Switch pet", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color("BrandPurple").opacity(0.14)))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
    }
}
