// PetpalPDFImporter.swift
// Local PDF text extraction via PDFKit (no network).

import Foundation
import PDFKit

enum PetpalPDFImportError: Equatable, LocalizedError {
    case couldNotOpenDocument
    case corruptedOrInvalid
    case passwordProtected
    case emptyDocument
    case noExtractableText

    var errorDescription: String? {
        switch self {
        case .couldNotOpenDocument:
            return "The PDF could not be opened."
        case .corruptedOrInvalid:
            return "The file does not appear to be a valid PDF."
        case .passwordProtected:
            return "This PDF is password-protected."
        case .emptyDocument:
            return "This PDF has no pages."
        case .noExtractableText:
            return "No text could be extracted from this PDF."
        }
    }
}

enum PetpalPDFImporter {
    /// Extracts and concatenates text from every page. Returns `nil` on failure with a specific error.
    static func extractFullText(from url: URL) -> (text: String?, error: PetpalPDFImportError?) {
        guard let document = PDFDocument(url: url) else {
            return (nil, .couldNotOpenDocument)
        }

        if document.isEncrypted {
            guard document.unlock(withPassword: "") else {
                return (nil, .passwordProtected)
            }
        }

        guard document.pageCount > 0 else {
            return (nil, .emptyDocument)
        }

        var segments: [String] = []
        segments.reserveCapacity(document.pageCount)

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            guard let raw = page.string else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                segments.append(trimmed)
            }
        }

        let combined = segments.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if combined.isEmpty {
            return (nil, .noExtractableText)
        }

        return (combined, nil)
    }
}
