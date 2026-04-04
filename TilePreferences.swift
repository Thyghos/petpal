// TilePreferences.swift
// Petpal - Tile Preferences Model

import Foundation
import SwiftData

@Model
final class TilePreferences {
    var id: UUID = UUID()
    var tileOrder: [String] = HomeTile.defaultOrder // Array of tile IDs in display order
    var hiddenTiles: [String] = [] // Array of tile IDs that are hidden
    var lastUpdated: Date = Date()
    
    init(
        id: UUID = UUID(),
        tileOrder: [String] = HomeTile.defaultOrder,
        hiddenTiles: [String] = [],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.tileOrder = tileOrder
        self.hiddenTiles = hiddenTiles
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Home Tile Definition

struct HomeTile: Identifiable, Hashable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [String] // Color names
    let iconSize: CGFloat
    
    init(id: String, icon: String, title: String, subtitle: String, gradient: [String], iconSize: CGFloat) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.gradient = gradient
        self.iconSize = iconSize
    }
    
    static let allTiles: [HomeTile] = [
        HomeTile(id: "reminders", icon: "bell.badge.fill", title: "Reminders", subtitle: "Push notifications for meds & more", gradient: ["BrandPurple", "BrandPurple"], iconSize: 24),
        HomeTile(id: "ai_vet", icon: "cross.case.circle.fill", title: "AI Vet", subtitle: "Ask pet health questions", gradient: ["BrandGreen", "BrandPurple"], iconSize: 24),
        HomeTile(id: "emergency", icon: "qrcode.viewfinder", title: "Emergency QR", subtitle: "Printable QR for lost pet with vital info", gradient: ["red", "red"], iconSize: 26),
        HomeTile(id: "health", icon: "heart.text.square.fill", title: "Health History", subtitle: "Log all vet visits", gradient: ["pink", "pink"], iconSize: 24),
        HomeTile(id: "food", icon: "note.text", title: "Pet Care Notes", subtitle: "Printable sheet for pet sitter", gradient: ["BrandOrange", "orange"], iconSize: 26),
        HomeTile(id: "insurance", icon: "cross.case.fill", title: "Insurance", subtitle: "Upload all policy docs", gradient: ["BrandBlue", "cyan"], iconSize: 24),
        HomeTile(id: "weight", icon: "chart.line.uptrend.xyaxis", title: "Weight Tracker", subtitle: "Track weight over time", gradient: ["BrandGreen", "BrandBlue"], iconSize: 24),
        HomeTile(id: "certificates", icon: "doc.text.fill", title: "Certificates", subtitle: "Vaccines, licenses, travel forms", gradient: ["BrandBlue", "BrandPurple"], iconSize: 24),
        HomeTile(id: "favorites", icon: "gift.fill", title: "Pet Deals", subtitle: "Discounts & partner offers", gradient: ["BrandOrange", "BrandPurple"], iconSize: 24),
    ]
    
    /// Default home grid order (left-to-right, top-to-bottom in a 2-column grid).
    static let defaultOrder: [String] = [
        "reminders",
        "ai_vet",
        "health",
        "food",
        "insurance",
        "weight",
        "certificates",
        "emergency",
        "favorites"
    ]
    
    static func tile(for id: String) -> HomeTile? {
        allTiles.first { $0.id == id }
    }

    /// Strips removed tile ids from saved preferences (e.g. legacy `"documents"`, `"dashboard"`).
    static func sanitizedTileOrder(_ order: [String]) -> [String] {
        var out = order.filter { tile(for: $0) != nil }
        for id in defaultOrder where !out.contains(id) {
            out.append(id)
        }
        return out
    }

    static func sanitizedHiddenTiles(_ hidden: [String]) -> [String] {
        hidden.filter { tile(for: $0) != nil }
    }
}
