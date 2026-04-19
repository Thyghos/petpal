// VetStoredDocumentsListView.swift
// Lists SwiftData `StoredVetDocument` rows and attachments (not a legacy feature screen — root is tab navigation).

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct VetStoredDocumentsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoredVetDocument.recordDate, order: .reverse) private var documents: [StoredVetDocument]

    var body: some View {
        Group {
            if documents.isEmpty {
                ContentUnavailableView {
                    Label("No Documents", systemImage: "doc.text")
                } description: {
                    Text("Store lab results, referrals, and other PDFs or scans in one place.")
                } actions: {
                    Button("Add document") { addDocument() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    InlineAddListRow(title: "Add Document") { addDocument() }
                    ForEach(documents, id: \.id) { doc in
                        NavigationLink {
                            VetStoredDocumentDetailView(document: doc)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(doc.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : doc.title)
                                    .font(.headline)
                                Text(doc.documentKind)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(doc.recordDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary.opacity(0.85))
                            }
                        }
                    }
                    .onDelete(perform: deleteDocuments)
                }
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addDocument()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add document")
            }
        }
    }

    private func addDocument() {
        let doc = StoredVetDocument(
            title: "New document",
            notes: "",
            documentKind: "General",
            recordDate: Date(),
            createdAt: Date()
        )
        modelContext.insert(doc)
    }

    private func deleteDocuments(at offsets: IndexSet) {
        for index in offsets {
            let doc = documents[index]
            PetRecordAttachment.deleteAll(parentRecordId: doc.id, parentKind: .vetDocument, context: modelContext)
            modelContext.delete(doc)
        }
    }
}

private struct VetStoredDocumentDetailView: View {
    @Bindable var document: StoredVetDocument
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Form {
            Section("Details") {
                TextField("Title", text: $document.title)
                TextField("Kind", text: $document.documentKind)
                DatePicker("Record date", selection: $document.recordDate, displayedComponents: .date)
            }
            Section("Notes") {
                TextField("Notes", text: $document.notes, axis: .vertical)
                    .lineLimit(3...10)
            }
            RecordAttachmentsSection(parentRecordId: document.id, parentKind: .vetDocument)
        }
        .navigationTitle(document.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Document" : document.title)
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    scanDocumentPhoto()
                } label: {
                    Label("Scan Document", systemImage: "camera.fill")
                }
            }
        }
        #endif
    }

    #if os(iOS)
    private func scanDocumentPhoto() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        CameraAccessHelper.requestVideoAccessIfNeeded { ok in
            guard ok else { return }
            DirectCameraSession.present { image in
                guard let image else { return }
                PetRecordAttachment.insertImagePages(
                    [image],
                    parentRecordId: document.id,
                    parentKind: .vetDocument,
                    context: modelContext
                )
            }
        }
    }
    #endif
}
