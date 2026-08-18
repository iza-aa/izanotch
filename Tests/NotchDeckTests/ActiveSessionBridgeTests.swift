import Testing
import Foundation
@testable import NotchDeck

@Suite("Active Session Bridge Tests")
struct ActiveSessionBridgeTests {
    @Test("Multi-turn interactive session keeps stdin open and receives subsequent clarification replies")
    func testMultiTurnInteractiveSession() async throws {
        let bridge = ActiveSessionBridge()
        let acc = OutputAccumulator()

        // 1. Start interactive session with initial prompt
        try await bridge.startInteractiveSession(
            executable: "/usr/bin/cat",
            arguments: [],
            initialPrompt: "Turn 1: Initial Prompt"
        ) { chunk in
            acc.append(chunk)
        }

        #expect(await bridge.isInteractiveSessionActive == true)
        try await Task.sleep(nanoseconds: 30_000_000) // 30ms

        // 2. Send Turn 2 clarification reply while session is running
        try await bridge.sendClarificationResponse("Turn 2: Clarification Reply")
        try await Task.sleep(nanoseconds: 30_000_000)

        // 3. Close input and wait for clean exit
        await bridge.closeInteractiveInput()
        let exitCode = try await bridge.waitForInteractiveSessionExit()

        #expect(exitCode == 0)
        #expect(await bridge.isInteractiveSessionActive == false)

        let fullOutput = acc.get()
        #expect(fullOutput.contains("Turn 1: Initial Prompt"))
        #expect(fullOutput.contains("Turn 2: Clarification Reply"))
    }

    @Test("Dispatch interactive prompt and verify non-zero exit code throws error")
    func testDispatchInteractivePromptErrorOnFailure() async throws {
        let bridge = ActiveSessionBridge()
        let acc = OutputAccumulator()

        do {
            try await bridge.startInteractiveSession(
                executable: "/bin/sh",
                arguments: ["-c", "exit 42"],
                initialPrompt: "test"
            ) { chunk in
                acc.append(chunk)
            }
            _ = try await bridge.waitForInteractiveSessionExit()
            #expect(Bool(false), "Should have thrown error on exit code 42")
        } catch let err as ActiveSessionError {
            switch err {
            case .executionFailed(let code):
                #expect(code == 42)
            default:
                #expect(Bool(false), "Expected executionFailed with code 42, got \(err)")
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
        
        guard let lastLine = lines.last, let data = lastLine.data(using: .utf8) else {
            #expect(Bool(false), "Expected last line in JSONL")
            return
        }

        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed?["type"] as? String == "USER_INPUT")
        #expect(parsed?["content"] as? String == complexResponse)

        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test("Send clarification response throws error when neither session nor directory exists")
    func testSendClarificationThrowsWhenNoSession() async throws {
        let bridge = ActiveSessionBridge()
        do {
            try await bridge.sendClarificationResponse("Hello", sessionDirectory: nil)
            #expect(Bool(false), "Should have thrown sessionNotRunning error")
        } catch let err as ActiveSessionError {
            switch err {
            case .sessionNotRunning:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "Expected sessionNotRunning error")
            }
        }
    }
}
