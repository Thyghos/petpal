// PetpalStore.swift
// Petpal — Subscription & IAP management for AI Vet plans (StoreKit 2).
//
// App Store Connect products required:
//   Auto-Renewable Subscriptions (group "AI Vet"):
//     com.thyghos.petpalapp.aivet.plus   — $3.99/month  (75 replies)
//     com.thyghos.petpalapp.aivet.pro    — $9.99/month (250 replies)
//   Consumable:
//     com.thyghos.petpalapp.aivet.topup  — $0.99 (10 bonus replies)
//   Consumable Tips:
//     com.thyghos.petpalapp.tip.small    — $0.99
//     com.thyghos.petpalapp.tip.medium   — $4.99
//     com.thyghos.petpalapp.tip.large    — $9.99
//     com.thyghos.petpalapp.tip.generous — ~$20 (typically $19.99)

#if os(iOS)
import StoreKit
#endif
import Combine
import SwiftUI

#if os(iOS)

@MainActor
final class PetpalStore: ObservableObject {
    static let shared = PetpalStore()

    // MARK: - Product IDs

    static let plusProductID = "com.thyghos.petpalapp.aivet.plus"
    static let proProductID  = "com.thyghos.petpalapp.aivet.pro"
    static let subscriptionIDs: Set<String> = [plusProductID, proProductID]

    // MARK: - Published State

    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var activeProductID: String?
    @Published private(set) var isLoading = true
    @Published var purchaseError: String?

    private var updateListenerTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        updateListenerTask = listenForTransactions()
    }

    deinit { updateListenerTask?.cancel() }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: Self.subscriptionIDs)
            subscriptions = products.sorted { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshSubscriptionStatus()
                    return true
                case .unverified(_, let verificationError):
                    purchaseError = verificationError.localizedDescription
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Purchase is pending approval (e.g. Ask to Buy)."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    // MARK: - Subscription Status

    func refreshSubscriptionStatus() async {
        var foundActiveID: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.subscriptionIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil, !transaction.isUpgraded else { continue }
            if transaction.productID == Self.proProductID {
                foundActiveID = Self.proProductID
            } else if foundActiveID != Self.proProductID {
                foundActiveID = Self.plusProductID
            }
        }

        activeProductID = foundActiveID
        syncTierToUserDefaults()
    }

    // MARK: - Computed Helpers

    var activeTier: AIVetPlanTier {
        switch activeProductID {
        case Self.proProductID:  return .pro
        case Self.plusProductID: return .plus
        default:                 return .free
        }
    }

    func product(for tier: AIVetPlanTier) -> Product? {
        switch tier {
        case .plus: return subscriptions.first { $0.id == Self.plusProductID }
        case .pro:  return subscriptions.first { $0.id == Self.proProductID }
        case .free: return nil
        }
    }

    // MARK: - Private

    private func syncTierToUserDefaults() {
        UserDefaults.standard.set(activeTier.rawValue, forKey: "aiVetPlanTier")
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self.refreshSubscriptionStatus()
            }
        }
    }
}

#endif
