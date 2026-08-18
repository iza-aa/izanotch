import Testing
import Foundation
@testable import NotchDeck

@Suite("Notch Feature Navigation Tests")
struct NotchFeatureNavigationTests {
    @Test("NotchFeatureTab cases and icon bindings")
    func testFeatureTabCases() {
        let tabs = NotchFeatureTab.allCases
        #expect(tabs.count == 5)
        #expect(tabs.contains(.aiChat))
        #expect(tabs.contains(.notes))
        #expect(tabs.contains(.schedule))
        #expect(tabs.contains(.music))
        #expect(tabs.contains(.clipboard))

        #expect(NotchFeatureTab.aiChat.iconName == "bubble.left.and.bubble.right.fill")
        #expect(NotchFeatureTab.notes.iconName == "note.text")
        #expect(NotchFeatureTab.schedule.iconName == "calendar")
        #expect(NotchFeatureTab.music.iconName == "music.note")
        #expect(NotchFeatureTab.clipboard.iconName == "doc.on.clipboard")
    }

    @Test("StateController tab switching and chat message appending")
    @MainActor
    func testTabSwitchingAndChat() {
        let controller = NotchStateController()
        #expect(controller.activeTab == .aiChat)

        controller.selectTab(.notes)
        #expect(controller.activeTab == .notes)

        controller.selectTab(.music)
        #expect(controller.activeTab == .music)

        let initialCount = controller.chatMessages.count
        controller.appendChatMessage(sender: "User", text: "Test Message", isUser: true)
        #expect(controller.chatMessages.count == initialCount + 1)
        #expect(controller.chatMessages.last?.text == "Test Message")
        #expect(controller.chatMessages.last?.isUser == true)
    }

    @Test("Hidden state dimensions return zero frame")
    func testHiddenStateGeometry() {
        let dimensions = NotchGeometryCalculator.dimensions(for: .hidden, hasPhysicalNotch: true)
        #expect(dimensions.width == 0)
        #expect(dimensions.height == 0)

        let mockScreen = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(for: .hidden, screenFrame: mockScreen, hasPhysicalNotch: true)
        #expect(frame.width == 0)
        #expect(frame.height == 0)
    }
}
