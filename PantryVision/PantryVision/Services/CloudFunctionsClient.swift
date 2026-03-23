import Foundation

enum CloudFunctionsClientError: Error {
    case invalidBaseURL
    case invalidResponse
}

/// Thin HTTPS client for calling Firebase Cloud Functions directly.
/// This keeps the app free of API keys; the Cloud Function holds secrets (OpenAI key).
struct CloudFunctionsClient {
    let baseURL: URL

    func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        idToken: String?
    ) async throws -> Response {
        var requestURL = baseURL
        requestURL.appendPathComponent(path)

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idToken, !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw CloudFunctionsClientError.invalidResponse
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

