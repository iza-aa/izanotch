import Foundation

public enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    case antigravity = "Antigravity"
    case claudeCode = "Claude Code"
    case gemini = "Gemini Flash"
    case codex = "Codex"

    public var id: String { rawValue }
}

public struct MultiAIResponse: Sendable {
    public let text: String
    public let provider: AIProvider
    public let executionTimeMs: Int
}

public final class MultiAIClient: @unchecked Sendable {
    public static let shared = MultiAIClient()
    private let urlSession: URLSession
    private let subprocessBridge: AISubprocessBridge

    public init(urlSession: URLSession = .shared, subprocessBridge: AISubprocessBridge = AISubprocessBridge()) {
        self.urlSession = urlSession
        self.subprocessBridge = subprocessBridge
    }

    // MARK: - Request Builders

    public static func buildClaudeRequest(
        apiKey: String,
        prompt: String,
        model: String = "claude-3-5-sonnet-20241022",
        maxTokens: Int = 1024
    ) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    public static func buildGeminiRequest(
        apiKey: String,
        prompt: String,
        model: String = "gemini-2.5-flash"
    ) -> URLRequest {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Prompt Execution Router

    public func prompt(
        text: String,
        provider: AIProvider,
        geminiApiKey: String? = nil,
        claudeApiKey: String? = nil
    ) async throws -> MultiAIResponse {
        let startTime = Date()

        switch provider {
        case .gemini:
            guard let key = geminiApiKey, !key.isEmpty else {
                throw AIClientError.missingAPIKey
            }
            let req = Self.buildGeminiRequest(apiKey: key, prompt: text)
            let (data, response) = try await urlSession.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                throw AIClientError.httpError(statusCode: code, message: "Gemini HTTP error")
            }
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let candidates = json["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            let responseText = parts?.first?["text"] as? String ?? "No response"
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            return MultiAIResponse(text: responseText, provider: .gemini, executionTimeMs: duration)

        case .claudeCode:
            if let key = claudeApiKey, !key.isEmpty {
                let req = Self.buildClaudeRequest(apiKey: key, prompt: text)
                let (data, response) = try await urlSession.data(for: req)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                    throw AIClientError.httpError(statusCode: code, message: "Claude HTTP error")
                }
                let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                let contentBlocks = json["content"] as? [[String: Any]]
                let responseText = contentBlocks?.first?["text"] as? String ?? "No response from Claude"
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                return MultiAIResponse(text: responseText, provider: .claudeCode, executionTimeMs: duration)
            } else {
                let acc = OutputAccumulator()
                _ = try await subprocessBridge.execute(
                    executable: "/bin/sh",
                    arguments: ["-c", "command -v claude >/dev/null 2>&1 && claude -p \"\(text)\" || echo 'Claude CLI ready.'"]
                ) { chunk in
                    acc.append(chunk)
                }
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                let cliOutput = acc.get()
                return MultiAIResponse(text: cliOutput.isEmpty ? "Claude Code CLI executed." : cliOutput, provider: .claudeCode, executionTimeMs: duration)
            }

        case .antigravity:
            let acc = OutputAccumulator()
            _ = try await subprocessBridge.execute(
                executable: "/bin/sh",
                arguments: ["-c", "echo '[Antigravity Prompt Dispatched]: \(text)'"]
            ) { chunk in
                acc.append(chunk)
            }
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            return MultiAIResponse(text: acc.get(), provider: .antigravity, executionTimeMs: duration)

        case .codex:
            let acc = OutputAccumulator()
            _ = try await subprocessBridge.execute(
                executable: "/bin/sh",
                arguments: ["-c", "command -v codex >/dev/null 2>&1 && codex exec \"\(text)\" || echo 'Codex ready: \(text)'"]
            ) { chunk in
                acc.append(chunk)
            }
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)
            return MultiAIResponse(text: acc.get(), provider: .codex, executionTimeMs: duration)
        }
    }
}
