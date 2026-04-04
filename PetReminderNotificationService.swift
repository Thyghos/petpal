// PetReminderNotificationService.swift
// Schedules local notifications for Petpal reminders so alerts appear when the app is backgrounded or closed.

#if os(iOS)
import Foundation
import SwiftData
import UserNotifications

/// Presents notifications as banners even when Petpal is in the foreground.
final class PetReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PetReminderNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Omit `.badge` while foregrounded — otherwise the alert’s badge value fights “clear icon when app is open.”
        completionHandler([.banner, .list, .sound])
    }
}

@MainActor
enum PetReminderNotificationService {

    private static func identifier(for reminderId: UUID) -> String {
        "com.thyghos.petpalapp.reminder.\(reminderId.uuidString)"
    }

    /// Call from `PetpalApp.init` so foreground presentation works.
    static func installDelegate() {
        UNUserNotificationCenter.current().delegate = PetReminderNotificationDelegate.shared
    }

    /// Requests permission only when status is `notDetermined`. Does not re-prompt if the user denied.
    static func requestPermissionIfNeeded() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func canSchedule() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// App icon badge when this alert delivers. iOS replaces the icon number with this value (not +1 per alert). Count incomplete reminders due **any time that same calendar day** as this alert so Lucy 3:01 + Penny 3:02 both show **2**, while older due dates on other days don’t inflate the count like before.
    private static func badgeCountWhenFiring(for reminder: PetReminder, modelContext: ModelContext) -> Int {
        let all = (try? modelContext.fetch(FetchDescriptor<PetReminder>())) ?? []
        let fire = reminder.nextDueDate
        let n = incompleteReminderCountDueSameCalendarDay(as: fire, in: all)
        return max(1, n)
    }

    /// Same local calendar day as `fire` — e.g. Lucy 3:00 + Penny 3:01 both count (one minute apart); same-minute-only would show 1 on the icon.
    private static func incompleteReminderCountDueSameCalendarDay(as fire: Date, in all: [PetReminder]) -> Int {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: fire)
        guard let nextDayStart = cal.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
        return all.filter { r in
            guard !r.isCompleted else { return false }
            return r.nextDueDate >= dayStart && r.nextDueDate < nextDayStart
        }.count
    }

    /// After any reminder edit, re-sync **all** pending alerts so each payload’s badge matches other incomplete reminders due that same calendar day.
    @MainActor
    static func scheduleAfterReminderChange(modelContext: ModelContext) {
        Task {
            await requestPermissionIfNeeded()
            await syncAllReminders(modelContext: modelContext)
        }
    }

    /// Groups notifications by pet in Notification Center; one thread per `petId`.
    private static func threadIdentifier(for reminder: PetReminder) -> String {
        if let pid = reminder.petId {
            return "petpal.pet.\(pid.uuidString)"
        }
        return "petpal.reminder.unassigned"
    }

    /// Clears the **SpringBoard app icon** badge whenever Petpal is open. In-app Reminders red badges are separate.
    static func clearApplicationIconBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    /// Removes **delivered** Petpal reminder banners from Notification Center / lock screen after open.
    /// Does not remove pending future alerts; does not affect the in-app Reminders tile badge.
    static func clearDeliveredReminderNotifications() {
        let prefix = "com.thyghos.petpalapp.reminder."
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications.map(\.request.identifier).filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    private static func petName(for petId: UUID?, modelContext: ModelContext) -> String? {
        guard let petId else { return nil }
        let idv = petId
        var descriptor = FetchDescriptor<Pet>(predicate: #Predicate { $0.id == idv })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.name
    }

    /// Removes any pending alert for this reminder.
    static func cancel(reminderId: UUID) {
        let id = identifier(for: reminderId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    static func syncReminder(_ reminder: PetReminder, modelContext: ModelContext) async {
        cancel(reminderId: reminder.id)

        guard await canSchedule() else { return }
        guard !reminder.isCompleted else { return }
        guard reminder.nextDueDate > Date() else { return }

        let pet = petName(for: reminder.petId, modelContext: modelContext)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let taskTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = reminder.category.trimmingCharacters(in: .whitespacesAndNewlines)

        let content = UNMutableNotificationContent()
        // Lead with the pet profile so each alert is clearly for that pet (subtitle = the reminder itself).
        if let pet, !pet.isEmpty {
            content.title = pet
            if !taskTitle.isEmpty {
                content.subtitle = taskTitle
            } else if !category.isEmpty {
                content.subtitle = category
            } else {
                content.subtitle = "Reminder"
            }
        } else {
            content.title = taskTitle.isEmpty ? (category.isEmpty ? "Petpal reminder" : category) : taskTitle
            content.subtitle = ""
        }

        var bodyParts: [String] = []
        if !category.isEmpty {
            let categoryInTitle = (content.title == category)
            let categoryInSubtitle = (content.subtitle == category)
            if !categoryInTitle && !categoryInSubtitle {
                bodyParts.append(category)
            }
        }
        let notes = reminder.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            let maxNotes = 120
            bodyParts.append(notes.count > maxNotes ? String(notes.prefix(maxNotes)) + "\u{2026}" : notes)
        }
        content.body = bodyParts.isEmpty ? "Open Petpal for details." : bodyParts.joined(separator: " · ")

        content.sound = .default
        content.badge = NSNumber(value: badgeCountWhenFiring(for: reminder, modelContext: modelContext))
        content.threadIdentifier = threadIdentifier(for: reminder)
        var info: [String: Any] = ["reminderId": reminder.id.uuidString]
        if let pid = reminder.petId {
            info["petId"] = pid.uuidString
        }
        content.userInfo = info

        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.nextDueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(identifier: identifier(for: reminder.id), content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            #if DEBUG
            print("Petpal: failed to schedule reminder notification: \(error)")
            #endif
        }
    }

    /// Reconciles all reminders (e.g. after launch, iCloud sync, or bulk edits).
    static func syncAllReminders(modelContext: ModelContext) async {
        guard await canSchedule() else { return }

        let all = (try? modelContext.fetch(FetchDescriptor<PetReminder>())) ?? []
        let activeIds = Set(all.map(\.id))

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let prefix = "com.thyghos.petpalapp.reminder."
        for req in pending where req.identifier.hasPrefix(prefix) {
            let suffix = String(req.identifier.dropFirst(prefix.count))
            guard let uid = UUID(uuidString: suffix), activeIds.contains(uid) else {
                center.removePendingNotificationRequests(withIdentifiers: [req.identifier])
                continue
            }
        }

        for reminder in all {
            await syncReminder(reminder, modelContext: modelContext)
        }
    }
}

#endif
