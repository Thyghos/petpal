// MilestoneType.swift
// Milestone kinds for cards, notifications, and SwiftData `MilestoneRecord.milestoneType`.

import Foundation

enum MilestoneType: String, CaseIterable, Identifiable {
    case birthday
    case adoptionAnniversary
    case firstVetVisit
    case healthyVetVisit
    case vaccinesUpToDate
    case oneYearInPetpal
    case custom

    var id: String { rawValue }

    /// Shown in the manual milestone generator. `firstVetVisit` is automatic-only.
    static var manualGeneratorCases: [MilestoneType] {
        allCases.filter { $0 != .firstVetVisit }
    }

    /// Evaluated by `MilestoneCheckService` on startup. Manual-only types are excluded.
    static var automaticDetectionCases: [MilestoneType] {
        allCases.filter { $0 != .healthyVetVisit && $0 != .custom }
    }

    var displayName: String {
        switch self {
        case .birthday: return "Happy Birthday"
        case .adoptionAnniversary: return "Adoption Anniversary"
        case .firstVetVisit: return "First Vet Visit"
        case .healthyVetVisit: return "Healthy Vet Visit"
        case .vaccinesUpToDate: return "Vaccines Up to Date"
        case .oneYearInPetpal: return "1 Year in Petpal"
        case .custom: return "Custom Moment"
        }
    }

    var emoji: String {
        switch self {
        case .birthday: return "🎂"
        case .adoptionAnniversary: return "🏠"
        case .firstVetVisit: return "🩺"
        case .healthyVetVisit: return "🏥"
        case .vaccinesUpToDate: return "✅"
        case .oneYearInPetpal: return "🐾"
        case .custom: return "✨"
        }
    }

    var sfSymbol: String {
        switch self {
        case .birthday: return "birthday.cake"
        case .adoptionAnniversary: return "house.heart.fill"
        case .firstVetVisit: return "cross.case.fill"
        case .healthyVetVisit: return "cross.case.fill"
        case .vaccinesUpToDate: return "checkmark.seal.fill"
        case .oneYearInPetpal: return "pawprint.fill"
        case .custom: return "star.fill"
        }
    }

    /// Push body; use `[Pet Name]` placeholder. Empty string means no notification (manual-only types).
    var notificationBody: String {
        switch self {
        case .birthday:
            return "[Pet Name]'s birthday is today!"
        case .adoptionAnniversary:
            return "Today is [Pet Name]'s adoption anniversary!"
        case .firstVetVisit:
            return "[Pet Name] just had their first vet visit logged!"
        case .healthyVetVisit:
            return ""
        case .vaccinesUpToDate:
            return "[Pet Name]'s vaccines are all up to date!"
        case .oneYearInPetpal:
            return "[Pet Name] has been in Petpal for a whole year!"
        case .custom:
            return ""
        }
    }

    /// Card headline; use `[Pet Name]` placeholder. Empty for `custom` — use `MilestoneRecord.customCardTitle`.
    var cardTitle: String {
        switch self {
        case .birthday:
            return "Happy Birthday, [Pet Name]!"
        case .adoptionAnniversary:
            return "[Pet Name]'s Adoption Anniversary"
        case .firstVetVisit:
            return "[Pet Name]'s First Vet Visit"
        case .healthyVetVisit:
            return "[Pet Name] Got a Clean Bill of Health!"
        case .vaccinesUpToDate:
            return "[Pet Name] is Fully Vaccinated"
        case .oneYearInPetpal:
            return "1 Year with [Pet Name] in Petpal"
        case .custom:
            return ""
        }
    }

    func replacingPetName(_ name: String, in template: String) -> String {
        template.replacingOccurrences(of: "[Pet Name]", with: name)
    }
}
