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

    @Test("Codex live activity keeps the provider context")
    @MainActor
    func testCodexLiveActivityContext() {
        let controller = NotchStateController()

        controller.showLiveActivity(
            title: "Codex • Working",
            countdown: "Working",
            for: "Codex"
        )

        #expect(controller.currentState == .liveActivity(title: "Codex • Working", countdown: "Working"))
        #expect(controller.liveActivityModel == "Codex")
    }

    @Test("Compact status names the selected provider when idle")
    @MainActor
    func testProviderReadyStatus() {
        let controller = NotchStateController()
        controller.activeAIModel = "Codex"

        #expect(controller.compactProviderStatuses.count == 1)
        #expect(controller.compactProviderStatuses[0].compactLabel == "Codex Ready")

        controller.activeAIModel = "Antigravity"
        #expect(controller.compactProviderStatuses[0].compactLabel == "Antigravity Ready")
    }

    @Test("Compact status exposes all active providers for rotation")
    @MainActor
    func testMultipleActiveProviderStatuses() {
        let controller = NotchStateController()
        controller.setProviderStatus("Codex", status: "Working", isActive: true)
        controller.setProviderStatus("Antigravity", status: "Working", isActive: true)

        let labels = controller.compactProviderStatuses.map(\.compactLabel)
        #expect(labels == ["Codex Working", "Antigravity Working"])
    }
}
