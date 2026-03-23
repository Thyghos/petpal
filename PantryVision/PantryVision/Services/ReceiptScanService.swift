import Foundation
import UIKit
import Vision

enum ReceiptScanError: Error {
    case noCGImage
    case visionFailed
}

struct ReceiptScanResult {
    let ocrText: String
    let itemCandidates: [String]
}

/// MVP OCR-only receipt scanner.
/// It extracts text and returns simple item candidates; grocery list matching happens in `GroceryListStore`.
struct ReceiptScanService {
    private let maxCandidates = 25

    func scanReceipt(_ image: UIImage) async throws -> ReceiptScanResult {
        guard let cgImage = image.cgImage else {
            throw ReceiptScanError.noCGImage
        }

        let ocrText = try await recognizeText(from: cgImage)
        let candidates = extractCandidates(from: ocrText)
        return ReceiptScanResult(ocrText: ocrText, itemCandidates: Array(candidates.prefix(maxCandidates)))
    }

    private func recognizeText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ReceiptScanError.visionFailed)
                    return
                }

                let strings: [String] = results.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                continuation.resume(returning: strings.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func extractCandidates(from ocrText: String) -> [String] {
        let lowered = ocrText.lowercased()
        let parts = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let stopwords: Set<String> = [
            "total", "tax", "subtotal", "cash", "card", "visa", "mastercard",
            "change", "thank", "you", "receipt", "order", "store", "number",
            "and", "the", "a", "an", "of", "to", "in", "for", "with", "on", "at", "is", "are",
            "milk" // keep real items; do not filter out
        ]

        var seen = Set<String>()
        var ordered: [String] = []
        for raw in parts {
            let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard token.count >= 3 && token.count <= 20 else { continue }
            guard token.rangeOfCharacter(from: CharacterSet.letters) != nil else { continue }
            guard !stopwords.contains(token) else { continue }

            if seen.insert(token).inserted {
                ordered.append(token.capitalized)
            }
            if ordered.count >= maxCandidates { break }
        }

        return ordered
    }
}

