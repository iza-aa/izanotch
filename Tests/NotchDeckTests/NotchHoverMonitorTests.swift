import Testing
import Foundation
@testable import NotchDeck

@Suite("Notch Hover Monitor Tests")
struct NotchHoverMonitorTests {
    @Test("Hover enter triggers expansion after debounce delay")
    @MainActor
    func testHoverEnterDebounce() async throws {
        let stateController = NotchStateController()
        let monitor = NotchHoverMonitor(stateController: stateController, debounceDuration: 0.05)
        
        #expect(stateController.currentState == .collapsed)

        monitor.mouseEntered()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms (not yet debounced)
        #expect(stateController.currentState == .collapsed)

        try await Task.sleep(nanoseconds: 60_000_000) // 60ms (passed 50ms debounce)
        #expect(stateController.currentState == .expanded)
        
        monitor.mouseExited()
        #expect(stateController.currentState == .collapsed)
    }
}
