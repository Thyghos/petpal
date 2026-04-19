// ClaudeProxyClient.swift
// All Claude traffic goes through the Cloudflare Vet AI worker (`APIConfiguration.vetAIProxyURL`), not api.anthropic.com.

import Foundation

enum ClaudeProxyError: Error, LocalizedError {
    case noProxyConfigured
    case invalidURL
    case httpError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noProxyConfigured:
            return "Vet AI proxy is not configured."
        case .invalidURL:
            return "Invalid Vet AI proxy URL."
        case .httpError(let s):
            return s
        case .invalidResponse:
            return "Unexpected response from Vet AI proxy."
        }
    }
}

enum ClaudeProxyClient {
    private static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }

    /// POST to the Vet AI proxy — same JSON contract as `VetAIView.callProxyAPI` (`reply` string in JSON body).
    static func send(
        messages: [[String: String]],
        petName: String,
        petSpecies: String,
        petContext: String = ""
    ) async throws -> String {
        guard let proxyURLString = APIConfiguration.vetAIProxyURL else {
            throw ClaudeProxyError.noProxyConfigured
        }
        guard let url = URL(string: proxyURLString) else {
            throw ClaudeProxyError.invalidURL
        }
        let token = APIConfiguration.vetAIProxyToken

        let body: [String: Any] = [
            "messages": messages,
            "petName": petName,
            "petSpecies": petSpecies,
            "petContext": petContext
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session().data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                ?? "HTTP \(http.statusCode)"
            throw ClaudeProxyError.httpError(message)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reply = json["reply"] as? String,
              !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClaudeProxyError.invalidResponse
        }
        return reply
    }
}
