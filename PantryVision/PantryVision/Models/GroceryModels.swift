import Foundation

struct GroceryAisleRule: Identifiable, Codable, Equatable {
    var id: String
    var aisleName: String
    var keywords: [String]
}

struct GroceryStoreProfile: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var aisleRules: [GroceryAisleRule]

    static let catalog: [GroceryStoreProfile] = [
        GroceryStoreProfile(
            id: "generic",
            displayName: "Generic Store",
            aisleRules: [
                GroceryAisleRule(id: "produce", aisleName: "Produce", keywords: ["produce", "lettuce", "spinach", "onion", "tomato", "garlic", "pepper", "banana", "apple", "orange", "berries", "cucumber"]),
                GroceryAisleRule(id: "dairy", aisleName: "Dairy", keywords: ["milk", "cheese", "yogurt", "butter", "cream"]),
                GroceryAisleRule(id: "meat", aisleName: "Meat", keywords: ["chicken", "beef", "pork", "turkey", "bacon", "sausage", "steak"]),
                GroceryAisleRule(id: "bakery", aisleName: "Bakery", keywords: ["bread", "tortilla", "wrap", "bagel", "bun"]),
                GroceryAisleRule(id: "frozen", aisleName: "Frozen", keywords: ["frozen", "ice cream", "broccoli", "peas", "fry", "wok"]),
                GroceryAisleRule(id: "pantry", aisleName: "Pantry", keywords: ["pasta", "rice", "beans", "lentil", "flour", "oil", "vinegar", "sauce", "tomato", "canned", "broth", "spice"]),
                GroceryAisleRule(id: "beverages", aisleName: "Beverages", keywords: ["water", "juice", "soda", "coffee", "tea"]),
                GroceryAisleRule(id: "snacks", aisleName: "Snacks", keywords: ["chips", "cracker", "snack"])
            ]
        )
    ]
}

struct GroceryItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var quantity: Int?
    var note: String?
    var isCrossedOff: Bool = false

    /// User-selected health/benefit tags (MVP: heuristic suggestions at add-time).
    var healthTags: [String] = []

    /// Attribution for who added the item.
    var addedBy: String = "You"
    var addedAt: Date = Date()

    /// Purchase history stats used for UI + subtle nudges.
    /// We treat `isCrossedOff == true` as "purchased" for MVP.
    var lastPurchasedAt: Date?
    var lastPurchasedBy: String?
    var purchaseIntervalsSumDays: Double = 0
    var purchaseIntervalsCount: Int = 0
    var purchaseCount: Int = 0

    /// Rough, user-provided estimate used for totals. Optional for MVP.
    var estimatedUnitPrice: Double?
    var currencyCode: String = "USD"

    /// Stored with the item so both spouses see the same aisle hint.
    var storeId: String?
    var aisleName: String?

    static func normalizeForMatch(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lettersOnly = String(trimmed.filter { $0.isLetter })
        guard lettersOnly.count > 3 else { return lettersOnly }
        if lettersOnly.hasSuffix("s") {
            return String(lettersOnly.dropLast())
        }
        return lettersOnly
    }
}

struct GroceryList: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String = "Pantry List"

    /// Used later for spouse/family sync.
    var familyId: String = "local-family"

    /// Which store aisle mapping was last used (for new items we add).
    var selectedStoreId: String? = GroceryStoreProfile.catalog.first?.id

    var items: [GroceryItem] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

@MainActor
final class GroceryListStore: ObservableObject {
    @Published private(set) var list: GroceryList
    @Published private(set) var syncFamilyId: String?
    @Published private(set) var syncStatusMessage: String?

    private let storageFileName = "grocerylist.json"
    private let syncService = GroceryListSyncService()

    init() {
        self.list = GroceryList()
        loadFromDisk()
        self.syncStatusMessage = nil
    }

    var items: [GroceryItem] { list.items }

    var selectedStore: GroceryStoreProfile {
        let storeId = list.selectedStoreId ?? GroceryStoreProfile.catalog.first?.id
        return GroceryStoreProfile.catalog.first(where: { $0.id == storeId }) ?? GroceryStoreProfile.catalog[0]
    }

    func selectStore(_ storeId: String) {
        guard GroceryStoreProfile.catalog.contains(where: { $0.id == storeId }) else { return }
        list.selectedStoreId = storeId
        touchAndSave()
    }

    private func aisleNameForItem(_ name: String, store: GroceryStoreProfile) -> String? {
        let lower = name.lowercased()
        var bestRule: GroceryAisleRule?
        var bestScore = 0

        for rule in store.aisleRules {
            let matches = rule.keywords.reduce(0) { acc, keyword in
                let k = keyword.lowercased()
                return acc + (lower.contains(k) ? 1 : 0)
            }
            if matches > 0 {
                if matches > bestScore {
                    bestRule = rule
                    bestScore = matches
                }
            }
        }

        return bestRule?.aisleName
    }

    var estimatedTotal: Double {
        list.items.reduce(0) { acc, item in
            guard !item.isCrossedOff else { return acc }
            guard let unit = item.estimatedUnitPrice else { return acc }
            let qty = item.quantity ?? 1
            return acc + (unit * Double(qty))
        }
    }

    func addItem(
        name: String,
        quantity: Int? = nil,
        note: String? = nil,
        estimatedUnitPrice: Double? = nil,
        healthTags: [String] = []
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let store = selectedStore
        let aisle = aisleNameForItem(trimmed, store: store)

        list.items.append(
            GroceryItem(
                name: trimmed,
                quantity: quantity,
                note: note,
                healthTags: healthTags,
                addedBy: PantryVisionIdentity.displayName,
                addedAt: Date(),
                lastPurchasedAt: nil,
                lastPurchasedBy: nil,
                purchaseIntervalsSumDays: 0,
                purchaseIntervalsCount: 0,
                purchaseCount: 0,
                estimatedUnitPrice: estimatedUnitPrice,
                storeId: store.id,
                aisleName: aisle
            )
        )
        touchAndSave()

        if let familyId = syncFamilyId {
            let item = list.items.last!
            Task {
                try? await syncService.upsertItem(familyId: familyId, item: item)
            }
        }
    }

    func addItemIfMissing(
        name: String,
        quantity: Int? = nil,
        note: String? = nil,
        estimatedUnitPrice: Double? = nil,
        healthTags: [String] = []
    ) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased()

        // If it already exists (regardless of crossed-off state), don't add duplicates.
        let exists = list.items.contains(where: { $0.name.lowercased() == lower })
        guard !exists else { return }

        addItem(name: trimmed, quantity: quantity, note: note, estimatedUnitPrice: estimatedUnitPrice, healthTags: healthTags)
    }

    /// Applies receipt OCR candidates to mark matching items as purchased.
    /// Returns item names that were updated.
    func markPurchasedFromReceiptCandidates(_ candidates: [String]) -> [String] {
        let now = Date()
        let normalizedCandidates = Set(candidates.map { GroceryItem.normalizeForMatch($0) }.filter { !$0.isEmpty })
        guard !normalizedCandidates.isEmpty else { return [] }

        var matchedNames: [String] = []
        var updatedItems: [GroceryItem] = []

        for idx in list.items.indices {
            let item = list.items[idx]
            let itemNorm = GroceryItem.normalizeForMatch(item.name)
            if itemNorm.isEmpty { continue }

            let matches =
                normalizedCandidates.contains(itemNorm) ||
                normalizedCandidates.contains(where: { $0.contains(itemNorm) || itemNorm.contains($0) })

            guard matches else { continue }
            guard !list.items[idx].isCrossedOff else { continue } // avoid double-counting

            if let previous = list.items[idx].lastPurchasedAt {
                let intervalDays = max(0, now.timeIntervalSince(previous) / (60 * 60 * 24))
                list.items[idx].purchaseIntervalsSumDays += intervalDays
                list.items[idx].purchaseIntervalsCount += 1
            }

            list.items[idx].purchaseCount += 1
            list.items[idx].isCrossedOff = true
            list.items[idx].lastPurchasedAt = now
            list.items[idx].lastPurchasedBy = PantryVisionIdentity.displayName

            matchedNames.append(item.name)
            updatedItems.append(list.items[idx])
        }

        guard !updatedItems.isEmpty else { return [] }

        touchAndSave()

        if let familyId = syncFamilyId {
            for item in updatedItems {
                Task { try? await syncService.upsertItem(familyId: familyId, item: item) }
            }
        }

        return matchedNames
    }

    func aisleHint(for itemName: String) -> String? {
        let trimmed = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return aisleNameForItem(trimmed, store: selectedStore)
    }

    func removeItems(at offsets: IndexSet) {
        let removed = offsets.map { list.items[$0] }
        list.items.remove(atOffsets: offsets)
        touchAndSave()

        if let familyId = syncFamilyId {
            Task {
                for item in removed {
                    try? await syncService.deleteItem(familyId: familyId, itemID: item.id)
                }
            }
        }
    }

    func removeItem(id: UUID) {
        let wasPresent = list.items.contains(where: { $0.id == id })
        list.items.removeAll { $0.id == id }
        touchAndSave()

        guard wasPresent else { return }
        if let familyId = syncFamilyId {
            Task { try? await syncService.deleteItem(familyId: familyId, itemID: id) }
        }
    }

    func toggleCrossOff(_ itemID: UUID) {
        guard let idx = list.items.firstIndex(where: { $0.id == itemID }) else { return }
        let now = Date()
        let newValue = !list.items[idx].isCrossedOff
        list.items[idx].isCrossedOff = newValue

        // When transitioning to "crossed off", record a purchase event.
        if newValue {
            if let previous = list.items[idx].lastPurchasedAt {
                let intervalDays = max(0, now.timeIntervalSince(previous) / (60 * 60 * 24))
                list.items[idx].purchaseIntervalsSumDays += intervalDays
                list.items[idx].purchaseIntervalsCount += 1
            }
            list.items[idx].purchaseCount += 1
            list.items[idx].lastPurchasedAt = now
            list.items[idx].lastPurchasedBy = PantryVisionIdentity.displayName
        }

        touchAndSave()

        let updated = list.items[idx]
        if let familyId = syncFamilyId {
            Task { try? await syncService.upsertItem(familyId: familyId, item: updated) }
        }
    }

    func updateItem(_ item: GroceryItem) {
        guard let idx = list.items.firstIndex(where: { $0.id == item.id }) else { return }
        list.items[idx] = item
        touchAndSave()

        if let familyId = syncFamilyId {
            Task { try? await syncService.upsertItem(familyId: familyId, item: item) }
        }
    }

    func createFamily() async throws -> String {
        syncStatusMessage = "Creating family..."
        let family = try await FamilyCodeService.createFamily()
        syncFamilyId = family.familyId
        list.familyId = family.familyId
        syncStatusMessage = "Synced"

        syncService.startListening(familyId: family.familyId) { [weak self] items in
            guard let self else { return }
            self.list.items = items
            self.list.updatedAt = Date()
            self.saveToDisk()
        }
        return family.familyCode
    }

    func joinFamily(familyCode: String) async throws {
        let trimmed = familyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        syncStatusMessage = "Connecting..."
        let joined = try await FamilyCodeService.joinFamily(familyCode: trimmed)
        syncFamilyId = joined.familyId
        list.familyId = joined.familyId
        syncStatusMessage = "Synced"

        syncService.startListening(familyId: joined.familyId) { [weak self] items in
            guard let self else { return }
            self.list.items = items
            self.list.updatedAt = Date()
            self.saveToDisk()
        }
    }

    private func touchAndSave() {
        list.updatedAt = Date()
        saveToDisk()
    }

    private func loadFromDisk() {
        let url = storageURL()
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            let decoded = try JSONDecoder().decode(GroceryList.self, from: data)
            self.list = decoded
        } catch {
            // MVP: ignore corrupt data and start fresh.
        }
    }

    private func saveToDisk() {
        let url = storageURL()
        do {
            let data = try JSONEncoder().encode(list)
            try data.write(to: url, options: [.atomic])
        } catch {
            // MVP: ignore disk errors for now.
        }
    }

    private func storageURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(storageFileName)
    }
}

