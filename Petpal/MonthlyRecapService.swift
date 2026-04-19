// Builds stats + optional Claude one-liner for a pet’s monthly recap.

import Foundation
import SwiftData

enum MonthlyRecapService {
    private static func cacheKey(petId: UUID, year: Int, month: Int) -> String {
        "monthlyRecap_\(petId.uuidString)_\(year)_\(month)"
    }

    static func cachedOneLiner(petId: UUID, year: Int, month: Int) -> String? {
        let k = cacheKey(petId: petId, year: year, month: month)
        let s = UserDefaults.standard.string(forKey: k)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty == false) ? s : nil
    }

    static func setCachedOneLiner(_ line: String?, petId: UUID, year: Int, month: Int) {
        let k = cacheKey(petId: petId, year: year, month: month)
        if let line, !line.isEmpty {
            UserDefaults.standard.set(line, forKey: k)
        } else {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }

    struct MonthlyStats {
        var vetVisits: Int
        /// Same as `milestoneRecords.count` — kept for AI / fallback text.
        var milestones: Int
        var miles: Double
        var steps: Int
        var activeMinutes: Int
        var manualWalksCount: Int
        var manualWalksMiles: Double
        /// Single source for recap card: milestones with `triggeredDate` in this month.
        var milestoneRecords: [MilestoneRecord]
    }

    /// All highlight photos for the month, newest first (for recap collage up to 9).
    @MainActor
    static func monthlyPhotos(
        petId: UUID,
        month: Int,
        year: Int,
        modelContext: ModelContext
    ) -> [PetMonthlyPhoto] {
        let all = (try? modelContext.fetch(FetchDescriptor<PetMonthlyPhoto>())) ?? []
        return all.filter { $0.petId == petId && $0.month == month && $0.year == year }
            .sorted { $0.addedDate > $1.addedDate }
    }

    /// Milestones for `petId` whose `triggeredDate` falls in the given calendar month.
    @MainActor
    static func milestoneRecordsInMonth(
        petId: UUID,
        month: Int,
        year: Int,
        modelContext: ModelContext
    ) -> [MilestoneRecord] {
        let cal = Calendar.current
        var startComps = DateComponents()
        startComps.year = year
        startComps.month = month
        startComps.day = 1
        guard let monthStart = cal.date(from: startComps),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return []
        }
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: monthEnd) ?? monthEnd
        let allMilestones = (try? modelContext.fetch(FetchDescriptor<MilestoneRecord>())) ?? []
        return allMilestones.filter { m in
            guard m.petId == petId else { return false }
            let d = m.triggeredDate
            return d >= monthStart && d <= endOfDay
        }
    }

    /// Visits and milestones in calendar month; activity from Apple Health monthly bucket when available.
    @MainActor
    static func computeStats(
        petId: UUID,
        month: Int,
        year: Int,
        modelContext: ModelContext,
        appleHealthSummary: AppleHealthSummary?
    ) throws -> MonthlyStats {
        let cal = Calendar.current
        var startComps = DateComponents()
        startComps.year = year
        startComps.month = month
        startComps.day = 1
        guard let monthStart = cal.date(from: startComps),
              let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return MonthlyStats(
                vetVisits: 0,
                milestones: 0,
                miles: 0,
                steps: 0,
                activeMinutes: 0,
                manualWalksCount: 0,
                manualWalksMiles: 0,
                milestoneRecords: []
            )
        }
        let endOfDay = cal.date(bySettingHour: 23, minute: 59, second: 59, of: monthEnd) ?? monthEnd

        let visits = (try? modelContext.fetch(FetchDescriptor<VetVisitLog>())) ?? []
        let vetVisits = visits.filter { v in
            guard v.petId == petId else { return false }
            let d = v.visitDate
            return d >= monthStart && d <= endOfDay
        }.count

        let monthMilestones = milestoneRecordsInMonth(petId: petId, month: month, year: year, modelContext: modelContext)
        let milestoneCount = monthMilestones.count

        var miles: Double = 0
        var steps: Int = 0
        var activeMinutes: Int = 0
        if let summary = appleHealthSummary,
           let ma = summary.walksByMonth.first(where: { $0.month == month && $0.year == year }) {
            miles = ma.miles
            steps = ma.steps
            activeMinutes = ma.activeMinutes
        }

        let allWalks = (try? modelContext.fetch(FetchDescriptor<ManualWalkEntry>())) ?? []
        let monthWalks = allWalks.filter { w in
            guard let wid = w.petId, wid == petId else { return false }
            let d = w.walkDate
            return d >= monthStart && d <= endOfDay
        }
        let manualWalksCount = monthWalks.count
        let manualWalksMiles = monthWalks.reduce(0.0) { acc, w in
            acc + Self.manualWalkDistanceMiles(distance: w.distance, unit: w.distanceUnit)
        }

        return MonthlyStats(
            vetVisits: vetVisits,
            milestones: milestoneCount,
            miles: miles,
            steps: steps,
            activeMinutes: activeMinutes,
            manualWalksCount: manualWalksCount,
            manualWalksMiles: manualWalksMiles,
            milestoneRecords: monthMilestones
        )
    }

    private static func manualWalkDistanceMiles(distance: Double, unit: String) -> Double {
        unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "km"
            ? distance * 0.621371192
            : distance
    }

    /// Returns AI line, using cache when `useCache` and cache hit; otherwise calls Claude and caches.
    @MainActor
    static func oneLiner(
        petName: String,
        petId: UUID,
        month: Int,
        year: Int,
        monthName: String,
        stats: MonthlyStats,
        forceRefresh: Bool
    ) async -> String {
        if !forceRefresh, let c = cachedOneLiner(petId: petId, year: year, month: month) {
            return c
        }
        do {
            let line = try await ClaudeShortTextAPI.monthlyRecapLine(
                petName: petName,
                monthName: monthName,
                vetVisits: stats.vetVisits,
                milestones: stats.milestones,
                manualWalks: stats.manualWalksCount,
                manualMiles: stats.manualWalksMiles
            )
            setCachedOneLiner(line, petId: petId, year: year, month: month)
            return line
        } catch {
            let fallback = "\(petName) had a memorable \(monthName) — \(stats.vetVisits) vet visit\(stats.vetVisits == 1 ? "" : "s"), \(stats.manualWalksCount) walk\(stats.manualWalksCount == 1 ? "" : "s"), and \(stats.milestones) milestone\(stats.milestones == 1 ? "" : "s")."
            setCachedOneLiner(fallback, petId: petId, year: year, month: month)
            return fallback
        }
    }
}
