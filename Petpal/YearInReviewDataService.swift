// Aggregates calendar-year stats, calls Claude for headline + personality, persists `YearInReviewRecord`.

import Foundation
import SwiftData

enum YearInReviewDataService {
    static func personalityCacheKey(petId: UUID, year: Int) -> String {
        "yearReview_\(petId.uuidString)_\(year)_personality"
    }

    static func headlineCacheKey(petId: UUID, year: Int) -> String {
        "yearReview_\(petId.uuidString)_\(year)_headline"
    }

    private static func calendarYearRange(year: Int) -> (start: Date, end: Date) {
        let cal = Calendar.current
        var s = DateComponents()
        s.year = year
        s.month = 1
        s.day = 1
        let start = cal.date(from: s) ?? Date()
        var e = DateComponents()
        e.year = year
        e.month = 12
        e.day = 31
        let end = cal.date(from: e) ?? Date()
        let today = Date()
        let cappedEnd = min(end, today)
        return (start, cappedEnd)
    }

    /// Counts `StoredVetDocument` with `createdAt` in `[start, end]`.
    static func documentsUploadedCount(from start: Date, to end: Date, context: ModelContext) -> Int {
        let docs = (try? context.fetch(FetchDescriptor<StoredVetDocument>())) ?? []
        return docs.filter { $0.createdAt >= start && $0.createdAt <= end }.count
    }

    @MainActor
    static func aggregateStats(
        pet: Pet,
        year: Int,
        modelContext: ModelContext,
        appleHealthSummary: AppleHealthSummary?
    ) throws -> YearInReviewRecord {
        let (start, end) = calendarYearRange(year: year)
        let pid = pet.id

        let visits = (try? modelContext.fetch(FetchDescriptor<VetVisitLog>())) ?? []
        let vetVisitsCount = visits.filter { v in
            guard v.petId == pid else { return false }
            let d = v.visitDate
            return d >= start && d <= end
        }.count

        let milestones = (try? modelContext.fetch(FetchDescriptor<MilestoneRecord>())) ?? []
        let milestonesCount = milestones.filter { m in
            guard m.petId == pid else { return false }
            let d = m.triggeredDate
            return d >= start && d <= end
        }.count

        let reminders = (try? modelContext.fetch(FetchDescriptor<PetReminder>())) ?? []
        let medicationsLoggedCount = reminders.filter { r in
            guard r.petId == pid, r.category == "Medication" else { return false }
            return r.createdDate >= start && r.createdDate <= end
        }.count

        let certs = (try? modelContext.fetch(FetchDescriptor<PetCertificate>())) ?? []
        let vaccinesCompletedCount = certs.filter { c in
            guard c.petId == pid else { return false }
            return c.updatedAt >= start && c.updatedAt <= end
        }.count

        let manualWalks = (try? modelContext.fetch(FetchDescriptor<ManualWalkEntry>())) ?? []
        let walksInYear = manualWalks.filter { w in
            guard let wid = w.petId, wid == pid else { return false }
            let d = w.walkDate
            return d >= start && d <= end
        }
        let totalWalksWithPet = walksInYear.count
        let totalMilesWithPet = walksInYear.reduce(0.0) { acc, w in
            acc + Self.manualWalkDistanceMiles(distance: w.distance, unit: w.distanceUnit)
        }

        let weights = (try? modelContext.fetch(FetchDescriptor<PetWeightEntry>())) ?? []
        let scoped = weights.filter { $0.petId == pid && $0.entryDate >= start && $0.entryDate <= end }
            .sorted { $0.entryDate < $1.entryDate }
        let weightChangeText: String? = {
            guard let first = scoped.first, let last = scoped.last else { return nil }
            if first.id == last.id { return "Stable" }
            let unit = pet.weightUnit.lowercased().contains("kg") ? "kg" : "lbs"
            let from = displayWeightKg(first.weightKg, unit: unit)
            let to = displayWeightKg(last.weightKg, unit: unit)
            let delta = to - from
            if abs(delta) < 0.05 { return "Stable" }
            let sign = delta > 0 ? "+" : ""
            return "\(sign)\(String(format: "%.1f", delta)) \(unit)"
        }()

        /// Apple Health activity distance for the calendar year (general owner activity).
        var totalActivityMiles: Double = 0
        var totalSteps: Int = 0
        var totalActiveMinutes: Int = 0
        if let s = appleHealthSummary {
            for m in s.walksByMonth where m.year == year {
                totalActivityMiles += m.miles
                totalSteps += m.steps
                totalActiveMinutes += m.activeMinutes
            }
        }

        let record = YearInReviewRecord(petId: pid, year: year)
        record.generatedDate = Date()
        record.vetVisitsCount = vetVisitsCount
        record.milestonesCount = milestonesCount
        record.medicationsLoggedCount = medicationsLoggedCount
        record.vaccinesCompletedCount = vaccinesCompletedCount
        record.weightChangeText = weightChangeText
        record.totalMiles = totalActivityMiles
        record.totalSteps = totalSteps
        record.totalWalksWithPet = totalWalksWithPet
        record.totalMilesWithPet = totalMilesWithPet
        record.aiConversationsCount = 0
        return record
    }

    private static func manualWalkDistanceMiles(distance: Double, unit: String) -> Double {
        unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "km"
            ? distance * 0.621371192
            : distance
    }

    private static func displayWeightKg(_ kg: Double, unit: String) -> Double {
        if unit.lowercased().contains("kg") { return kg }
        return kg * 2.2046226218
    }

    @MainActor
    static func generateOrUpdate(
        pet: Pet,
        year: Int,
        modelContext: ModelContext,
        appleHealthSummary: AppleHealthSummary?,
        forceRefreshAI: Bool
    ) async throws -> YearInReviewRecord {
        let stats = try aggregateStats(pet: pet, year: year, modelContext: modelContext, appleHealthSummary: appleHealthSummary)

        let allY = (try? modelContext.fetch(FetchDescriptor<YearInReviewRecord>())) ?? []
        let existing = allY.first { $0.petId == pet.id && $0.year == year }

        let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedLine = breed.isEmpty ? pet.species : breed
        let petName = pet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your pet" : pet.name

        var personality = UserDefaults.standard.string(forKey: personalityCacheKey(petId: pet.id, year: year))
        var headline = UserDefaults.standard.string(forKey: headlineCacheKey(petId: pet.id, year: year))

        if forceRefreshAI {
            personality = nil
            headline = nil
        }

        if personality == nil || personality?.isEmpty == true {
            do {
                personality = try await ClaudeShortTextAPI.yearPersonalityLine(
                    petName: petName,
                    breed: breedLine,
                    vetVisits: stats.vetVisitsCount,
                    walksWithPet: stats.totalWalksWithPet,
                    milesWithPet: stats.totalMilesWithPet,
                    milestones: stats.milestonesCount
                )
            } catch {
                personality = "\(petName) brought joy, logged walks, and a little chaos this year."
            }
            UserDefaults.standard.set(personality, forKey: personalityCacheKey(petId: pet.id, year: year))
        }

        if headline == nil || headline?.isEmpty == true {
            do {
                headline = try await ClaudeShortTextAPI.yearHeadline(petName: petName, year: year)
            } catch {
                headline = "A year of tail wags and together time"
            }
            UserDefaults.standard.set(headline, forKey: headlineCacheKey(petId: pet.id, year: year))
        }

        stats.personalityLine = personality
        stats.yearHeadline = headline

        if let existing {
            existing.generatedDate = Date()
            existing.personalityLine = stats.personalityLine
            existing.yearHeadline = stats.yearHeadline
            existing.totalMiles = stats.totalMiles
            existing.totalSteps = stats.totalSteps
            existing.totalWalksWithPet = stats.totalWalksWithPet
            existing.totalMilesWithPet = stats.totalMilesWithPet
            existing.vetVisitsCount = stats.vetVisitsCount
            existing.milestonesCount = stats.milestonesCount
            existing.weightChangeText = stats.weightChangeText
            existing.vaccinesCompletedCount = stats.vaccinesCompletedCount
            existing.medicationsLoggedCount = stats.medicationsLoggedCount
            existing.aiConversationsCount = 0
            try? modelContext.save()
            return existing
        }

        modelContext.insert(stats)
        try? modelContext.save()
        return stats
    }
}
