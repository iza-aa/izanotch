import Testing
import Foundation
@testable import NotchDeck

@Suite("AI Subprocess Bridge Tests")
struct AISubprocessBridgeTests {
    @Test("Execute subprocess with stdout streaming and exit code verification")
    func testExecuteSubprocess() async throws {
        let bridge = AISubprocessBridge()
        let acc = OutputAccumulator()
        
        let exitCode = try await bridge.execute(
            executable: "/bin/sh",
            arguments: ["-c", "echo 'NotchDeck Bridge Active'"]
        ) { chunk in
            acc.append(chunk)
        }
        
        #expect(exitCode == 0)
        #expect(acc.get().contains("NotchDeck Bridge Active"))
    }

    @Test("Send stdin to running subprocess")
    func testStdinSubprocess() async throws {
        let bridge = AISubprocessBridge()
        let acc = OutputAccumulator()

        try bridge.startInteractive(
            executable: "/usr/bin/cat",
            arguments: []
        ) { chunk in
            acc.append(chunk)
        }

        try bridge.sendInput("Hello from NotchDeck\n")
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        bridge.closeInput()
        
        let exitCode = try await bridge.waitForExit()
        #expect(exitCode == 0)
        #expect(acc.get().contains("Hello from NotchDeck"))
    }

    @Test("Send input throws error when stdin is not available")
    func testSendInputThrowsWhenNotRunning() {
        let bridge = AISubprocessBridge()
        do {
            try bridge.sendInput("test")
            #expect(Bool(false), "Should have thrown stdinNotAvailable")
        } catch let err as AISubprocessError {
            switch err {
            case .stdinNotAvailable:
                #expect(Bool(true))
            default:
                #expect(Bool(false), "Expected stdinNotAvailable error")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type")
        }
    }
}
