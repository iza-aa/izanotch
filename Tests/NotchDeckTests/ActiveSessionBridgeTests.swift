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

    @Test("Send clarification response to file handle")
    func testSendClarificationResponse() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let logDir = tempDir.appendingPathComponent(".system_generated/logs")
        try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logFile = logDir.appendingPathComponent("transcript.jsonl")
        try "{}".write(to: logFile, atomically: true, encoding: .utf8)

        let bridge = ActiveSessionBridge()
        try await bridge.sendClarificationResponse("Option A Chosen", sessionDirectory: tempDir)

        let updatedContent = try String(contentsOf: logFile)
        #expect(updatedContent.contains("Option A Chosen"))
        #expect(updatedContent.contains("USER_INPUT"))

        try? FileManager.default.removeItem(at: tempDir)
    }
}
