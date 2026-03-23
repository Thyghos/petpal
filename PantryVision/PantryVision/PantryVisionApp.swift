import SwiftUI

@main
struct PantryVisionApp: App {
    @StateObject private var groceryStore = GroceryListStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(groceryStore)
        }
    }
}

