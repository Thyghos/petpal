// SourceAttachmentService.swift
// Creates `PetRecordAttachment` rows for AI / scan provenance (caller saves `ModelContext`).

import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

enum SourceAttachmentService {
    /// Stable `yyyy-MM-dd` for filenames (local calendar).
    static func fileDateToken(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Safe fragment for filenames (keeps alphanumerics; replaces others with `-`).
    static func sanitizedFilenameSlug(_ raw: String, emptyFallback: String = "item") -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return emptyFallback }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = trimmed.unicodeScalars.map { us -> Character in
            allowed.contains(us) ? Character(us) : "-"
        }
        var s = String(mapped)
        while s.contains("--") {
            s = s.replacingOccurrences(of: "--", with: "-")
        }
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return s.isEmpty ? emptyFallback : s
    }

    #if canImport(UIKit)
    /// Inserts a JPEG attachment (0.85). Caller typically saves `modelContext` after linking parents.
    @discardableResult
    static func attachPhoto(
        _ image: UIImage,
        to modelContext: ModelContext,
        parentRecordId: UUID,
        parentKind: PetRecordAttachmentParentKind,
        filename: String,
        note: String
    ) -> PetRecordAttachment? {
        guard let data = image.jpegData(compressionQuality: 0.85), !data.isEmpty else { return nil }
        let att = PetRecordAttachment(
            parentRecordId: parentRecordId,
            parentKind: parentKind,
            fileData: data,
            contentKind: "image",
            displayFileName: filename,
            sourceNote: note
        )
        modelContext.insert(att)
        return att
    }
    #endif

    /// Reads PDF bytes from disk (e.g. security-scoped import URL).
    @discardableResult
    static func attachPDF(
        url: URL,
        to modelContext: ModelContext,
        parentRecordId: UUID,
        parentKind: PetRecordAttachmentParentKind,
        filename: String,
        note: String
    ) -> PetRecordAttachment? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return attachPDFData(
            data,
            to: modelContext,
            parentRecordId: parentRecordId,
            parentKind: parentKind,
            filename: filename,
            note: note
        )
    }

    /// In-memory PDF (e.g. last imported vet-visit PDF bytes).
    @discardableResult
    static func attachPDFData(
        _ data: Data,
        to modelContext: ModelContext,
        parentRecordId: UUID,
        parentKind: PetRecordAttachmentParentKind,
        filename: String,
        note: String
    ) -> PetRecordAttachment? {
        guard !data.isEmpty else { return nil }
        let att = PetRecordAttachment(
            parentRecordId: parentRecordId,
            parentKind: parentKind,
            fileData: data,
            contentKind: "pdf",
            displayFileName: filename,
            sourceNote: note
        )
        modelContext.insert(att)
        return att
    }
}

#if canImport(UIKit)
@MainActor
enum VetImportSourceAttachment {
    /// Attaches the vet-import photo or PDF to the visit, vaccine certs, and reminders created in the same save. Clears `PDFImportCoordinator` snapshots.
    static func attachAfterVetVisitSave(
        modelContext: ModelContext,
        visitId: UUID,
        visitDate: Date,
        clinicDisplay: String,
        visitDateLabel: String,
        vaccineCertificates: [(vaccineName: String, id: UUID)],
        medicationReminderIds: [UUID],
        nextAppointmentReminderId: UUID?
    ) {
        let coord = PDFImportCoordinator.shared
        let dateTok = SourceAttachmentService.fileDateToken(visitDate)
        let todayTok = SourceAttachmentService.fileDateToken(Date())
        let clinicForNote = clinicDisplay

        if let pdf = coord.lastVetImportPDFData, !pdf.isEmpty {
            let baseNote = "PDF imported on \(todayTok). AI extracted: \(clinicForNote), \(visitDateLabel)."
            _ = SourceAttachmentService.attachPDFData(
                pdf,
                to: modelContext,
                parentRecordId: visitId,
                parentKind: .vetVisit,
                filename: "vet-visit-\(dateTok).pdf",
                note: baseNote
            )
            for pair in vaccineCertificates {
                let note = "Source document for \(pair.vaccineName)"
                _ = SourceAttachmentService.attachPDFData(
                    pdf,
                    to: modelContext,
                    parentRecordId: pair.id,
                    parentKind: .certificate,
                    filename: "vaccine-source-\(dateTok).pdf",
                    note: note
                )
            }
            for rid in medicationReminderIds {
                _ = SourceAttachmentService.attachPDFData(
                    pdf,
                    to: modelContext,
                    parentRecordId: rid,
                    parentKind: .reminder,
                    filename: "medication-source-\(dateTok).pdf",
                    note: baseNote
                )
            }
            if let apt = nextAppointmentReminderId {
                _ = SourceAttachmentService.attachPDFData(
                    pdf,
                    to: modelContext,
                    parentRecordId: apt,
                    parentKind: .reminder,
                    filename: "appointment-source-\(dateTok).pdf",
                    note: baseNote
                )
            }
        } else if let img = coord.sourceImage {
            let baseNote = "Photo imported on \(todayTok). AI extracted: \(clinicForNote), \(visitDateLabel)."
            _ = SourceAttachmentService.attachPhoto(
                img,
                to: modelContext,
                parentRecordId: visitId,
                parentKind: .vetVisit,
                filename: "vet-visit-\(dateTok).jpg",
                note: baseNote
            )
            for pair in vaccineCertificates {
                let note = "Source document for \(pair.vaccineName)"
                _ = SourceAttachmentService.attachPhoto(
                    img,
                    to: modelContext,
                    parentRecordId: pair.id,
                    parentKind: .certificate,
                    filename: "vaccine-source-\(dateTok).jpg",
                    note: note
                )
            }
            for rid in medicationReminderIds {
                _ = SourceAttachmentService.attachPhoto(
                    img,
                    to: modelContext,
                    parentRecordId: rid,
                    parentKind: .reminder,
                    filename: "medication-source-\(dateTok).jpg",
                    note: baseNote
                )
            }
            if let apt = nextAppointmentReminderId {
                _ = SourceAttachmentService.attachPhoto(
                    img,
                    to: modelContext,
                    parentRecordId: apt,
                    parentKind: .reminder,
                    filename: "appointment-source-\(dateTok).jpg",
                    note: baseNote
                )
            }
        }

        coord.clearVetVisitSourceImage()
        coord.clearVetImportPDFSnapshot()
    }
}

@MainActor
enum ShelterImportSourceAttachment {
    /// Attaches shelter PDF or photo to each certificate, medication reminder, and an optional `StoredVetDocument`. Clears shelter import snapshots.
    static func attachAfterShelterSave(
        modelContext: ModelContext,
        petName: String,
        anchorDate: Date,
        anchorLabel: String,
        vaccineCertificates: [(vaccineName: String, id: UUID)],
        medicationReminderIds: [UUID],
        storedDocumentId: UUID?
    ) {
        let coord = PDFImportCoordinator.shared
        let nameSlug = SourceAttachmentService.sanitizedFilenameSlug(petName, emptyFallback: "pet")
        let dateTok = SourceAttachmentService.fileDateToken(anchorDate)
        let todayTok = SourceAttachmentService.fileDateToken(Date())

        if let pdf = coord.lastShelterImportPDFData, !pdf.isEmpty {
            if let docId = storedDocumentId {
                let docNote = "Original document from a breeder or rescue. Imported on \(todayTok). Used to create pet profile."
                _ = SourceAttachmentService.attachPDFData(
                    pdf,
                    to: modelContext,
                    parentRecordId: docId,
                    parentKind: .vetDocument,
                    filename: "shelter-record-\(nameSlug)-\(dateTok).pdf",
                    note: docNote
                )
            }
            for pair in vaccineCertificates {
                let slug = SourceAttachmentService.sanitizedFilenameSlug(pair.vaccineName)
                let note = "Source document for \(pair.vaccineName). Imported from breeder or rescue records on \(anchorLabel)."
                _ = SourceAttachmentService.attachPDFData(
                    pdf,
                    to: modelContext,
                    parentRecordId: pair.id,
                    parentKind: .certificate,
                    filename: "vaccine-source-\(slug)-\(dateTok).pdf",
                    note: note
                )
            }
            for rid in medicationReminderIds {
                let note = "Created from breeder or rescue import for \(petName) on \(anchorLabel). Original document is attached under Documents."
                _ = SourceAttachmentService.attachPDFData(
                    pdf,
                    to: modelContext,
                    parentRecordId: rid,
                    parentKind: .reminder,
                    filename: "shelter-med-\(dateTok).pdf",
                    note: note
                )
            }
        } else if let img = coord.sourceImage {
            if let docId = storedDocumentId {
                let docNote = "Original document from a breeder or rescue. Imported on \(todayTok). Used to create pet profile."
                _ = SourceAttachmentService.attachPhoto(
                    img,
                    to: modelContext,
                    parentRecordId: docId,
                    parentKind: .vetDocument,
                    filename: "shelter-record-\(nameSlug)-\(dateTok).jpg",
                    note: docNote
                )
            }
            for pair in vaccineCertificates {
                let slug = SourceAttachmentService.sanitizedFilenameSlug(pair.vaccineName)
                let note = "Source document for \(pair.vaccineName). Imported from breeder or rescue records on \(anchorLabel)."
                _ = SourceAttachmentService.attachPhoto(
                    img,
                    to: modelContext,
                    parentRecordId: pair.id,
                    parentKind: .certificate,
                    filename: "vaccine-source-\(slug)-\(dateTok).jpg",
                    note: note
                )
            }
            for rid in medicationReminderIds {
                let note = "Created from breeder or rescue import for \(petName) on \(anchorLabel). Original document is attached under Documents."
                _ = SourceAttachmentService.attachPhoto(
                    img,
                    to: modelContext,
                    parentRecordId: rid,
                    parentKind: .reminder,
                    filename: "shelter-med-\(dateTok).jpg",
                    note: note
                )
            }
        }

        coord.clearShelterImportSnapshot()
    }
}
#endif
