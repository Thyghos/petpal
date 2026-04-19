// LucysTipJarView.swift  (houses DeveloperTipJarView)
// Petpal — optional developer tips via In-App Purchase (StoreKit 2).
//
// App Store Connect: create 4 consumable IAPs with these exact Product IDs:
//   com.thyghos.petpalapp.tip.small    — $0.99
//   com.thyghos.petpalapp.tip.medium   — $4.99
//   com.thyghos.petpalapp.tip.large    — $9.99
//   com.thyghos.petpalapp.tip.generous — ~$20 (typically $19.99 tier)

#if os(iOS)
import StoreKit
#endif
import Combine
import SwiftUI

#if os(iOS)

@MainActor
final class DeveloperTipJarStore: ObservableObject {
    enum TipProductID: String, CaseIterable {
        case small    = "com.thyghos.petpalapp.tip.small"
        case medium   = "com.thyghos.petpalapp.tip.medium"
        case large    = "com.thyghos.petpalapp.tip.large"
        case generous = "com.thyghos.petpalapp.tip.generous"

        /// SF Symbols render reliably; emoji in `Text` can show as placeholders on some devices.
        var symbolName: String {
            switch self {
            case .small:    return "cup.and.saucer.fill"
            case .medium:   return "gift.fill"
            case .large:    return "party.popper.fill"
            case .generous: return "heart.circle.fill"
            }
        }

        /// Shown only when StoreKit has not returned products yet (e.g. before config loads).
        var displayPriceFallback: String {
            switch self {
            case .small:    return "$0.99"
            case .medium:   return "$4.99"
            case .large:    return "$9.99"
            case .generous: return "$19.99"
            }
        }
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = true
    @Published var purchaseError: String?
    @Published var showThanks = false
    @Published private(set) var isPurchasing = false

    private static let ids = TipProductID.allCases.map(\.rawValue)

    func loadProducts() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Self.ids)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func product(for tip: TipProductID) -> Product? {
        products.first { $0.id == tip.rawValue }
    }

    func purchase(tip: TipProductID) async {
        if let p = product(for: tip) {
            await purchase(p)
            return
        }
        await loadProducts()
        if let p = product(for: tip) {
            await purchase(p)
            return
        }
        purchaseError = Self.catalogUnavailableMessage
    }

    private static let catalogUnavailableMessage = "Tips aren\u{2019}t loading. If you\u{2019}re testing in Xcode, set the Run scheme\u{2019}s StoreKit Configuration to StoreKitConfiguration.storekit (Product \u{2192} Scheme \u{2192} Edit Scheme \u{2192} Run \u{2192} Options). For a device build, add the consumable IAPs in App Store Connect first."

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        purchaseError = nil
        showThanks = false
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    showThanks = true
                case .unverified(_, let error):
                    purchaseError = error.localizedDescription
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "This purchase is pending (e.g. Ask to Buy)."
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

}

struct DeveloperTipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = DeveloperTipJarStore()

    var body: some View {
        NavigationStack {
            ZStack {
                Color("BrandCream").opacity(0.35)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Petpal is built by a small team with a lot of heart. Tips are entirely optional and don\u{2019}t unlock anything extra\u{2014}they simply help us keep improving the app for you and your pets.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if store.showThanks {
                            Label("Thank you so much\u{2014}that means a lot!", systemImage: "heart.fill")
                                .font(.headline)
                                .foregroundStyle(Color("BrandPurple"))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color("BrandSoftBlue").opacity(0.35))
                                )
                        }

                        if store.isLoading && store.products.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Loading prices\u{2026}")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        VStack(spacing: 12) {
                            ForEach(DeveloperTipJarStore.TipProductID.allCases, id: \.rawValue) { tip in
                                let product = store.product(for: tip)
                                Button {
                                    Task { await store.purchase(tip: tip) }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: tip.symbolName)
                                            .font(.title2)
                                            .foregroundStyle(Color("BrandPurple"))
                                            .frame(width: 36)
                                        Text(product?.displayPrice ?? tip.displayPriceFallback)
                                            .font(.headline)
                                            .foregroundStyle(Color("BrandDark"))
                                        Spacer()
                                        if store.isPurchasing {
                                            ProgressView()
                                                .scaleEffect(0.85)
                                        } else {
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.secondarySystemGroupedBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(store.isPurchasing)
                            }
                        }

                        if let err = store.purchaseError, !err.isEmpty {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Text("Payments are processed by Apple. Tips are optional and do not unlock app features. For refunds, use Apple\u{2019}s Report a Problem flow.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Developer Tip Jar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await store.loadProducts()
        }
    }
}

// Keep the old name as a typealias so any stale references still compile.
typealias LucysTipJarView = DeveloperTipJarView

#else

struct DeveloperTipJarView: View {
    var body: some View {
        Text("Developer Tip Jar is available on iPhone and iPad.")
            .padding()
    }
}

typealias LucysTipJarView = DeveloperTipJarView

#endif
