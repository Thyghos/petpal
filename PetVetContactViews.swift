// PetVetContactViews.swift
// Read-only vet phone / email: tap to call or open Mail; context menu to copy.

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum PetContactClipboard {
    static func copy(_ string: String) {
        let t = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        #if os(iOS)
        UIPasteboard.general.string = t
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(t, forType: .string)
        #endif
    }
}

enum PetContactURLBuilder {
    static func phoneCallURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var cleaned = ""
        for ch in trimmed where ch.isNumber || ch == "+" {
            cleaned.append(ch)
        }
        guard cleaned.count >= 3 else { return nil }
        return URL(string: "tel:\(cleaned)")
    }

    static func mailComposeURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains("@") else { return nil }
        return URL(string: "mailto:\(trimmed)")
            ?? URL(string: "mailto:\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
    }
}

struct PetProfilePhoneRow: View {
    @Environment(\.openURL) private var openURL
    let title: String
    let phone: String
    @State private var showCopiedAlert = false

    private var callURL: URL? { PetContactURLBuilder.phoneCallURL(phone) }

    var body: some View {
        Button {
            if let url = callURL {
                openURL(url) { accepted in
                    if !accepted {
                        PetContactClipboard.copy(phone)
                        showCopiedAlert = true
                    }
                }
            } else {
                PetContactClipboard.copy(phone)
                showCopiedAlert = true
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.title3)
                    .foregroundStyle(Color("BrandOrange"))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(phone)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(callURL != nil ? Color("BrandBlue") : .primary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if callURL != nil {
                    Image(systemName: "phone.arrow.up.right")
                        .font(.body)
                        .foregroundStyle(Color("BrandBlue").opacity(0.85))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy phone number") {
                PetContactClipboard.copy(phone)
            }
            if let url = callURL {
                Button("Call") {
                    openURL(url)
                }
            }
        }
        .accessibilityHint(callURL != nil ? "Opens Phone to call this number" : "Phone number could not be dialed; use Copy from the menu")
        .alert("Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Phone number copied.")
        }
    }
}

struct PetProfileEmailRow: View {
    @Environment(\.openURL) private var openURL
    let title: String
    let email: String
    @State private var showCopiedAlert = false

    private var mailURL: URL? { PetContactURLBuilder.mailComposeURL(email) }

    var body: some View {
        Button {
            if let url = mailURL {
                openURL(url) { accepted in
                    if !accepted {
                        PetContactClipboard.copy(email)
                        showCopiedAlert = true
                    }
                }
            } else {
                PetContactClipboard.copy(email)
                showCopiedAlert = true
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.title3)
                    .foregroundStyle(Color("BrandOrange"))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(email)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(mailURL != nil ? Color("BrandBlue") : .primary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if mailURL != nil {
                    Image(systemName: "arrow.up.right.square")
                        .font(.body)
                        .foregroundStyle(Color("BrandBlue").opacity(0.85))
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy email") {
                PetContactClipboard.copy(email)
            }
            if let url = mailURL {
                Button("Send email") {
                    openURL(url)
                }
            }
        }
        .accessibilityHint(mailURL != nil ? "Opens Mail to email this address" : "Use Copy from the menu if Mail cannot open this address")
        .alert("Copied", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Email address copied.")
        }
    }
}
