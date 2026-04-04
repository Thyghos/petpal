import SwiftUI

struct HelpfulProductsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Paste your Harvest Hosts referral URL (from your member dashboard).
    private static let harvestHostsReferralURLString = "https://www.harvest-hosts.com/2ZX3ZT1/2CTPL/"
    private static let petsmontReferralURLString = "https://petsmont.com/k8tskya"
    private static let canadaPetCareReferralURLString = "https://www.jdoqocy.com/click-101715977-11745546"
    private static let chewyReferralURLString = "https://chewpanions.chewy.com/k8tskya"
    private static let amazonShopURLString = "https://www.amazon.com/shop/k8tskya"

    private static let lucysFavoriteThingsSubtitle = "Lucy's favorite things"

    private static let lucyIntroFooter = "Lucy, the reason we created this app, is 14 and has been traveling full time for 5 years. These are companies and items she has used."

    private static let harvestHostsPromoLine = "Use code HHFRIENDS15 for 15% off."
    private static let petsmontPromoLine = "Use code k8tskya15 for 15% off."
    private static let canadaPetCarePromoLine = "Discounts on pet meds"

    /// Add `RecommendedProduct(title:subtitle:url:)` rows when you have affiliate links.
    private let products: [RecommendedProduct] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PartnerPickRow(
                        imageName: "AmazonDealLogo",
                        title: "Amazon",
                        subtitle: Self.lucysFavoriteThingsSubtitle,
                        urlString: Self.amazonShopURLString,
                        thumbnailBackdrop: Color(.systemGray6)
                    )
                    PartnerPickRow(
                        imageName: "ChewyDealLogo",
                        title: "Chewy",
                        subtitle: Self.lucysFavoriteThingsSubtitle,
                        urlString: Self.chewyReferralURLString
                    )
                    PartnerPickRow(
                        imageName: "PetsmontBuddyGuard",
                        title: "Petsmont Buddy Guard",
                        subtitle: "Organic mushroom powder for immune support — dogs & cats",
                        promoLine: Self.petsmontPromoLine,
                        urlString: Self.petsmontReferralURLString
                    )
                    PartnerPickRow(
                        imageName: "HarvestHostsReferral",
                        title: "Harvest Hosts",
                        subtitle: "Overnight RV stays at wineries, farms & breweries",
                        promoLine: Self.harvestHostsPromoLine,
                        urlString: Self.harvestHostsReferralURLString
                    )
                    PartnerPickRow(
                        imageName: "CanadaPetCareBanner",
                        title: "Canada Pet Care",
                        subtitle: "Pet supplies, flea & tick, heartworm meds & more",
                        promoLine: Self.canadaPetCarePromoLine,
                        urlString: Self.canadaPetCareReferralURLString,
                        thumbnailWidth: 40,
                        thumbnailHeight: 72
                    )
                }

                if !products.isEmpty {
                    Section("More deals") {
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
                }

                Section {
                    Text(Self.lucyIntroFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Text(AffiliateLinkDisclosure.listFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Pet Deals")
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

private struct PartnerPickRow: View {
    @Environment(\.openURL) private var openURL

    let imageName: String
    let title: String
    let subtitle: String
    var promoLine: String? = nil
    let urlString: String
    var thumbnailWidth: CGFloat = 72
    var thumbnailHeight: CGFloat = 40
    /// Light backdrop + `scaledToFit` for logos that need contrast (e.g. dark-on-dark PNGs).
    var thumbnailBackdrop: Color? = nil

    var body: some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            openURL(url)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let thumbnailBackdrop {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(thumbnailBackdrop)
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .padding(6)
                        }
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: thumbnailWidth, height: thumbnailHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(Color("BrandDark"))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let promoLine {
                        Text(promoLine)
                            .font(.caption2)
                            .foregroundStyle(Color("BrandDark"))
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RecommendedProduct: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let url: String
}
