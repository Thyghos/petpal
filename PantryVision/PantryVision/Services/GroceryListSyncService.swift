import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum GroceryListSyncServiceError: Error {
    case firebaseUnavailable
}

/// Firestore-backed realtime grocery list sync for a shared `familyId`.
/// If Firebase isn't configured in the build, this service becomes a no-op.
final class GroceryListSyncService {
    #if canImport(FirebaseFirestore)
    private var listener: Any?
    #else
    private var listener: Any?
    #endif

    func startListening(familyId: String, onItems: @escaping ([GroceryItem]) -> Void) {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        stopListening()

        listener = db.collection("families")
            .document(familyId)
            .collection("items")
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("GroceryListSyncService listener error: \(error)")
                    return
                }

                let docs = snapshot?.documents ?? []
                let items: [GroceryItem] = docs.compactMap { doc in
                    guard let name = doc.get("name") as? String else { return nil }
                    let quantity = doc.get("quantity") as? Int
                    let note = doc.get("note") as? String
                    let isCrossedOff = doc.get("isCrossedOff") as? Bool ?? false
                    let estimatedUnitPrice = doc.get("estimatedUnitPrice") as? Double ?? (doc.get("estimatedUnitPrice") as? NSNumber)?.doubleValue
                    let currencyCode = doc.get("currencyCode") as? String ?? "USD"
                    let storeId = doc.get("storeId") as? String
                    let aisleName = doc.get("aisleName") as? String
                    let addedBy = doc.get("addedBy") as? String ?? "You"
                    let addedAt = (doc.get("addedAt") as? Timestamp)?.dateValue() ?? Date()
                    let lastPurchasedBy = doc.get("lastPurchasedBy") as? String
                    let lastPurchasedAt = (doc.get("lastPurchasedAt") as? Timestamp)?.dateValue()
                    let purchaseIntervalsSumDays = doc.get("purchaseIntervalsSumDays") as? Double ?? 0
                    let purchaseIntervalsCount = doc.get("purchaseIntervalsCount") as? Int ?? 0
                    let purchaseCount = doc.get("purchaseCount") as? Int ?? 0
                    let healthTags = doc.get("healthTags") as? [String] ?? []

                    let idString = doc.documentID
                    let id = UUID(uuidString: idString) ?? UUID()

                    return GroceryItem(
                        id: id,
                        name: name,
                        quantity: quantity,
                        note: note,
                        isCrossedOff: isCrossedOff,
                        addedBy: addedBy,
                        addedAt: addedAt,
                        lastPurchasedAt: lastPurchasedAt,
                        lastPurchasedBy: lastPurchasedBy,
                        purchaseIntervalsSumDays: purchaseIntervalsSumDays,
                        purchaseIntervalsCount: purchaseIntervalsCount,
                        purchaseCount: purchaseCount,
                        estimatedUnitPrice: estimatedUnitPrice,
                        currencyCode: currencyCode,
                        storeId: storeId,
                        aisleName: aisleName,
                        healthTags: healthTags
                    )
                }

                DispatchQueue.main.async {
                    onItems(items)
                }
            }
        #else
        // Firebase not linked yet.
        DispatchQueue.main.async {
            onItems([])
        }
        _ = familyId
        _ = listener
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        if let reg = listener as? ListenerRegistration {
            reg.remove()
        }
        listener = nil
        #else
        listener = nil
        #endif
    }

    func upsertItem(familyId: String, item: GroceryItem) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("families").document(familyId).collection("items").document(item.id.uuidString)

        let lastPurchasedAtValue: Any = item.lastPurchasedAt != nil ? item.lastPurchasedAt! : NSNull()

        let data: [String: Any] = [
            "name": item.name,
            "quantity": item.quantity as Any,
            "note": item.note as Any,
            "isCrossedOff": item.isCrossedOff,
            "healthTags": item.healthTags,
            "estimatedUnitPrice": item.estimatedUnitPrice as Any,
            "currencyCode": item.currencyCode,
            "storeId": item.storeId as Any,
            "aisleName": item.aisleName as Any,
            "addedBy": item.addedBy,
            "addedAt": item.addedAt,
            "lastPurchasedBy": item.lastPurchasedBy as Any,
            "lastPurchasedAt": lastPurchasedAtValue,
            "purchaseIntervalsSumDays": item.purchaseIntervalsSumDays,
            "purchaseIntervalsCount": item.purchaseIntervalsCount,
            "purchaseCount": item.purchaseCount
        ]

        try await withCheckedThrowingContinuation { continuation in
            docRef.setData(data, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        #else
        throw GroceryListSyncServiceError.firebaseUnavailable
        #endif
        _ = familyId
        _ = item
    }

    func deleteItem(familyId: String, itemID: UUID) async throws {
        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        let docRef = db.collection("families").document(familyId).collection("items").document(itemID.uuidString)
        try await withCheckedThrowingContinuation { continuation in
            docRef.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        #else
        throw GroceryListSyncServiceError.firebaseUnavailable
        #endif
        _ = familyId
    }
}

