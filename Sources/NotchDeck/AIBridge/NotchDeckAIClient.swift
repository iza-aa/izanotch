import Foundation

public enum AIClientError: Error, LocalizedError, Sendable {
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case timeout
    case missingAPIKey
    /// No interactive agent subprocess is running. Dispatch cannot be confirmed.
    case sessionUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API endpoint URL."
        case .httpError(let code, let msg): return "HTTP Error \(code): \(msg ?? "Unknown error")"
        case .decodingError(let err): return "Failed to decode response: \(err)"
        case .timeout: return "AI service request timed out."
        case .missingAPIKey: return "API key is not configured in Keychain."
        case .sessionUnavailable: return "No active Antigravity session. Start the agent first, then try again."
        }
    }
}

public final class NotchDeckAIClient: Sendable {
    public static let shared = NotchDeckAIClient()
    private let urlSession: URLSession

    public init(session: URLSession? = nil) {
        if let session = session {
            self.urlSession = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 10.0
            config.timeoutIntervalForResource = 15.0
            self.urlSession = URLSession(configuration: config)
        }
    }

    public func parseSchedule(
        userUtterance: String,
        currentDate: Date = Date(),
        apiKey: String
    ) async throws -> NLPScheduleResult {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingAPIKey
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        let currentISO = isoFormatter.string(from: currentDate)

        let systemInstruction = """
        You are the deterministic NLP Scheduling Engine for NotchDeck.
        Parse userUtterance relative to reference_datetime: "\(currentISO)".
        If time has already passed today without a specified date, rollover to tomorrow.
        Output ONLY valid raw JSON matching the schema.
        """

        let prompt = "User Utterance: \"\(userUtterance)\""

        let payload: [String: Any] = [
            "system_instruction": ["parts": [["text": systemInstruction]]],
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.0,
                "responseMimeType": "application/json"
            ]
        ]

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw AIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.httpError(statusCode: -1, message: "Non-HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8)
            throw AIClientError.httpError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        struct GeminiResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]?
        }

        do {
            let geminiRes = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let jsonString = geminiRes.candidates?.first?.content.parts.first?.text,
                  let jsonData = jsonString.data(using: .utf8) else {
                throw AIClientError.httpError(statusCode: httpResponse.statusCode, message: "Empty candidate payload")
            }
            return try JSONDecoder().decode(NLPScheduleResult.self, from: jsonData)
        } catch {
            throw AIClientError.decodingError(error.localizedDescription)
        }
    }
}
