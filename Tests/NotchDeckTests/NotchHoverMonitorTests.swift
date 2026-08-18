import Testing
import Foundation
@testable import NotchDeck

@Suite("Notch Hover Monitor Tests")
struct NotchHoverMonitorTests {
    @Test("Hover enter triggers expansion after debounce delay")
    @MainActor
    func testHoverEnterDebounce() async throws {
        let stateController = NotchStateController()
        let monitor = NotchHoverMonitor(
            stateController: stateController,
            enterDebounceDuration: 0.05,
            exitDebounceDuration: 0.05
        )
        
        #expect(stateController.currentState == .collapsed)

        monitor.mouseEntered()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms (not yet debounced)
        #expect(stateController.currentState == .collapsed)

        try await Task.sleep(nanoseconds: 60_000_000) // 60ms (passed 50ms debounce)
        #expect(stateController.currentState == .expanded)
        
        monitor.mouseExited()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms (not yet collapsed)
        #expect(stateController.currentState == .expanded)

        try await Task.sleep(nanoseconds: 60_000_000) // 60ms (passed 50ms exit debounce)
        #expect(stateController.currentState == .collapsed)
    }

    @Test("Hover re-entry cancels pending collapse task")
    @MainActor
    func testHoverReEntryCancelsExit() async throws {
        let stateController = NotchStateController()
        let monitor = NotchHoverMonitor(
            stateController: stateController,
            enterDebounceDuration: 0.02,
            exitDebounceDuration: 0.08
        )

        stateController.transition(to: .expanded)
        #expect(stateController.currentState == .expanded)

        monitor.mouseExited()
        try await Task.sleep(nanoseconds: 20_000_000) // 20ms (exit pending)

        // Mouse re-enters before exit debounce fires
        monitor.mouseEntered()
        try await Task.sleep(nanoseconds: 90_000_000) // 90ms

        // Should still be expanded, NOT collapsed!
        #expect(stateController.currentState == .expanded)
    }
}
