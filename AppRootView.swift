// AppRootView.swift
// Runs one-time persistence repair before the home screen appears.

import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HomeView()
            .task {
                LegacyPetBootstrap.runIfNeeded(modelContext: modelContext)
            }
    }
}
