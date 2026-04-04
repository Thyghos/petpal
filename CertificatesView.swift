// CertificatesView.swift
// Rabies, licenses, travel/CDC forms, and other documents per pet.

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

enum PetCertificateCategory {
    static let all = ["Vaccine", "Dog license", "CDC / travel", "Other"]
}

struct CertificatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PetCertificate.updatedAt, order: .reverse) private var allCertificates: [PetCertificate]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var showingAdd = false
    @State private var refreshID = UUID()
    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif

    private var scopedPetId: UUID? {
        FeaturePetScope.resolvedPetId(pets: pets)
    }

    private var petScopedCertificates: [PetCertificate] {
        guard let pid = scopedPetId else { return [] }
        return allCertificates.filter { $0.petId == pid }
            .sorted {
                let e0 = $0.expirationDate.map { $0.timeIntervalSince1970 } ?? .infinity
                let e1 = $1.expirationDate.map { $0.timeIntervalSince1970 } ?? .infinity
                if e0 != e1 { return e0 < e1 }
                return $0.updatedAt > $1.updatedAt
            }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                FeaturePetScopeHeader(pets: pets)
                Text("Vaccines, licenses, travel paperwork — attach photos, scans, or PDFs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                if petScopedCertificates.isEmpty {
                    ContentUnavailableView {
                        Label("No Certificates", systemImage: "doc.badge.plus")
                    } description: {
                        Text("Add rabies certificates, licenses, CDC forms, or anything else you need on hand.")
                    } actions: {
                        Button("Add Certificate") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(petScopedCertificates, id: \.id) { cert in
                            NavigationLink {
                                PetCertificateDetailView(certificate: cert)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cert.title.isEmpty ? "Certificate" : cert.title)
                                        .font(.headline)
                                    Text(cert.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let exp = cert.expirationDate {
                                        Text(expLabel(exp))
                                            .font(.caption2)
                                            .foregroundStyle(expirationAccent(exp))
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteCertificates)
                    }
                }
            }
            .id(refreshID)
            .navigationTitle("Certificates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAdd, onDismiss: { refreshID = UUID() }) {
                PetCertificateEditorView(existingId: nil)
            }
            #if os(iOS)
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            #endif
        }
    }

    private func expLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Expires today" }
        if date < Date() { return "Expired \(date.formatted(date: .abbreviated, time: .omitted))" }
        return "Expires \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private func expirationAccent(_ date: Date) -> Color {
        if date < Date() { return .red }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 999
        if days <= 30 { return .orange }
        return Color.secondary.opacity(0.85)
    }

    private func deleteCertificates(at offsets: IndexSet) {
        for index in offsets {
            let c = petScopedCertificates[index]
            PetRecordAttachment.deleteAll(parentRecordId: c.id, parentKind: .certificate, context: modelContext)
            modelContext.delete(c)
        }
        try? modelContext.save()
    }
}

struct PetCertificateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var certificate: PetCertificate
    @Query private var attachments: [PetRecordAttachment]

    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif

    private var certAttachments: [PetRecordAttachment] {
        attachments.filter {
            $0.parentRecordId == certificate.id && $0.parentKind == PetRecordAttachmentParentKind.certificate.rawValue
        }
    }

    var body: some View {
        Form {
            Section("Certificate") {
                TextField("Name", text: $certificate.title)
                Picker("Type", selection: $certificate.category) {
                    ForEach(PetCertificateCategory.all, id: \.self) { Text($0).tag($0) }
                }
                Toggle("Expiration date", isOn: Binding(
                    get: { certificate.expirationDate != nil },
                    set: { on in
                        certificate.expirationDate = on ? (certificate.expirationDate ?? Date()) : nil
                    }
                ))
                if certificate.expirationDate != nil {
                    DatePicker(
                        "Expires",
                        selection: Binding(
                            get: { certificate.expirationDate ?? Date() },
                            set: { certificate.expirationDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            }
            Section("Notes") {
                TextField("Notes", text: $certificate.notes, axis: .vertical)
                    .lineLimit(3...10)
            }
            Section {
                Text("Add a photo, file, or scan below. Long-press an attachment to share or print.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            RecordAttachmentsSection(parentRecordId: certificate.id, parentKind: .certificate)
        }
        .navigationTitle(certificate.title.isEmpty ? "Certificate" : certificate.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            certificate.updatedAt = Date()
            try? modelContext.save()
        }
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let printable = CertificatePrintableView(certificate: certificate)
                        if let img = PrintShareHelper.renderToImage(printable) {
                            var items: [Any] = [img, certificateShareText]
                            items.append(contentsOf: attachmentShareItems())
                            DispatchQueue.main.async {
                                sharePayload = ShareSheetPayload(items: items)
                            }
                        }
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        let printable = CertificatePrintableView(certificate: certificate)
                        DispatchQueue.main.async {
                            PrintShareHelper.printView(printable, title: certificate.title.isEmpty ? "Certificate" : certificate.title)
                        }
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        #endif
    }

    private var certificateShareText: String {
        var lines: [String] = [certificate.title.isEmpty ? "Certificate" : certificate.title]
        lines.append("Type: \(certificate.category)")
        if let exp = certificate.expirationDate {
            lines.append("Expiration: \(exp.formatted(date: .abbreviated, time: .omitted))")
        }
        if !certificate.notes.isEmpty {
            lines.append(certificate.notes)
        }
        lines.append("Shared from Petpal")
        return lines.joined(separator: "\n")
    }

    #if os(iOS)
    private func attachmentShareItems() -> [Any] {
        var out: [Any] = []
        let dir = FileManager.default.temporaryDirectory
        for att in certAttachments {
            if att.contentKind == "image", let img = UIImage(data: att.fileData) {
                out.append(img)
            } else if att.contentKind == "pdf" {
                let name = "certificate-\(certificate.id.uuidString.prefix(8)).pdf"
                let url = dir.appendingPathComponent(name)
                try? att.fileData.write(to: url)
                out.append(url)
            }
        }
        return out
    }
    #endif
}

private struct CertificatePrintableView: View {
    let certificate: PetCertificate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Certificate")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.black)
            Text(certificate.title.isEmpty ? "Untitled" : certificate.title)
                .font(.headline)
                .foregroundStyle(.black)
            Text("Type: \(certificate.category)")
                .font(.subheadline)
                .foregroundStyle(.black.opacity(0.8))
            if let exp = certificate.expirationDate {
                Text("Expiration: \(exp.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.8))
            }
            if !certificate.notes.isEmpty {
                Divider()
                Text(certificate.notes)
                    .font(.caption)
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .preferredColorScheme(.light)
    }
}

struct PetCertificateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    let existingId: UUID?

    @State private var draftRecordId: UUID?
    @State private var titleText = ""
    @State private var category = "Other"
    @State private var notes = ""
    @State private var hasExpiration = false
    @State private var expiration = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Certificate") {
                    TextField("Name (e.g. Rabies 2025)", text: $titleText)
                    Picker("Type", selection: $category) {
                        ForEach(PetCertificateCategory.all, id: \.self) { Text($0).tag($0) }
                    }
                    Toggle("Expiration date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires", selection: $expiration, displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...8)
                }
                if let rid = draftRecordId {
                    RecordAttachmentsSection(parentRecordId: rid, parentKind: .certificate)
                }
            }
            .navigationTitle("New Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if draftRecordId == nil {
                    draftRecordId = existingId ?? UUID()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let rid = draftRecordId, existingId == nil {
                            PetRecordAttachment.deleteAll(parentRecordId: rid, parentKind: .certificate, context: modelContext)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let rid = draftRecordId else { return }
                        let pid = FeaturePetScope.resolvedPetId(pets: pets)
                        let c = PetCertificate(
                            id: rid,
                            petId: pid,
                            title: titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Certificate" : titleText.trimmingCharacters(in: .whitespacesAndNewlines),
                            notes: notes,
                            category: category,
                            expirationDate: hasExpiration ? expiration : nil
                        )
                        modelContext.insert(c)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
