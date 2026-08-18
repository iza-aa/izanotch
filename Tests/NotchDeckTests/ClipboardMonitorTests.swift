import Testing
import AppKit
@testable import NotchDeck

@Suite("Clipboard Monitor Tests")
struct ClipboardMonitorTests {
    @Test("ClipboardMonitor copies text and clears clipboard")
    @MainActor
    func testClipboardCopyAndClear() {
        let monitor = ClipboardMonitor.shared
        let testString = "NotchDeck Secret Key: sk-proj-1234567890abcdef1234567890"

        monitor.copyToClipboard(testString)
        let readString = NSPasteboard.general.string(forType: .string)
        #expect(readString == testString)

        monitor.clearClipboard()
        let clearedString = NSPasteboard.general.string(forType: .string)
        #expect(clearedString == nil || clearedString?.isEmpty == true)
    }
}
