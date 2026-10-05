import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation

@main
struct CanvasSelectionProbe {
    static func main() async {
        print("=================================================================")
        print("🔍 EMPIRICAL PROBE: TradingView Canvas Selection & Cmd+C Behavior")
        print("=================================================================")

        let apps = NSWorkspace.shared.runningApplications.filter { $0.localizedName == "TradingView" }
        guard let tv = apps.first else {
            print("❌ TradingView is not running!")
            exit(1)
        }
        tv.activate()
        try? await Task.sleep(nanoseconds: 400_000_000)

        let pasteboard = NSPasteboard.general
        let sentinelToken = "SENTINEL_PROBE_\(UUID().uuidString.prefix(8))"

        // 1. Seed sentinel to clipboard
        pasteboard.clearContents()
        pasteboard.setString(sentinelToken, forType: .string)
        print("1. Seeded sentinel to clipboard: \(sentinelToken)")
        print("   Current pasteboard types: \(pasteboard.types?.map { $0.rawValue } ?? [])")

        // 2. Click safe canvas area to ensure canvas has focus
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]],
              let tvInfo = infoList.first(where: {
                  let owner = $0[kCGWindowOwnerName as String] as? String ?? ""
                  let name = $0[kCGWindowName as String] as? String ?? ""
                  return owner.contains("TradingView") && (name.contains("ASTER") || name.contains("Chart") || name.contains("Unnamed") || name.contains("BTC"))
              }),
              let boundsDict = tvInfo[kCGWindowBounds as String] as? [String: Any],
              let winX = boundsDict["X"] as? CGFloat,
              let winY = boundsDict["Y"] as? CGFloat,
              let winW = boundsDict["Width"] as? CGFloat,
              let winH = boundsDict["Height"] as? CGFloat else {
            print("❌ TradingView window bounds not found!")
            exit(1)
        }

        let canvasClickPt = CGPoint(x: winX + winW * 0.35, y: winY + 200)
        print("2. Clicking canvas at: \(canvasClickPt)")
        let src = CGEventSource(stateID: .hidSystemState)
        let move = CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: canvasClickPt, mouseButton: .left)
        let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: canvasClickPt, mouseButton: .left)
        let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: canvasClickPt, mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // 3. Synthesize Cmd+A on canvas
        print("3. Sending Cmd+A on canvas...")
        let cmdA_down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: true)
        cmdA_down?.flags = [.maskCommand]
        let cmdA_up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: false)
        cmdA_up?.flags = [.maskCommand]
        cmdA_down?.post(tap: .cghidEventTap)
        cmdA_up?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 200_000_000)

        // 4. Synthesize Cmd+C on canvas
        print("4. Sending Cmd+C on canvas...")
        let cmdC_down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        cmdC_down?.flags = [.maskCommand]
        let cmdC_up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        cmdC_up?.flags = [.maskCommand]
        cmdC_down?.post(tap: .cghidEventTap)
        cmdC_up?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // 5. Inspect clipboard
        let afterTypes = pasteboard.types?.map { $0.rawValue } ?? []
        let afterString = pasteboard.string(forType: .string) ?? "<nil>"
        print("5. After Cmd+A -> Cmd+C on canvas:")
        print("   Clipboard types: \(afterTypes)")
        print("   Clipboard string: \"\(afterString.prefix(200))\" (length: \(afterString.count))")

        if afterString == sentinelToken {
            print("   👉 RESULT: Sentinel UNCHANGED! Cmd+C on canvas with no text field did NOT overwrite clipboard string.")
        } else {
            print("   👉 RESULT: Sentinel WAS OVERWRITTEN! Canvas copied data:")
            print("   Full payload preview: \(afterString.prefix(500))")
        }

        // Clean up: Press Escape twice to unselect any selected drawing
        let escD = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Escape), keyDown: true)
        let escU = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Escape), keyDown: false)
        escD?.post(tap: .cghidEventTap)
        escU?.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 100_000_000)
        escD?.post(tap: .cghidEventTap)
        escU?.post(tap: .cghidEventTap)
        print("6. Sent Escape x2 to clear canvas selection.")
        print("=================================================================")
    }
}
