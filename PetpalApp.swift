// PetpalApp.swift
// Petpal - App Entry Point
//
// SwiftData at a stable URL (`PetpalSwiftDataStore`). We prefer CloudKit sync (`.automatic`)
// when it works; if opening with CloudKit fails, we fall back to a **local-only** store so
// data still persists on disk (instead of dropping straight to in-memory or wiping the store).

import SwiftUI
import SwiftData

@main
struct PetpalApp: App {
    private let sharedModelContainer: ModelContainer

    init() {
        #if os(iOS)
        PetReminderNotificationService.installDelegate()
        #endif
        let schema = Schema([
            Pet.self,
            PetReminder.self,
            TilePreferences.self,
            HealthTipPreferences.self,
            EmergencyProfile.self,
            StoredVetDocument.self,
            VetVisitLog.self,
            PetInsuranceInfo.self,
            PetRecordAttachment.self,
            PetSitterInstructions.self,
            PetWeightEntry.self,
            PetCertificate.self
        ])
        let storeURL = PetpalSwiftDataStore.storeURL()
        let cloudConfig = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .automatic)
        let localConfig = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)

        func makeContainer(_ configuration: ModelConfiguration) throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: [configuration])
        }

        PetpalPersistenceDiagnostics.openedWithLocalStoreOnlyAfterCloudFailure = false

        /// Open disk store: try CloudKit first, then local-only (same file) before giving up.
        func openDiskPreferCloud() throws -> ModelContainer {
            do {
                let c = try makeContainer(cloudConfig)
                PetpalPersistenceDiagnostics.openedWithLocalStoreOnlyAfterCloudFailure = false
                return c
            } catch let cloudError {
                #if DEBUG
                print("Petpal: SwiftData+CloudKit open failed; trying local-only store. \(cloudError)")
                #endif
                let c = try makeContainer(localConfig)
                PetpalPersistenceDiagnostics.openedWithLocalStoreOnlyAfterCloudFailure = true
                return c
            }
        }

        do {
            sharedModelContainer = try openDiskPreferCloud()
        } catch let openError1 {
            do {
                sharedModelContainer = try openDiskPreferCloud()
            } catch let openError2 {
                #if DEBUG
                print("Petpal: two disk opens failed; attempting store reset.\n1: \(openError1)\n2: \(openError2)")
                #endif
                do {
                    try PetpalSwiftDataStore.removeCanonicalStoreArtifacts()
                    do {
                        sharedModelContainer = try openDiskPreferCloud()
                    } catch {
                        sharedModelContainer = try makeContainer(localConfig)
                        PetpalPersistenceDiagnostics.openedWithLocalStoreOnlyAfterCloudFailure = true
                    }
                    PetpalStoreRecoveryNotice.registerRecoveryEvent()
                    PetpalPersistenceDiagnostics.lastDiskPersistenceFailureSummary = [
                        String(describing: openError1),
                        String(describing: openError2)
                    ].joined(separator: "\n")
                } catch let afterResetError {
                    PetpalPersistenceDiagnostics.isUsingInMemoryStore = true
                    PetpalPersistenceDiagnostics.lastDiskPersistenceFailureSummary = [
                        "Before reset: \(openError1)",
                        "Retry: \(openError2)",
                        "After reset: \(afterResetError)"
                    ].joined(separator: "\n")
                    #if DEBUG
                    print("Petpal: disk failed after reset; using in-memory.\n\(PetpalPersistenceDiagnostics.lastDiskPersistenceFailureSummary ?? "")")
                    #endif
                    do {
                        sharedModelContainer = try makeContainer(memoryConfig)
                    } catch let memoryError {
                        PetpalPersistenceDiagnostics.lastDiskPersistenceFailureSummary = [
                            PetpalPersistenceDiagnostics.lastDiskPersistenceFailureSummary ?? "",
                            "Memory: \(memoryError)"
                        ].joined(separator: "\n")
                        fatalError(
                            "Petpal cannot start SwiftData. \(PetpalPersistenceDiagnostics.lastDiskPersistenceFailureSummary ?? "")"
                        )
                    }
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .task {
                    #if os(iOS)
                    await PetpalStore.shared.refreshSubscriptionStatus()
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
