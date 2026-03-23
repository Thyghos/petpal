import Foundation
import UIKit
import Vision

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum PhotoAnalysisResult {
    case items([MappedGroceryItem])
}

struct MappedGroceryItem: Equatable {
    let name: String
    let estimatedUnitPrice: Double?
}

enum PhotoAnalysisServiceError: Error {
    case noCGImage
    case visionFailed
}

/// Hybrid pipeline:
/// 1) Vision OCR on-device -> extract pantry-ish candidates
/// 2) Optional Cloud Function call -> AI normalizes candidates into final grocery items
struct PhotoAnalysisService {
    private let ocrCandidatesLimit = 10
    private let mappingCandidatesLimit = 30

    func analyzeFridgePhoto(_ image: UIImage) async throws -> PhotoAnalysisResult {
        guard let cgImage = image.cgImage else {
            throw PhotoAnalysisServiceError.noCGImage
        }

        // 1) OCR locally.
        let ocrText = try await recognizeText(from: cgImage)
        let localCandidates = extractCandidates(from: ocrText)

        // If OCR is empty, still return something useful so the UX isn't blank.
        let fallbackItems = localCandidates.prefix(ocrCandidatesLimit).map { MappedGroceryItem(name: $0, estimatedUnitPrice: nil) }
        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .items(Array(fallbackItems))
        }

        // 2) Optional AI normalization through Cloud Function (server has the API key).
        guard let baseURL = PantryVisionConfig.cloudFunctionsBaseURL else {
            return .items(Array(fallbackItems))
        }

        let cloudClient = CloudFunctionsClient(baseURL: baseURL)
        let mappingAPI = FridgeItemMappingAPI(client: cloudClient)

        // If Firebase Auth isn't configured yet, we can still call without a token
        // (Cloud Functions should decide whether to enforce auth).
        let idToken: String? = await AuthTokenProvider.idToken()

        let responseItems = try await mappingAPI.mapOcrToItems(
            ocrText: ocrText,
            candidates: Array(localCandidates.prefix(mappingCandidatesLimit)),
            idToken: idToken
        )

        let mapped = responseItems.map { MappedGroceryItem(name: $0.name, estimatedUnitPrice: $0.estimatedUnitPrice) }
        return .items(mapped.isEmpty ? Array(fallbackItems) : mapped)
    }

    private func recognizeText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: PhotoAnalysisServiceError.visionFailed)
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
        // Very light heuristic: split into tokens and keep pantry-like words.
        let lowered = ocrText.lowercased()

        let parts = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let stopwords: Set<String> = [
            "and", "the", "a", "an", "of", "to", "in", "for", "with", "on", "at", "is", "are", "was", "were",
            "milk", // keep real items (we won't remove this)
        ]

        let filtered: [String] = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { token in
                guard token.count >= 3 && token.count <= 20 else { return false }
                guard token.rangeOfCharacter(from: CharacterSet.letters) != nil else { return false }
                if stopwords.contains(token) { return false }
                return true
            }

        // Unique while preserving order.
        var seen = Set<String>()
        var ordered: [String] = []
        for token in filtered {
            if seen.insert(token).inserted {
                ordered.append(token.capitalized)
            }
        }
        return ordered
    }
}

/// Optional auth helper for Cloud Functions requests.
/// Works when FirebaseAuth is available; otherwise returns nil.
enum AuthTokenProvider {
    static func idToken() async -> String? {
        #if canImport(FirebaseAuth)
        do {
            let user = Auth.auth().currentUser
            guard let user else { return nil }
            return try await user.getIDToken()
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}

