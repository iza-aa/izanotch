import Testing
import Foundation
@testable import NotchDeck

@Suite("Antigravity Coordinator Tests")
struct AntigravityCoordinatorTests {
    @Test("Read recent transcript from mock directory")
    func testReadRecentTranscript() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sampleTranscript = "{\"step_index\":1,\"type\":\"MODEL_OUTPUT\",\"content\":\"Test Response\"}\n"
        let logFile = tempDir.appendingPathComponent("transcript.jsonl")
        try sampleTranscript.write(to: logFile, atomically: true, encoding: .utf8)

        let result = AntigravityCoordinator.observeRecentTranscript(brainDir: tempDir)
        #expect(result?.contains("Test Response") == true)

        try? FileManager.default.removeItem(at: tempDir)
    }
}
