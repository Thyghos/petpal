// Year in Review: December 1 + adoption-anniversary local notifications (iOS).

import Foundation
#if os(iOS)
import UserNotifications

enum YearInReviewNotificationService {
    private static let decemberId = "com.thyghos.petpalapp.yir.december"

    static func scheduleYearInReviewNotifications(pets: [Pet]) async {
        await PetReminderNotificationService.requestPermissionIfNeeded()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }

        let cal = Calendar.current
        let year = cal.component(.year, from: Date())

        if !UserDefaults.standard.bool(forKey: "hasScheduledYIRNotif_\(year)") {
            var dc = DateComponents()
            dc.month = 12
            dc.day = 1
            dc.hour = 9
            dc.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let content = UNMutableNotificationContent()
            let petName = primaryPetName(pets: pets)
            content.title = "\(petName)'s Year in Review is ready!"
            content.body = "Tap to see how amazing this year was 🐾"
            content.sound = .default
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [decemberId])
            let req = UNNotificationRequest(identifier: decemberId, content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(req)
            UserDefaults.standard.set(true, forKey: "hasScheduledYIRNotif_\(year)")
        }

        let today = Date()
        for pet in pets {
            let added = pet.dateAdded
            let years = cal.dateComponents([.year], from: added, to: today).year ?? 0
            guard years >= 1 else { continue }
            let pid = pet.id.uuidString
            let gateKey = "hasScheduledYIRAnniversary_\(pid)"
            if UserDefaults.standard.bool(forKey: gateKey) { continue }

            var dc = cal.dateComponents([.month, .day], from: added)
            dc.hour = 9
            dc.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let content = UNMutableNotificationContent()
            let name = displayPetName(pet)
            content.title = "Happy Anniversary, \(name)!"
            content.body = "Another year together — see your Year in Review 🎉"
            content.sound = .default
            let id = "com.thyghos.petpalapp.yir.adopt.\(pid)"
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(req)
            UserDefaults.standard.set(true, forKey: gateKey)
        }
    }

    private static func primaryPetName(pets: [Pet]) -> String {
        let sorted = pets.sorted { $0.dateAdded < $1.dateAdded }
        guard let id = ActivePetResolver.resolvedPetId(pets: sorted),
              let pet = sorted.first(where: { $0.id == id }) else {
            return "Your pet"
        }
        return displayPetName(pet)
    }

    private static func displayPetName(_ pet: Pet) -> String {
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your pet" : n
    }
}
#endif
