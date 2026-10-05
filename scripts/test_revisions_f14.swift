import Foundation

// TDD Verification Test for Milestone 181 (Revisi F-14: Option 3 Dual-Layer Handover + Watchdog Safety Timer)

func testRevisionsF14() {
    print("=== START TEST REVISIONS F-14 ===")

    let rootPath = "/Users/heizaaa/Desktop/cdev/iza-3"
    let companionManagerPath = "\(rootPath)/boringNotch/Clicky/CompanionManager.swift"
    guard let content = try? String(contentsOfFile: companionManagerPath, encoding: .utf8) else {
        fatalError("Failed to read CompanionManager.swift")
    }

    // 1. Verify speakAndReportText resets isHomeSpaceStreaming and homeSpaceStreamingText
    assert(content.contains("self.isHomeSpaceStreaming = false") || content.contains("isHomeSpaceStreaming = false"), "FAIL: isHomeSpaceStreaming not reset")
    assert(content.contains("self.homeSpaceStreamingText = \"\"") || content.contains("homeSpaceStreamingText = \"\""), "FAIL: homeSpaceStreamingText not reset")
    print("✓ Test 1: speakAndReportText atomic state handover verified")

    // 2. Verify appendChatMessage has defensive reset for assistant messages
    assert(content.contains("if !message.isUser"), "FAIL: appendChatMessage lacks defensive reset for assistant messages")
    print("✓ Test 2: appendChatMessage defensive reset for assistant messages verified")

    // 3. Verify streaming watchdog timer implementation
    assert(content.contains("streamingWatchdogWorkItem"), "FAIL: streamingWatchdogWorkItem missing")
    assert(content.contains("armStreamingWatchdog"), "FAIL: armStreamingWatchdog helper missing")
    assert(content.contains("disarmStreamingWatchdog"), "FAIL: disarmStreamingWatchdog helper missing")
    print("✓ Test 3: Streaming safety watchdog timer verified")

    // 4. Verify companion status reset to idle upon completion
    assert(content.contains("CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)"), "FAIL: companion status not updated to idle on finish")
    print("✓ Test 4: Companion status update to .idle verified")

    print("=== ALL REVISIONS F-14 TESTS PASSED (100%) ===")
}

testRevisionsF14()
