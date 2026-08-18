import Foundation
import AppKit

public struct NotchGeometryCalculator: Sendable {
    /// Default notch height used as fallback when `safeAreaInsets` cannot be read.
    public static let defaultNotchHeight: CGFloat = 36.0

    // MARK: - Hardware Notch Metrics

    /// Returns the physical notch width on the given screen by reading `auxiliaryTopLeftArea`
    /// and `auxiliaryTopRightArea`.  Falls back to `200` if the auxiliary areas are unavailable.
    @MainActor
    public static func notchWidth(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            let leftWidth  = screen.auxiliaryTopLeftArea?.width  ?? 0
            let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
            let notch = screen.frame.width - leftWidth - rightWidth
            if notch > 50 && notch < 500 {   // sanity check – real notches are 100-230 pt
                return notch
            }
        }
        return 200   // safe fallback for older APIs or Rosetta
    }

    /// True inset: space between notch bottom and menu-bar bottom (i.e. how tall the notch is).
    @MainActor
    public static func notchHeight(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            let inset = screen.safeAreaInsets.top
            if inset > 0 { return inset }
        }
        return defaultNotchHeight
    }

    // MARK: - Content Insets

    public static func contentTopInset(hasPhysicalNotch: Bool) -> CGFloat {
        return hasPhysicalNotch ? defaultNotchHeight + 10.0 : 14.0
    }

    // MARK: - Dimensions

    /// Dimensions for a given state without access to an NSScreen (unit-test compatible).
    /// Uses static fallback values.  Prefer `dimensions(for:screen:)` when a real screen is available.
    public static func dimensions(
        for state: NotchState,
        hasPhysicalNotch: Bool = false
    ) -> (width: CGFloat, height: CGFloat) {
        let notchH: CGFloat = hasPhysicalNotch ? defaultNotchHeight : 0

        switch state {
        case .hidden:
            return (0, 0)
        case .collapsed:
            // Collapsed pill sits exactly over the notch area
            return (hasPhysicalNotch ? 200 : 160, hasPhysicalNotch ? 36 : 32)
        case .voiceActive:
            return (360, 60 + notchH)
        case .liveActivity:
            return (320, 44 + notchH)
        case .expanded:
            // Expanded uses a generous width so content has room; never wider than screen
            return (480, 250 + notchH)
        }
    }

    // MARK: - Frame Calculation

    /// Preferred: calculates the correct window frame using actual screen data.
    @MainActor
    public static func calculateFrame(
        for state: NotchState,
        screen: NSScreen
    ) -> NSRect {
        let screenFrame = screen.frame
        if state == .hidden {
            return NSRect(x: screenFrame.midX, y: screenFrame.maxY, width: 0, height: 0)
        }

        let hasNotch = hasPhysicalNotch(screen: screen)
        let notchW   = hasNotch ? notchWidth(for: screen)  : 160
        let notchH   = hasNotch ? notchHeight(for: screen) : 0

        switch state {
        case .hidden:
            return NSRect(x: screenFrame.midX, y: screenFrame.maxY, width: 0, height: 0)

        case .collapsed:
            // Collapsed window must sit exactly over the hardware notch
            let w = hasNotch ? notchW : 160
            let h = hasNotch ? notchH : 32
            let x = screenFrame.midX - (w / 2.0)
            let y = hasNotch ? screenFrame.maxY - h : screenFrame.maxY - h - 10
            return NSRect(x: x, y: y, width: w, height: h)

        case .voiceActive:
            let w: CGFloat = 360
            let h: CGFloat = 60 + notchH
            return NSRect(
                x: screenFrame.midX - (w / 2.0),
                y: screenFrame.maxY - h,
                width: w, height: h
            )

        case .liveActivity:
            let w: CGFloat = 320
            let h: CGFloat = 44 + notchH
            return NSRect(
                x: screenFrame.midX - (w / 2.0),
                y: screenFrame.maxY - h,
                width: w, height: h
            )

        case .expanded:
            // Cap expanded width at min(480, screenFrame.width - 48) to avoid overflow
            let w = min(480, screenFrame.width - 48)
            let h: CGFloat = 250 + notchH
            return NSRect(
                x: screenFrame.midX - (w / 2.0),
                y: screenFrame.maxY - h,
                width: w, height: h
            )
        }
    }

    /// Compatibility overload for call-sites that only pass `screenFrame` + `hasPhysicalNotch`
    /// (used by unit tests and legacy code paths).
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

    // MARK: - Screen Detection

    public static func hasPhysicalNotch(screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0 || screen.auxiliaryTopLeftArea != nil
        }
        return false
    }
}
