import SwiftUI

struct HelpfulProductsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let products: [RecommendedProduct] = [
        RecommendedProduct(title: "Everyday Kibble", subtitle: "Balanced nutrition for daily feeding", url: "https://example.com/affiliate/kibble"),
        RecommendedProduct(title: "Freeze-Dried Treats", subtitle: "High-value training treats", url: "https://example.com/affiliate/treats"),
        RecommendedProduct(title: "Slow Feeder Bowl", subtitle: "Helps pets who eat too fast", url: "https://example.com/affiliate/slowfeeder"),
        RecommendedProduct(title: "Harness", subtitle: "Comfortable daily walk harness", url: "https://example.com/affiliate/harness"),
        RecommendedProduct(title: "Leash", subtitle: "Durable everyday leash", url: "https://example.com/affiliate/leash"),
        RecommendedProduct(title: "Seat Belt Clip", subtitle: "Safer car rides for your pet", url: "https://example.com/affiliate/seatbelt"),
        RecommendedProduct(title: "Paw Balm", subtitle: "Soothes dry or cracked paws", url: "https://example.com/affiliate/pawbalm"),
        RecommendedProduct(title: "Shampoo", subtitle: "Gentle formula for sensitive skin", url: "https://example.com/affiliate/shampoo"),
        RecommendedProduct(title: "Dental Chews", subtitle: "Daily dental health support", url: "https://example.com/affiliate/dental"),
        RecommendedProduct(title: "Plush Toy", subtitle: "Pet-approved play favorite", url: "https://example.com/affiliate/toy")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Our picks") {
                    ForEach(products) { item in
                        Button {
                            guard let url = URL(string: item.url) else { return }
                            openURL(url)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .foregroundStyle(Color("BrandDark"))
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Text(AffiliateLinkDisclosure.listFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Pet Picks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// Keep old name as typealias so any stale references compile.
typealias LucysFavoritesView = HelpfulProductsView

private struct RecommendedProduct: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let url: String
}
