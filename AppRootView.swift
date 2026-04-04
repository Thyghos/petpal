// AppRootView.swift
// Runs one-time persistence repair before the home screen appears.

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPersistenceWarning = false
    @State private var showStoreRecreatedNotice = false
    @State private var showLocalOnlyNotice = false

    var body: some View {
        HomeView()
            .task {
                LegacyPetBootstrap.runIfNeeded(modelContext: modelContext)
                #if os(iOS)
                await PetReminderNotificationService.syncAllReminders(modelContext: modelContext)
                PetReminderNotificationService.clearApplicationIconBadge()
                #endif
            }
            .onChange(of: scenePhase) { _, phase in
                #if os(iOS)
                switch phase {
                case .active:
                    PetReminderNotificationService.clearApplicationIconBadge()
                    PetReminderNotificationService.clearDeliveredReminderNotifications()
                    Task { @MainActor in
                        await PetReminderNotificationService.syncAllReminders(modelContext: modelContext)
                        PetReminderNotificationService.clearApplicationIconBadge()
                    }
                default:
                    break
                }
                #endif
            }
            .onAppear {
                #if os(iOS)
                // Cold launch: clear SpringBoard badge + lock-screen/NC reminder banners; in-app Reminders tile still shows overdue count.
                PetReminderNotificationService.clearApplicationIconBadge()
                PetReminderNotificationService.clearDeliveredReminderNotifications()
                #endif
                if PetpalStoreRecoveryNotice.shouldShowRecoveryNotice {
                    showStoreRecreatedNotice = true
                }
                showPersistenceWarning = PetpalPersistenceDiagnostics.isUsingInMemoryStore
                    && !PetpalPersistenceDiagnostics.suppressInMemoryStoreAlert
                showLocalOnlyNotice =
                    PetpalPersistenceDiagnostics.openedWithLocalStoreOnlyAfterCloudFailure
                    && !PetpalPersistenceDiagnostics.userAcknowledgedLocalOnlyFallback
            }
            .alert("Local data was reset", isPresented: $showStoreRecreatedNotice) {
                Button("Don’t show again") {
                    PetpalStoreRecoveryNotice.suppressRecoveryNoticeForever()
                }
                Button("OK", role: .cancel) {
                    PetpalStoreRecoveryNotice.markRecoveryNoticeAcknowledged()
                }
            } message: {
                Text(
                    "Your previous on-device database couldn’t be read, so Petpal started a new one. "
                    + "If you use another device or an older backup, use Settings → Backup & restore → Import. "
                    + "Some profile details may still be rebuilt from this device’s settings."
                )
            }
            .alert("Couldn’t open saved data", isPresented: $showPersistenceWarning) {
                Button("Don’t show again") {
                    PetpalPersistenceDiagnostics.suppressInMemoryStoreAlert = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "Petpal couldn’t open its on-disk database and is using temporary memory — "
                    + "nothing will be saved after you quit. Quit the app completely and open it again. "
                    + "If you have a backup, use Settings → Backup & restore → Import."
                )
            }
            .alert("Saving on this device only", isPresented: $showLocalOnlyNotice) {
                Button("Don’t show again") {
                    PetpalPersistenceDiagnostics.userAcknowledgedLocalOnlyFallback = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "iCloud sync couldn’t start, so Petpal is using on-device storage only. "
                    + "Your data will still save on this iPhone or iPad. Open Settings → Apple ID → iCloud if you want sync, then fully quit and reopen Petpal."
                )
            }
    }
}
