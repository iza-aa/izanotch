import ClickyFoundation
//
//  ChatGPTCodexVisionService.swift
//  boringNotch
//
//  Headless Vision Service powered by OpenAI Codex CLI & 6 Luna Medium (gpt-6-luna)
//  Executes vision coordinate extraction in background with zero GUI popups.
//

import Foundation

public struct VisionCoordinateResult: Codable {
    public let target: String
    public let x: Int
    public let y: Int
    public let confidence: Double
    
    public init(target: String, x: Int, y: Int, confidence: Double = 1.0) {
        self.target = target
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

public enum VisionServiceError: LocalizedError {
    case binaryNotFound(String)
    case executionFailed(String)
    case outputNotFound(String)
    case parsingFailed(String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let path):
            return "ChatGPT Codex binary not found at: \(path)"
        case .executionFailed(let reason):
            return "Codex execution failed: \(reason)"
        case .outputNotFound(let path):
            return "Expected output file not found at: \(path)"
        case .parsingFailed(let reason):
            return "Failed to parse vision coordinate JSON: \(reason)"
        case .timeout:
            return "Vision inference timed out after 15 seconds"
        }
    }
}

@MainActor
public final class ChatGPTCodexVisionService: ObservableObject {
    public static let shared = ChatGPTCodexVisionService()
    
    public static let codexBinaryPath = "/Applications/ChatGPT.app/Contents/Resources/codex"
    public static let defaultModel = "gpt-6-luna"
    public static let defaultReasoningEffort = "medium"
    
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var lastQueryTarget: String = ""
    @Published public private(set) var lastResult: VisionCoordinateResult?
    @Published public private(set) var lastExecutionDuration: TimeInterval = 0
    
    private init() {}
    
    /// Queries coordinates for a given UI target element within an image using 6 Luna Medium.
    /// - Parameters:
    ///   - imagePath: Absolute path to the captured screen/window snapshot PNG.
    ///   - targetElementPrompt: Natural language description of the element to locate (e.g. "Send button", "Search field").
    ///   - codexHome: Optional custom CODEX_HOME path for isolated multi-account failover.
    /// - Returns: Parsed `VisionCoordinateResult` with absolute X, Y coordinates.
    public func queryCoordinates(
        imagePath: String,
        targetElementPrompt: String,
        codexHome: String? = nil
    ) async throws -> VisionCoordinateResult {
        do {
            return try await executeProcessQuery(
                imagePath: imagePath,
                targetElementPrompt: targetElementPrompt,
                codexHome: codexHome
            )
        } catch VisionServiceError.executionFailed(let err) where codexHome != nil && (err.contains("401") || err.contains("token") || err.contains("refresh")) {
            ClickyLogger.warning("[CODEX_VISION]", "Pool session token error, failing over to system ~/.codex session: \(err)")
            return try await executeProcessQuery(
                imagePath: imagePath,
                targetElementPrompt: targetElementPrompt,
                codexHome: nil
            )
        }
    }

    private func executeProcessQuery(
        imagePath: String,
        targetElementPrompt: String,
        codexHome: String? = nil
    ) async throws -> VisionCoordinateResult {
        guard FileManager.default.fileExists(atPath: Self.codexBinaryPath) else {
            throw VisionServiceError.binaryNotFound(Self.codexBinaryPath)
        }
        guard FileManager.default.fileExists(atPath: imagePath) else {
            throw VisionServiceError.outputNotFound("Input image not found at: \(imagePath)")
        }
        
        isProcessing = true
        lastQueryTarget = targetElementPrompt
        let startTime = Date()
        
        defer {
            isProcessing = false
            lastExecutionDuration = Date().timeIntervalSince(startTime)
        }
        
        // Structured prompt requesting strict JSON coordinate output
        let stdinPrompt = """
        You are a high-precision computer vision locator for macOS UI elements.
        Locate the exact center coordinates of the requested target element in the provided image.
        Target element: "\(targetElementPrompt)"
        
        Respond with ONLY a single raw JSON object (no markdown quotes, no backticks, no explanatory text):
        {"target":"\(targetElementPrompt)","x":<integer_x>,"y":<integer_y>,"confidence":<0.0_to_1.0>}
        """
        
        let tempOutputDir = NSTemporaryDirectory()
        let tempOutputFile = (tempOutputDir as NSString).appendingPathComponent("codex_vision_\(UUID().uuidString).json")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: Self.codexBinaryPath)
                
                // Headless non-interactive execution arguments
                process.arguments = [
                    "exec",
                    "--ephemeral",
                    "--skip-git-repo-check",
                    "-s", "read-only",
                    "-m", Self.defaultModel,
                    "-c", "reasoning_effort=medium",
                    "-i", imagePath,
                    "-o", tempOutputFile,
                    "-"
                ]
                
                // Inject custom CODEX_HOME if specified for multi-account pool routing
                var env = ProcessInfo.processInfo.environment
                if let codexHome = codexHome, !codexHome.isEmpty {
                    env["CODEX_HOME"] = codexHome
                }
                process.environment = env
                
                let stdinPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardInput = stdinPipe
                process.standardError = stderrPipe
                
                // Timeout watchdog timer
                let timeoutItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 15.0, execute: timeoutItem)
                
                do {
                    try process.run()
                    
                    if let promptData = stdinPrompt.data(using: .utf8) {
                        stdinPipe.fileHandleForWriting.write(promptData)
                    }
                    try? stdinPipe.fileHandleForWriting.close()
                    
                    process.waitUntilExit()
                    timeoutItem.cancel()
                    
                    let exitCode = process.terminationStatus
                    if exitCode != 0 {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errString = String(data: errData, encoding: .utf8) ?? "Exit code \(exitCode)"
                        continuation.resume(throwing: VisionServiceError.executionFailed(errString))
                        return
                    }
                    
                    guard FileManager.default.fileExists(atPath: tempOutputFile),
                          let outputData = try? Data(contentsOf: URL(fileURLWithPath: tempOutputFile)),
                          let outputString = String(data: outputData, encoding: .utf8) else {
                        continuation.resume(throwing: VisionServiceError.outputNotFound(tempOutputFile))
                        return
                    }
                    
                    // Clean up temp file
                    try? FileManager.default.removeItem(atPath: tempOutputFile)
                    
                    // Parse JSON output (sanitize markdown code blocks if any)
                    let sanitizedJson = Self.extractJsonPayload(from: outputString)
                    guard let sanitizedData = sanitizedJson.data(using: .utf8),
                          let parsed = try? JSONDecoder().decode(VisionCoordinateResult.self, from: sanitizedData) else {
                        continuation.resume(throwing: VisionServiceError.parsingFailed(outputString))
                        return
                    }
                    
                    Task { @MainActor in
                        Self.shared.lastResult = parsed
                    }
                    continuation.resume(returning: parsed)
                    
                } catch {
                    timeoutItem.cancel()
                    try? FileManager.default.removeItem(atPath: tempOutputFile)
                    continuation.resume(throwing: VisionServiceError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Sanitizes model responses that may contain wrapping backticks or whitespace.
    public static func extractJsonPayload(from rawString: String) -> String {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: "\n")
            let filtered = lines.filter { !$0.hasPrefix("```") }
            return filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let startIndex = trimmed.firstIndex(of: "{"),
           let endIndex = trimmed.lastIndex(of: "}") {
            return String(trimmed[startIndex...endIndex])
        }
        return trimmed
    }
}
