// AppleHealthService.swift
// Read-only HealthKit aggregation for Petpal (iOS). Summary cached in UserDefaults.

import Combine
import Foundation
import SwiftUI

// MARK: - Models (shared)

struct MonthlyActivity: Codable, Equatable, Sendable {
    var month: Int
    var year: Int
    var steps: Int
    var miles: Double
    var activeMinutes: Int
}

struct AppleHealthSummary: Codable, Equatable, Sendable {
    var totalStepsThisYear: Int
    var totalMilesThisYear: Double
    var totalActiveMinutesThisYear: Int
    var totalCaloriesThisYear: Int
    var walksByMonth: [MonthlyActivity]
}

enum AppleHealthUserDefaultsKeys {
    static let hasPromptedHealthKit = "hasPromptedHealthKit"
    static let summaryCache = "appleHealthSummaryCache"
    static let summaryCacheDate = "appleHealthSummaryCacheDate"
    static let userConnected = "appleHealthUserConnected"
    static let lastSyncDate = "appleHealthLastSyncDate"
}

#if os(iOS)
import HealthKit

@MainActor
final class AppleHealthService: ObservableObject {
    static let shared = AppleHealthService()

    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    @Published private(set) var summary: AppleHealthSummary?
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var lastSyncDate: Date?

    private var readTypes: Set<HKObjectType> {
        var s = Set<HKObjectType>()
        if let t = HKQuantityType.quantityType(forIdentifier: .stepCount) { s.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { s.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { s.insert(t) }
        if let t = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) { s.insert(t) }
        return s
    }

    private init() {
        loadPersistedState()
    }

    private func loadPersistedState() {
        if !HKHealthStore.isHealthDataAvailable() {
            isConnected = false
            UserDefaults.standard.set(false, forKey: AppleHealthUserDefaultsKeys.userConnected)
            summary = nil
            return
        }
        let optedIn = UserDefaults.standard.bool(forKey: AppleHealthUserDefaultsKeys.userConnected)
        isConnected = optedIn
        if let ts = UserDefaults.standard.object(forKey: AppleHealthUserDefaultsKeys.lastSyncDate) as? TimeInterval {
            lastSyncDate = Date(timeIntervalSince1970: ts)
        }
        if optedIn,
           let json = UserDefaults.standard.string(forKey: AppleHealthUserDefaultsKeys.summaryCache),
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(AppleHealthSummary.self, from: data) {
            summary = decoded
        } else {
            summary = nil
        }
    }

    /// Call after Health tab first visit or Settings connect.
    func requestReadAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isConnected = false
            UserDefaults.standard.set(false, forKey: AppleHealthUserDefaultsKeys.userConnected)
            return
        }
        let types = readTypes
        guard !types.isEmpty else { return }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: types)
        } catch {
            isConnected = false
            UserDefaults.standard.set(false, forKey: AppleHealthUserDefaultsKeys.userConnected)
            UserDefaults.standard.set(true, forKey: AppleHealthUserDefaultsKeys.hasPromptedHealthKit)
            return
        }
        UserDefaults.standard.set(true, forKey: AppleHealthUserDefaultsKeys.hasPromptedHealthKit)
        UserDefaults.standard.set(true, forKey: AppleHealthUserDefaultsKeys.userConnected)
        isConnected = true
        await refreshSummaryIfStale(force: true)
    }

    /// Refreshes from HealthKit at most once per calendar day unless `force`.
    func refreshSummaryIfStale(force: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable(),
              UserDefaults.standard.bool(forKey: AppleHealthUserDefaultsKeys.userConnected) else {
            summary = nil
            return
        }

        if !force, let cachedDate = UserDefaults.standard.object(forKey: AppleHealthUserDefaultsKeys.summaryCacheDate) as? TimeInterval {
            let last = Date(timeIntervalSince1970: cachedDate)
            if calendar.isDateInToday(last), let json = UserDefaults.standard.string(forKey: AppleHealthUserDefaultsKeys.summaryCache),
               let data = json.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(AppleHealthSummary.self, from: data) {
                summary = decoded
                lastSyncDate = last
                return
            }
        }

        let end = Date()
        guard let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: end)) else { return }

        async let steps = cumulativeSum(for: .stepCount, unit: HKUnit.count(), from: startOfYear, to: end)
        async let miles = cumulativeSum(for: .distanceWalkingRunning, unit: HKUnit.mile(), from: startOfYear, to: end)
        async let calories = cumulativeSum(for: .activeEnergyBurned, unit: HKUnit.kilocalorie(), from: startOfYear, to: end)
        async let exerciseMinutes = cumulativeSum(for: .appleExerciseTime, unit: HKUnit.minute(), from: startOfYear, to: end)
        async let monthly = monthlyActivity(from: startOfYear, to: end)

        let (sTotal, miTotal, kcalTotal, exTotal, months) = await (steps, miles, calories, exerciseMinutes, monthly)

        let newSummary = AppleHealthSummary(
            totalStepsThisYear: Int(sTotal.rounded()),
            totalMilesThisYear: miTotal,
            totalActiveMinutesThisYear: Int(exTotal.rounded()),
            totalCaloriesThisYear: Int(kcalTotal.rounded()),
            walksByMonth: months
        )

        summary = newSummary
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: AppleHealthUserDefaultsKeys.lastSyncDate)
        if let encoded = try? JSONEncoder().encode(newSummary), let str = String(data: encoded, encoding: .utf8) {
            if str.utf8.count < 500_000 {
                UserDefaults.standard.set(str, forKey: AppleHealthUserDefaultsKeys.summaryCache)
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: AppleHealthUserDefaultsKeys.summaryCacheDate)
            } else {
                print("AppleHealthService: summaryCache too large (\(str.utf8.count) bytes), skipping UserDefaults write")
            }
        }
    }

    func disconnect() {
        UserDefaults.standard.removeObject(forKey: AppleHealthUserDefaultsKeys.summaryCache)
        UserDefaults.standard.removeObject(forKey: AppleHealthUserDefaultsKeys.summaryCacheDate)
        UserDefaults.standard.removeObject(forKey: AppleHealthUserDefaultsKeys.lastSyncDate)
        UserDefaults.standard.set(false, forKey: AppleHealthUserDefaultsKeys.userConnected)
        UserDefaults.standard.set(false, forKey: AppleHealthUserDefaultsKeys.hasPromptedHealthKit)
        summary = nil
        lastSyncDate = nil
        isConnected = false
    }

    // MARK: - HK queries

    private func cumulativeSum(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let v = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: v)
            }
            healthStore.execute(q)
        }
    }

    private func monthlyActivity(from start: Date, to end: Date) async -> [MonthlyActivity] {
        var months: [MonthlyActivity] = []
        var monthStart = calendar.startOfDay(for: start)
        while monthStart < end {
            let capturedMonthStart = monthStart
            let comps = calendar.dateComponents([.month, .year], from: capturedMonthStart)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: capturedMonthStart) else { break }
            let intervalEnd = min(nextMonth.addingTimeInterval(-1), end)

            async let steps = cumulativeSum(for: .stepCount, unit: HKUnit.count(), from: capturedMonthStart, to: intervalEnd)
            async let miles = cumulativeSum(for: .distanceWalkingRunning, unit: HKUnit.mile(), from: capturedMonthStart, to: intervalEnd)
            async let mins = cumulativeSum(for: .appleExerciseTime, unit: HKUnit.minute(), from: capturedMonthStart, to: intervalEnd)

            let (s, m, ex) = await (steps, miles, mins)
            months.append(
                MonthlyActivity(
                    month: comps.month ?? 1,
                    year: comps.year ?? calendar.component(.year, from: capturedMonthStart),
                    steps: Int(s.rounded()),
                    miles: m,
                    activeMinutes: Int(ex.rounded())
                )
            )
            monthStart = nextMonth
            if months.count > 24 { break }
        }
        return months
    }
}

#else

@MainActor
final class AppleHealthService: ObservableObject {
    static let shared = AppleHealthService()
    @Published private(set) var summary: AppleHealthSummary?
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var lastSyncDate: Date?

    func requestReadAuthorization() async {}
    func refreshSummaryIfStale(force: Bool = false) async {}
    func disconnect() {}
}

#endif
