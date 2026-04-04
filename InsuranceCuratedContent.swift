// InsuranceCuratedContent.swift
// Developer-provided insurance tips and affiliate links — same for every pet.
// User-entered policies stay in SwiftData (`PetInsuranceInfo` with `petId`) and are scoped per pet in the UI.

import Foundation

struct InsuranceCuratedItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String?
    /// Set when you add an affiliate or partner URL; opens in Safari / in-app browser.
    let url: URL?

    init(id: String, title: String, detail: String? = nil, url: URL? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
        self.url = url
    }
}

enum InsuranceCuratedContent {
    /// Add rows here; they appear for **all** pets at the top of Insurance.
    /// Example:
    /// `InsuranceCuratedItem(id: "partner-a", title: "Compare plans", detail: "Short blurb", url: URL(string: "https://…"))`
    static let items: [InsuranceCuratedItem] = [
        // Intentionally empty until you add affiliate or static links.
    ]
}

// MARK: - Affiliate disclosure (in-app + legal cross-reference)

/// Short copy for footers on **Pet Deals** and **Insurance** when outbound links may include affiliate or partner programs.
enum AffiliateLinkDisclosure {
    static let listFooter = """
    Some links are affiliate or partner links. Petpal may earn a commission if you buy or sign up—at no extra cost to you. Those websites set their own cookies and privacy rules; Petpal does not control what they collect after you leave the app.
    """
}
