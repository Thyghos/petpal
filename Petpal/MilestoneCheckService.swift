// MilestoneCheckService.swift
// Detects pet milestones, optional Claude fun line (Vet AI proxy), local notifications, and monthly highlight reminder.

import Foundation
import SwiftData

#if os(iOS)
import UserNotifications
import UIKit
#endif

private enum MilestoneAnthropicError: Error {
    case missingProxy
}

/// Generates a short celebratory line via the Vet AI Cloudflare proxy (same path as Vet AI / PDF parsers).
private enum MilestoneFunLineAPI {
    static func generateFunStatLine(petName: String, breed: String, milestoneDisplayName: String) async throws -> String {
        guard APIConfiguration.vetAIProxyURL != nil else {
            throw MilestoneAnthropicError.missingProxy
        }

        let system = """
        You are a warm, playful pet milestone writer. Write one short celebratory sentence (max 12 words) for a pet named \(petName) who is a \(breed). The milestone is: \(milestoneDisplayName). Make it heartfelt and specific to the milestone. No hashtags.
        """

        let userContent = """
        \(system)

        Write the sentence only, no quotes.
        """

        let reply = try await ClaudeProxyClient.send(
            messages: [["role": "user", "content": userContent]],
            petName: petName,
            petSpecies: breed,
            petContext: ""
        )
        return reply.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class MilestoneCheckService {
    static let shared = MilestoneCheckService()

    private init() {}

    private static let monthlyReminderId = "com.thyghos.petpalapp.monthlyHighlights"

    /// App launch + foreground: milestone scan + rolling monthly reminder.
    func runStartupChecks(modelContext: ModelContext) async {
        let pets = (try? modelContext.fetch(FetchDescriptor<Pet>())) ?? []
        let sorted = pets.sorted { $0.dateAdded < $1.dateAdded }
        await checkMilestones(for: sorted, context: modelContext)
        #if os(iOS)
        await scheduleNextMonthlyHighlightReminder(pets: sorted, modelContext: modelContext)
        #endif
    }

    func checkMilestones(for pets: [Pet], context: ModelContext) async {
        guard !pets.isEmpty else { return }
        #if os(iOS)
        await PetReminderNotificationService.requestPermissionIfNeeded()
        #endif

        let visits = (try? context.fetch(FetchDescriptor<VetVisitLog>())) ?? []
        let certs = (try? context.fetch(FetchDescriptor<PetCertificate>())) ?? []
        let cal = Calendar.current
        let today = Date()
        let currentYear = cal.component(.year, from: today)

        for pet in pets {
            let pid = pet.id
            for milestone in MilestoneType.automaticDetectionCases {
                if hasTriggeredDefaults(petId: pid, type: milestone, year: currentYear) { continue }
                guard evaluateCondition(
                    milestone: milestone,
                    pet: pet,
                    visits: visits,
                    certificates: certs,
                    calendar: cal,
                    today: today
                ) else { continue }

                var funLine: String?
                do {
                    let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
                    let breedOrSpecies = breed.isEmpty ? pet.species : breed
                    funLine = try await MilestoneFunLineAPI.generateFunStatLine(
                        petName: pet.name.isEmpty ? "Your pet" : pet.name,
                        breed: breedOrSpecies.isEmpty ? "pet" : breedOrSpecies,
                        milestoneDisplayName: milestone.displayName
                    )
                } catch {
                    funLine = nil
                }

                let record = MilestoneRecord(
                    petId: pid,
                    milestoneType: milestone.rawValue,
                    triggeredDate: today,
                    year: currentYear,
                    funStatLine: funLine,
                    wasAutoTriggered: true
                )
                context.insert(record)
                try? context.save()

                markTriggeredDefaults(petId: pid, type: milestone, year: currentYear)

                #if os(iOS)
                await scheduleMilestoneNotification(pet: pet, milestone: milestone)
                #endif
            }
        }
    }

    // MARK: - Conditions

    private func evaluateCondition(
        milestone: MilestoneType,
        pet: Pet,
        visits: [VetVisitLog],
        certificates: [PetCertificate],
        calendar cal: Calendar,
        today: Date
    ) -> Bool {
        let pid = pet.id
        switch milestone {
        case .birthday:
            guard let dob = pet.dateOfBirth else { return false }
            return cal.component(.month, from: dob) == cal.component(.month, from: today)
                && cal.component(.day, from: dob) == cal.component(.day, from: today)

        case .adoptionAnniversary:
            let added = pet.dateAdded
            let years = cal.dateComponents([.year], from: added, to: today).year ?? 0
            guard years > 0 else { return false }
            return cal.component(.month, from: added) == cal.component(.month, from: today)
                && cal.component(.day, from: added) == cal.component(.day, from: today)

        case .firstVetVisit:
            if firstVetVisitEverTriggered(petId: pid) { return false }
            let scoped = visits.filter { $0.petId == pid }
            return !scoped.isEmpty

        case .healthyVetVisit:
            return false

        case .custom:
            return false

        case .vaccinesUpToDate:
            let vaccines = certificates.filter { $0.petId == pid && $0.category == "Vaccine" }
            guard !vaccines.isEmpty else { return false }
            let startOfToday = cal.startOfDay(for: today)
            for v in vaccines {
                if let exp = v.expirationDate, cal.startOfDay(for: exp) < startOfToday {
                    return false
                }
            }
            return true

        case .oneYearInPetpal:
            let added = pet.dateAdded
            let years = cal.dateComponents([.year], from: added, to: today).year ?? 0
            guard years == 1 else { return false }
            return cal.component(.month, from: added) == cal.component(.month, from: today)
                && cal.component(.day, from: added) == cal.component(.day, from: today)
        }
    }

    // MARK: - UserDefaults

    private func defaultsKey(petId: UUID, type: MilestoneType, year: Int) -> String {
        "milestone_\(petId.uuidString)_\(type.rawValue)_\(year)"
    }

    private func firstVetDefaultsKey(petId: UUID) -> String {
        "milestone_\(petId.uuidString)_firstVetVisit"
    }

    private func hasTriggeredDefaults(petId: UUID, type: MilestoneType, year: Int) -> Bool {
        if type == .firstVetVisit {
            return UserDefaults.standard.bool(forKey: firstVetDefaultsKey(petId: petId))
        }
        return UserDefaults.standard.bool(forKey: defaultsKey(petId: petId, type: type, year: year))
    }

    private func markTriggeredDefaults(petId: UUID, type: MilestoneType, year: Int) {
        if type == .firstVetVisit {
            UserDefaults.standard.set(true, forKey: firstVetDefaultsKey(petId: petId))
        } else {
            UserDefaults.standard.set(true, forKey: defaultsKey(petId: petId, type: type, year: year))
        }
    }

    private func firstVetVisitEverTriggered(petId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: firstVetDefaultsKey(petId: petId))
    }

    /// Exposed so manual generator can mark first-vet without duplicating logic.
    func markFirstVetTriggeredIfNeeded(petId: UUID) {
        UserDefaults.standard.set(true, forKey: firstVetDefaultsKey(petId: petId))
    }

    // MARK: - Notifications (iOS)

    #if os(iOS)
    /// Display name for milestone alerts — always from `pet.name`, never microchip or UUID.
    private static func milestoneNotificationPetName(_ pet: Pet) -> String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your pet" : trimmed
    }

    private func milestoneCanSchedule() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Uses `pet.name` only (never microchip or id) so the lock-screen line reads naturally, e.g. “Lucy just had…”.
    private func scheduleMilestoneNotification(pet: Pet, milestone: MilestoneType) async {
        guard await milestoneCanSchedule() else { return }
        let bodyTemplate = milestone.notificationBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bodyTemplate.isEmpty else { return }
        let displayName = Self.milestoneNotificationPetName(pet)
        let content = UNMutableNotificationContent()
        content.title = milestone.displayName
        content.body = milestone.replacingPetName(displayName, in: bodyTemplate)
        content.sound = .default
        content.userInfo = [
            "petId": pet.id.uuidString,
            "milestoneType": milestone.rawValue
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let id = "com.thyghos.petpalapp.milestone.\(UUID().uuidString)"
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)
    }

    /// Last day of month at 19:00 local; rescheduled on each call so the next window is always correct.
    func scheduleNextMonthlyHighlightReminder(pets: [Pet], modelContext: ModelContext) async {
        await PetReminderNotificationService.requestPermissionIfNeeded()
        guard await milestoneCanSchedule() else { return }

        let petName = activePetDisplayName(pets: pets, modelContext: modelContext)
        guard let fireDate = Self.nextLastDayOfMonthSevenPM(from: Date()) else { return }

        let cal = Calendar.current
        let monthIndex = cal.component(.month, from: fireDate) - 1
        let monthWord = DateFormatter().monthSymbols[monthIndex]

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.monthlyReminderId])

        let content = UNMutableNotificationContent()
        content.title = "How was \(petName)'s \(monthWord)?"
        content.body = "Add your favorite highlights from this month! 🐾"
        content.sound = .default

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: Self.monthlyReminderId, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(req)

        if !UserDefaults.standard.bool(forKey: "hasScheduledMonthlyPhotoReminder") {
            UserDefaults.standard.set(true, forKey: "hasScheduledMonthlyPhotoReminder")
        }
    }

    private func activePetDisplayName(pets: [Pet], modelContext: ModelContext) -> String {
        let sorted = pets.sorted { $0.dateAdded < $1.dateAdded }
        guard let id = ActivePetResolver.resolvedPetId(pets: sorted),
              let pet = sorted.first(where: { $0.id == id }) else {
            return "your pet"
        }
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "your pet" : n
    }

    private static func nextLastDayOfMonthSevenPM(from now: Date) -> Date? {
        let cal = Calendar.current
        func lastDayAt7PM(containing date: Date) -> Date? {
            let y = cal.component(.year, from: date)
            let mo = cal.component(.month, from: date)
            guard let dayR = cal.range(of: .day, in: .month, for: date) else { return nil }
            let last = dayR.upperBound - 1
            return cal.date(from: DateComponents(year: y, month: mo, day: last, hour: 19, minute: 0))
        }
        guard let candidate = lastDayAt7PM(containing: now) else { return nil }
        if candidate > now { return candidate }
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)),
              let nextMonth = cal.date(byAdding: .month, value: 1, to: monthStart) else { return nil }
        return lastDayAt7PM(containing: nextMonth)
    }
    #endif
}

extension MilestoneCheckService {
    /// Manual card from the generator; marks UserDefaults like an automatic trigger for this year (and first-vet key when applicable).
    func createManualMilestone(
        for pet: Pet,
        type: MilestoneType,
        context: ModelContext,
        cardPhotoData: Data? = nil,
        customCardTitle: String? = nil,
        customFunStatLine: String? = nil
    ) async -> MilestoneRecord {
        let year = Calendar.current.component(.year, from: Date())
        let funLine: String?
        let storedCustomTitle: String?
        if type == .custom {
            let trimNonEmpty: (String?) -> String? = { s in
                guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
                return t
            }
            storedCustomTitle = trimNonEmpty(customCardTitle)
            funLine = trimNonEmpty(customFunStatLine)
        } else {
            storedCustomTitle = nil
            do {
                let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
                let breedOrSpecies = breed.isEmpty ? pet.species : breed
                funLine = try await MilestoneFunLineAPI.generateFunStatLine(
                    petName: pet.name.isEmpty ? "Your pet" : pet.name,
                    breed: breedOrSpecies.isEmpty ? "pet" : breedOrSpecies,
                    milestoneDisplayName: type.displayName
                )
            } catch {
                funLine = nil
            }
        }
        let record = MilestoneRecord(
            petId: pet.id,
            milestoneType: type.rawValue,
            triggeredDate: Date(),
            year: year,
            funStatLine: funLine,
            wasAutoTriggered: false,
            cardPhotoData: cardPhotoData,
            customCardTitle: storedCustomTitle
        )
        context.insert(record)
        try? context.save()
        markTriggeredDefaults(petId: pet.id, type: type, year: year)
        return record
    }

    /// Fresh Claude `funStatLine` for an existing card (same Vet AI proxy as manual creation).
    @MainActor
    func regenerateFunStatLine(
        for record: MilestoneRecord,
        pet: Pet,
        modelContext: ModelContext
    ) async {
        guard let type = MilestoneType(rawValue: record.milestoneType) else { return }
        let milestoneDisplayName: String
        if type == .custom {
            let t = record.customCardTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            milestoneDisplayName = t.isEmpty ? "Custom moment" : t
        } else {
            milestoneDisplayName = type.displayName
        }
        let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedOrSpecies = breed.isEmpty ? pet.species : breed
        do {
            let line = try await MilestoneFunLineAPI.generateFunStatLine(
                petName: pet.name.isEmpty ? "Your pet" : pet.name,
                breed: breedOrSpecies.isEmpty ? "pet" : breedOrSpecies,
                milestoneDisplayName: milestoneDisplayName
            )
            record.funStatLine = line
            try? modelContext.save()
        } catch {}
    }
}
