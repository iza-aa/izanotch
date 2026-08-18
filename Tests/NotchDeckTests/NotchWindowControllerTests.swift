import Testing
import AppKit
@testable import NotchDeck

@Suite("Notch Window Controller Tests")
struct NotchWindowControllerTests {
    @Test("Window Controller initializes panel with correct style and levels")
    @MainActor
    func testWindowControllerSetup() {
        let stateController = NotchStateController()
        let windowController = NotchWindowController(stateController: stateController)
        
        guard let panel = windowController.window as? NotchPanel else {
            #expect(Bool(false), "Window should be an instance of NotchPanel")
            return
        }

        #expect(panel.level.rawValue > Int(CGWindowLevelForKey(.normalWindow)))
        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == NSColor.clear)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }
}
