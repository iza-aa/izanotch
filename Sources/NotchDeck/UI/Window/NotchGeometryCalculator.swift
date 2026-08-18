import Foundation
import AppKit

public struct NotchGeometryCalculator: Sendable {
    public static let defaultNotchHeight: CGFloat = 36.0

    public static func contentTopInset(hasPhysicalNotch: Bool) -> CGFloat {
        return hasPhysicalNotch ? defaultNotchHeight + 10.0 : 14.0
    }

    public static func dimensions(for state: NotchState, hasPhysicalNotch: Bool = false) -> (width: CGFloat, height: CGFloat) {
        let notchOffset: CGFloat = hasPhysicalNotch ? defaultNotchHeight : 0

        switch state {
        case .hidden:
            return (0, 0)
        case .collapsed:
            return (hasPhysicalNotch ? 200 : 160, hasPhysicalNotch ? 36 : 32)
        case .voiceActive:
            return (360, 60 + notchOffset)
        case .liveActivity:
            return (320, 44 + notchOffset)
        case .expanded:
            return (560, 250 + notchOffset)
        }
    }

    public static func calculateFrame(
        for state: NotchState,
        screenFrame: NSRect,
        hasPhysicalNotch: Bool
    ) -> NSRect {
        if state == .hidden {
            return NSRect(x: screenFrame.midX, y: screenFrame.maxY, width: 0, height: 0)
        }

        let (width, height) = dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch)
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
