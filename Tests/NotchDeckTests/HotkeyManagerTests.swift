import Testing
import AppKit
@testable import NotchDeck

@Suite("Hotkey Manager Tests")
struct HotkeyManagerTests {
    @Test("Resolve Hotkey action correctly")
    func testHotkeyActions() {
        let toggleAction = HotkeyManager.resolveAction(keyCode: 49, flags: [.command, .shift]) // Cmd + Shift + Space
        #expect(toggleAction == .toggleExpand)

        let pushToTalkAction = HotkeyManager.resolveAction(keyCode: 49, flags: [.option]) // Option + Space
        #expect(pushToTalkAction == .pushToTalk)

        let escapeAction = HotkeyManager.resolveAction(keyCode: 53, flags: []) // Escape
        #expect(escapeAction == .dismiss)
    }
}
