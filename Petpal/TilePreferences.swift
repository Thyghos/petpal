// TilePreferences.swift
// PawPal - Tile Preferences Model

import Foundation
import SwiftData

@Model
class TilePreferences {
    var id: UUID = UUID()
    var tileOrder: [String] = [] // Array of tile IDs in display order
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
    let gradient: [String] // Color names
    let iconSize: CGFloat
    
    static let allTiles: [HomeTile] = [
        HomeTile(id: "travel", icon: "airplane.departure", title: "Travel Mode", gradient: ["BrandOrange", "BrandOrange"], iconSize: 24),
        HomeTile(id: "documents", icon: "doc.text.fill", title: "Documents", gradient: ["BrandBlue", "BrandBlue"], iconSize: 24),
        HomeTile(id: "reminders", icon: "bell.badge.fill", title: "Reminders", gradient: ["BrandPurple", "BrandPurple"], iconSize: 24),
        HomeTile(id: "emergency", icon: "qrcode.viewfinder", title: "Emergency QR", gradient: ["red", "red"], iconSize: 26),
        HomeTile(id: "health", icon: "heart.text.square.fill", title: "Health History", gradient: ["pink", "pink"], iconSize: 24),
        HomeTile(id: "food", icon: "fork.knife.circle.fill", title: "Food & Treats", gradient: ["BrandOrange", "orange"], iconSize: 26),
        HomeTile(id: "insurance", icon: "cross.case.fill", title: "Insurance", gradient: ["BrandBlue", "cyan"], iconSize: 24),
        HomeTile(id: "encyclopedia", icon: "book.closed.fill", title: "Encyclopedia", gradient: ["indigo", "indigo"], iconSize: 24),
        HomeTile(id: "dashboard", icon: "square.grid.2x2.fill", title: "Dashboard", gradient: ["BrandPurple", "purple"], iconSize: 24),
    ]
    
    static let defaultOrder: [String] = allTiles.map { $0.id }
    
    static func tile(for id: String) -> HomeTile? {
        allTiles.first { $0.id == id }
    }

    /// Normalizes stored order: known tile ids only, unique, then append any missing defaults (stable).
    static func sanitizedTileOrder(_ order: [String]) -> [String] {
        let validIds = Set(allTiles.map(\.id))
        var seen = Set<String>()
        var out: [String] = []
        for id in order where validIds.contains(id) {
            guard !seen.contains(id) else { continue }
            out.append(id)
            seen.insert(id)
        }
        for id in defaultOrder where !seen.contains(id) {
            out.append(id)
            seen.insert(id)
        }
        return out
    }

    /// After drag-reorder of **visible** tiles, rebuild full `tileOrder` including hidden entries.
    static func mergedFullTileOrder(visibleOrdered: [String], hiddenIDs: [String], previousFullOrder: [String]) -> [String] {
        let hidden = Set(hiddenIDs)
        let visible = Set(visibleOrdered)
        var full = visibleOrdered
        for id in previousFullOrder where hidden.contains(id) && !visible.contains(id) {
            guard !full.contains(id) else { continue }
            full.append(id)
        }
        for id in hiddenIDs where !full.contains(id) {
            full.append(id)
        }
        return sanitizedTileOrder(full)
    }
}

// MARK: - Layout customization (UserDefaults)

enum HomeTileLayoutState {
    private static let customizedKey = "HomeTileLayoutUserCustomized"

    static var userHasCustomizedLayout: Bool {
        UserDefaults.standard.bool(forKey: customizedKey)
    }

    static func migrateExistingInstallIfNeeded(prefs: TilePreferences) {
        if prefs.tileOrder.isEmpty {
            prefs.tileOrder = HomeTile.defaultOrder
        }
    }

    static func markLayoutCustomizedByUser() {
        UserDefaults.standard.set(true, forKey: customizedKey)
    }
}
