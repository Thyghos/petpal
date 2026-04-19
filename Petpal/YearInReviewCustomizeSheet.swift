// Year in Review customization — persisted per pet/year.

import SwiftUI

struct YearInReviewCustomSettings: Codable, Equatable {
    var showManualWalks: Bool = true
    var showAppleHealthActivity: Bool = true
    var showActiveMinutes: Bool = true
    var showVetVisits: Bool = true
    var showVaccines: Bool = true
    var showWeightChange: Bool = true
    var showMedications: Bool = true
    var showMonthlyPhotoGrid: Bool = true
    var showMilestones: Bool = true
    var showAIConversations: Bool = false
    var includePersonalitySlide: Bool = true
}

enum YearInReviewCustomizeStorage {
    static func key(petId: UUID, year: Int) -> String {
        "yirCustomize_\(petId.uuidString)_\(year)"
    }

    static func load(petId: UUID, year: Int) -> YearInReviewCustomSettings {
        let k = key(petId: petId, year: year)
        guard let data = UserDefaults.standard.data(forKey: k),
              let decoded = try? JSONDecoder().decode(YearInReviewCustomSettings.self, from: data) else {
            return YearInReviewCustomSettings()
        }
        return decoded
    }

    static func save(_ settings: YearInReviewCustomSettings, petId: UUID, year: Int) {
        let k = key(petId: petId, year: year)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: k)
        }
    }
}

struct YearInReviewCustomizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let petName: String
    @Binding var settings: YearInReviewCustomSettings

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Choose what appears in your Year in Review slides")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Activity") {
                    Toggle("Show miles with \(petName) (manual walks)", isOn: $settings.showManualWalks)
                    Toggle("Show Apple Health activity", isOn: $settings.showAppleHealthActivity)
                    Toggle("Show active minutes", isOn: $settings.showActiveMinutes)
                }
                Section("Health") {
                    Toggle("Show vet visits count", isOn: $settings.showVetVisits)
                    Toggle("Show vaccines completed", isOn: $settings.showVaccines)
                    Toggle("Show weight change", isOn: $settings.showWeightChange)
                    Toggle("Show medications logged", isOn: $settings.showMedications)
                }
                Section("Moments") {
                    Toggle("Show monthly photo grid", isOn: $settings.showMonthlyPhotoGrid)
                    Toggle("Show milestones count", isOn: $settings.showMilestones)
                    Toggle("Show AI conversations count", isOn: $settings.showAIConversations)
                }
                Section("Personality slide") {
                    Toggle("Include personality slide", isOn: $settings.includePersonalitySlide)
                }
            }
            .navigationTitle("Customize Your Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
