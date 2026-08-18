import Testing
import Foundation
@testable import NotchDeck

@Suite("Active Session Bridge Tests")
struct ActiveSessionBridgeTests {
    @Test("Dispatch interactive prompt and verify non-zero exit code throws error")
    func testDispatchInteractivePromptErrorOnFailure() async throws {
        let bridge = ActiveSessionBridge()
        let acc = OutputAccumulator()

        do {
            _ = try await bridge.dispatchPromptInteractive(
                executable: "/bin/sh",
                arguments: ["-c", "exit 42"],
                initialPrompt: "test"
            ) { chunk in
                acc.append(chunk)
            }
            #expect(Bool(false), "Should have thrown error on exit code 42")
        } catch let err as AIClientError {
            switch err {
            case .httpError(let code, _):
                #expect(code == 42)
            default:
                #expect(Bool(false), "Expected httpError with code 42")
            }
        }
    }

    @Test("Send clarification response with complex quotes, newlines, and special characters produces valid JSONL")
    func testSendClarificationResponseWithSpecialChars() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let logDir = tempDir.appendingPathComponent(".system_generated/logs")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logFile = logDir.appendingPathComponent("transcript.jsonl")
        try "{}".write(to: logFile, atomically: true, encoding: .utf8)

        let bridge = ActiveSessionBridge()
        let complexResponse = "Option \"A\" with \n newline and backslash \\ and emojis 🚀 and payload: {\"hack\": true}"
        try await bridge.sendClarificationResponse(complexResponse, sessionDirectory: tempDir)

        let updatedContent = try String(contentsOf: logFile)
        let lines = updatedContent.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        // Assert the appended line is strictly valid JSON
        guard let lastLine = lines.last, let data = lastLine.data(using: .utf8) else {
            #expect(Bool(false), "Expected last line in JSONL")
            return
        }

        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["type"] as? String == "USER_INPUT")
        #expect(parsed?["content"] as? String == complexResponse)

        try? FileManager.default.removeItem(at: tempDir)
    }
}
