// BringFidoInAppBrowser.swift
// In-app Safari for BringFido (no API) — city pages match bringfido.com URL patterns.

import CoreLocation
import Foundation
import MapKit
import SwiftUI

#if os(iOS)
import SafariServices
import UIKit

/// Presents BringFido inside the app via `SFSafariViewController`.
struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#endif

// MARK: - BringFido city URLs (reverse geocode → slug like san_francisco_ca_us)

enum BringFidoBrowseSection: String, CaseIterable, Identifiable {
    case lodging = "Hotels & lodging"
    case restaurant = "Restaurants"
    case attractionParks = "Dog parks"
    case attraction = "Activities"

    var id: String { rawValue }

    /// BringFido path after domain, ending before `/city/`.
    var pathPrefix: String {
        switch self {
        case .lodging: return "lodging"
        case .restaurant: return "restaurant"
        case .attractionParks: return "attraction/parks"
        case .attraction: return "attraction"
        }
    }

    var systemImage: String {
        switch self {
        case .lodging: return "bed.double.fill"
        case .restaurant: return "fork.knife"
        case .attractionParks: return "tree.fill"
        case .attraction: return "figure.walk"
        }
    }
}

enum BringFidoWebLink {
    static let home = URL(string: "https://www.bringfido.com/")!

    /// Builds `https://www.bringfido.com/{prefix}/city/{slug}/` when possible.
    static func cityURL(section: BringFidoBrowseSection, mapItem: MKMapItem) -> URL? {
        guard let slug = citySlug(from: mapItem) else { return nil }
        let path = "\(section.pathPrefix)/city/\(slug)/"
        return URL(string: "https://www.bringfido.com/\(path)")
    }

    /// `locality_adminArea_country` lowercase with underscores (e.g. `san_francisco_ca_us`).
    /// Uses addressRepresentations (iOS 26+) instead of deprecated placemark.
    static func citySlug(from mapItem: MKMapItem) -> String? {
        guard let repr = mapItem.addressRepresentations else { return nil }
        guard let rawCity = repr.cityName?.trimmingCharacters(in: .whitespacesAndNewlines), !rawCity.isEmpty else {
            return nil
        }
        let city = rawCity
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ".", with: "")
        let country = (repr.region?.identifier.description ?? "us").lowercased()

        var region = ""
        if let context = repr.cityWithContext(.full) {
            let parts = context.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2, parts[1].count == 2, parts[1].allSatisfy({ $0.isLetter }) {
                region = parts[1].lowercased()
            }
        }
        if region.isEmpty {
            return "\(city)_\(country)"
        }
        return "\(city)_\(region)_\(country)"
    }

    static func resolveURL(for coordinate: CLLocationCoordinate2D, section: BringFidoBrowseSection) async -> URL {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let mapItem = await reverseGeocode(location: location) else {
            return fallbackURL(for: section)
        }
        if let url = cityURL(section: section, mapItem: mapItem) {
            return url
        }
        return fallbackURL(for: section)
    }

    private static func fallbackURL(for section: BringFidoBrowseSection) -> URL {
        switch section {
        case .lodging: return URL(string: "https://www.bringfido.com/lodging/") ?? home
        case .restaurant: return URL(string: "https://www.bringfido.com/restaurant/") ?? home
        case .attractionParks: return URL(string: "https://www.bringfido.com/attraction/parks/") ?? home
        case .attraction: return URL(string: "https://www.bringfido.com/attraction/") ?? home
        }
    }

    private static func reverseGeocode(location: CLLocation) async -> MKMapItem? {
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        guard let items = try? await request.mapItems, let first = items.first else { return nil }
        return first
    }
}
