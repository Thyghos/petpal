import Foundation

struct MappedGroceryItemDTO: Decodable, Equatable {
    let name: String
    let estimatedUnitPrice: Double?
}

struct MapOcrToGroceryItemsRequest: Encodable {
    let ocrText: String
    let candidates: [String]
    let language: String
}

struct MapOcrToGroceryItemsResponse: Decodable {
    let items: [MappedGroceryItemDTO]
}

/// Calls a Cloud Function that uses AI to normalize OCR candidates to grocery items.
struct FridgeItemMappingAPI {
    private let client: CloudFunctionsClient
    private let functionName: String

    init(client: CloudFunctionsClient, functionName: String = "mapOcrToGroceryItems") {
        self.client = client
        self.functionName = functionName
    }

    func mapOcrToItems(ocrText: String, candidates: [String], idToken: String?) async throws -> [MappedGroceryItemDTO] {
        let request = MapOcrToGroceryItemsRequest(
            ocrText: ocrText,
            candidates: candidates,
            language: PantryVisionConfig.languageCode
        )
        let response: MapOcrToGroceryItemsResponse = try await client.post(
            path: functionName,
            body: request,
            idToken: idToken
        )
        return response.items
    }
}

