import Foundation
import AppKit

public struct NotchGeometryCalculator: Sendable {
    public static func dimensions(for state: NotchState) -> (width: CGFloat, height: CGFloat) {
        switch state {
        case .collapsed: return (180, 32)
        case .voiceActive: return (360, 60)
        case .liveActivity: return (320, 44)
        case .expanded: return (540, 380)
        }
    }

    public static func calculateFrame(
        for state: NotchState,
        screenFrame: NSRect,
        hasPhysicalNotch: Bool
    ) -> NSRect {
        let (width, height) = dimensions(for: state)
        let originX = screenFrame.midX - (width / 2.0)
        let topOffset: CGFloat = hasPhysicalNotch ? 0 : 10.0
        let originY = screenFrame.maxY - height - topOffset

        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    public static func hasPhysicalNotch(screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0 || screen.auxiliaryTopLeftArea != nil
        }
        return false
    }
}
