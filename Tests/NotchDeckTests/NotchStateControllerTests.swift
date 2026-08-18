import Testing
@testable import NotchDeck

@Suite("Notch State Controller Tests")
struct NotchStateControllerTests {
    @Test("Initial state is collapsed and transitions smoothly")
    @MainActor
    func testStateTransitions() {
        let controller = NotchStateController()
        #expect(controller.currentState == .collapsed)

        controller.transition(to: .voiceActive)
        #expect(controller.currentState == .voiceActive)

        controller.transition(to: .expanded)
        #expect(controller.currentState == .expanded)
    }
}
