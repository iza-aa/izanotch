import ClickyFoundation
//
//  GeminiBridgeClient.swift
//  izaNotch
//
//  Google Gemini Bridge Client communicating with local Antigravity Bridge / Gemini API.
//  Replaces legacy ClaudeAPI without third-party vendor baggage.
//

import AppKit
import Defaults
import Foundation

public final class GeminiBridgeClient {
    @MainActor public static var bridgeProvider: AntigravityBridgeManaging?

    private let apiURL: URL
    public var model: String
    private let session: URLSession

    public init(proxyURL: String? = nil, model: String? = nil) {
        let bridgePort = Defaults[.antigravityBridgePort] > 0 ? Defaults[.antigravityBridgePort] : 8080
        let defaultURL = URL(string: "http://127.0.0.1:\(bridgePort)/v1/messages")!
        if let proxyURL = proxyURL, !proxyURL.contains("your-worker-name"), let validURL = URL(string: proxyURL) {
            self.apiURL = validURL
        } else {
            self.apiURL = defaultURL
        }
        self.model = model ?? Defaults[.selectedAIModel]

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.urlCache = nil
        config.httpCookieStorage = nil
        self.session = URLSession(configuration: config)
    }

    private func makeAPIRequest() throws -> URLRequest {
        let bridgePort = Defaults[.antigravityBridgePort] > 0 ? Defaults[.antigravityBridgePort] : 8080
        let geminiDirectKey = Defaults[.geminiApiKey].trimmingCharacters(in: .whitespacesAndNewlines)

        let targetURL = apiURL.host == "127.0.0.1" || apiURL.host == "localhost"
            ? URL(string: "http://127.0.0.1:\(bridgePort)/v1/messages")!
            : apiURL

        var request = URLRequest(url: targetURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(!geminiDirectKey.isEmpty ? geminiDirectKey : "antigravity", forHTTPHeaderField: "x-api-key")

        return request
    }

    private func detectImageMediaType(for imageData: Data) -> String {
        if imageData.count >= 4 {
            let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
            let firstFourBytes = [UInt8](imageData.prefix(4))
            if firstFourBytes == pngSignature {
                return "image/png"
            }
        }
        return "image/jpeg"
    }

    /// Primary streaming execution for Gemini chat with tool calls support.
    public func analyzeMessagesWithToolsStreaming(
        messages: [[String: Any]],
        systemPrompt: String,
        tools: [[String: Any]] = [],
        maxTokens: Int = 1024,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> ModelTurnResult {
        let startTime = Date()
        var request = try makeAPIRequest()

        if request.url?.host == "127.0.0.1" {
            await MainActor.run {
                if let bridge = Self.bridgeProvider, !bridge.isRunning {
                    Task {
                        await bridge.startBridge()
                    }
                }
            }
        }

        let savedModel = Defaults[.selectedAIModel]
        let effectiveModel = savedModel.isEmpty ? "gemini-3.8-flash" : savedModel

        var body: [String: Any] = [
            "model": effectiveModel,
            "max_tokens": maxTokens,
            "stream": true,
            "system": systemPrompt,
            "messages": messages
        ]
        if !tools.isEmpty {
            body["tools"] = tools
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (byteStream, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiBridgeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorBodyChunks: [String] = []
            for try await line in byteStream.lines {
                errorBodyChunks.append(line)
            }
            let errorBody = errorBodyChunks.joined(separator: "\n")
            throw NSError(
                domain: "GeminiBridgeClient",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Gemini Bridge Error (\(httpResponse.statusCode)): \(errorBody)"]
            )
        }

        var accumulatedResponseText = ""
        var toolCalls: [ModelToolCall] = []
        var activeToolIndex: Int? = nil
        var activeToolId: String = ""
        var activeToolName: String = ""
        var activeToolJson: String = ""
        var stopReason: String? = nil

        for try await line in byteStream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard jsonString != "[DONE]" else { break }

            guard let jsonData = jsonString.data(using: .utf8),
                  let eventPayload = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let eventType = eventPayload["type"] as? String else {
                continue
            }

            switch eventType {
            case "content_block_start":
                if let block = eventPayload["content_block"] as? [String: Any],
                   let blockType = block["type"] as? String,
                   blockType == "tool_use" {
                    activeToolIndex = eventPayload["index"] as? Int
                    activeToolId = block["id"] as? String ?? "call_\(UUID().uuidString)"
                    activeToolName = block["name"] as? String ?? ""
                    activeToolJson = ""
                }
            case "content_block_delta":
                if let delta = eventPayload["delta"] as? [String: Any],
                   let deltaType = delta["type"] as? String {
                    if deltaType == "text_delta", let textChunk = delta["text"] as? String {
                        accumulatedResponseText += textChunk
                        await onTextChunk(textChunk)
                    } else if deltaType == "input_json_delta", let partial = delta["partial_json"] as? String {
                        activeToolJson += partial
                    }
                }
            case "content_block_stop":
                let stoppedIndex = eventPayload["index"] as? Int
                if (stoppedIndex == nil || stoppedIndex == activeToolIndex) && !activeToolName.isEmpty {
                    var argsDict: [String: Any] = [:]
                    if let argData = activeToolJson.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: argData) as? [String: Any] {
                        argsDict = parsed
                    }
                    toolCalls.append(ModelToolCall(id: activeToolId, name: activeToolName, arguments: argsDict))
                    activeToolIndex = nil
                    activeToolId = ""
                    activeToolName = ""
                    activeToolJson = ""
                }
            case "message_delta":
                if let delta = eventPayload["delta"] as? [String: Any] {
                    stopReason = delta["stop_reason"] as? String
                }
            case "error":
                if let errorDict = eventPayload["error"] as? [String: Any],
                   let errorMsg = errorDict["message"] as? String {
                    ClickyLogger.error("[GEMINI_CLIENT]", "Stream error received: \(errorMsg)")
                    throw NSError(domain: "GeminiBridgeClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
            default:
                break
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return ModelTurnResult(
            text: accumulatedResponseText,
            toolCalls: toolCalls,
            stopReason: stopReason,
            duration: duration
        )
    }

    /// Vision/image streaming execution for multimodal analysis.
    public func analyzeImageStreaming(
        images: [(data: Data, label: String)],
        systemPrompt: String,
        conversationHistory: [(userPlaceholder: String, assistantResponse: String)] = [],
        userPrompt: String,
        onTextChunk: @MainActor @Sendable (String) -> Void
    ) async throws -> (text: String, duration: TimeInterval) {
        let startTime = Date()
        var request = try makeAPIRequest()

        if request.url?.host == "127.0.0.1" {
            await MainActor.run {
                if let bridge = Self.bridgeProvider, !bridge.isRunning {
                    Task {
                        await bridge.startBridge()
                    }
                }
            }
        }

        let savedModel = Defaults[.selectedAIModel]
        let effectiveModel = savedModel.isEmpty ? "gemini-3.8-flash" : savedModel

        var contentBlocks: [[String: Any]] = []
        for image in images {
            let mediaType = detectImageMediaType(for: image.data)
            let base64String = image.data.base64EncodedString()
            contentBlocks.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": mediaType,
                    "data": base64String
                ]
            ])
        }

        contentBlocks.append([
            "type": "text",
            "text": userPrompt
        ])

        var messagesPayload: [[String: Any]] = []
        for turn in conversationHistory {
            messagesPayload.append(["role": "user", "content": turn.userPlaceholder])
            messagesPayload.append(["role": "assistant", "content": turn.assistantResponse])
        }
        messagesPayload.append(["role": "user", "content": contentBlocks])

        let body: [String: Any] = [
            "model": effectiveModel,
            "max_tokens": 1024,
            "stream": true,
            "system": systemPrompt,
            "messages": messagesPayload
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (byteStream, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "GeminiBridgeClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini HTTP response"])
        }

        var accumulatedText = ""
        for try await line in byteStream.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard jsonString != "[DONE]" else { break }

            guard let jsonData = jsonString.data(using: .utf8),
                  let eventPayload = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let eventType = eventPayload["type"] as? String else {
                continue
            }

            if eventType == "content_block_delta",
               let delta = eventPayload["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let textChunk = delta["text"] as? String {
                accumulatedText += textChunk
                await onTextChunk(textChunk)
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return (text: accumulatedText, duration: duration)
    }
}

// MARK: - Compatibility Typealias
public typealias ClaudeAPI = GeminiBridgeClient
