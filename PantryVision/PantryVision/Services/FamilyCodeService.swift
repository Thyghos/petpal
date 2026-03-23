import Foundation

enum FamilyCodeServiceError: Error {
    case missingCloudFunctionsBaseURL
}

struct CreateFamilyResponse: Decodable {
    let familyId: String
    let familyCode: String
}

struct JoinFamilyResponse: Decodable {
    let familyId: String
}

struct CreateFamilyRequest: Encodable {
    let language: String
}

struct JoinFamilyRequest: Encodable {
    let familyCode: String
}

/// Resolves a family code -> familyId via Cloud Functions.
/// Security is handled server-side; the app only sends the code + (optionally) an auth token.
enum FamilyCodeService {
    static func createFamily() async throws -> CreateFamilyResponse {
        guard let baseURL = PantryVisionConfig.cloudFunctionsBaseURL else {
            throw FamilyCodeServiceError.missingCloudFunctionsBaseURL
        }
        let client = CloudFunctionsClient(baseURL: baseURL)
        let req = CreateFamilyRequest(language: PantryVisionConfig.languageCode)
        let idToken = await AuthTokenProvider.idToken()
        return try await client.post(path: "createFamily", body: req, idToken: idToken)
    }

    static func joinFamily(familyCode: String) async throws -> JoinFamilyResponse {
        guard let baseURL = PantryVisionConfig.cloudFunctionsBaseURL else {
            throw FamilyCodeServiceError.missingCloudFunctionsBaseURL
        }
        let client = CloudFunctionsClient(baseURL: baseURL)
        let req = JoinFamilyRequest(familyCode: familyCode)
        let idToken = await AuthTokenProvider.idToken()
        return try await client.post(path: "joinFamily", body: req, idToken: idToken)
    }
}

