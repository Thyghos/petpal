// PetpalApp.swift
// Petpal - App Entry Point

import SwiftUI
import SwiftData

@main
struct PetpalApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [
            Pet.self,
            PetReminder.self,
            TilePreferences.self,
            HealthTipPreferences.self,
            EmergencyProfile.self,
            StoredVetDocument.self,
            VetVisitLog.self,
            PetInsuranceInfo.self,
            PetRecordAttachment.self,
            PetSitterInstructions.self
        ])
    }
}
