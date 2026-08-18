import Foundation
import AppKit

public struct NotchGeometryCalculator: Sendable {
    /// Default notch height used as fallback when `safeAreaInsets` cannot be read.
    public static let defaultNotchHeight: CGFloat = 36.0

    /// Wing extension on each side of the notch for expanded state.
    /// Per NotchKit reference: expandedWidth = notchWidth + 2 * wingExtension
    public static let wingExtension: CGFloat = 180

    // MARK: - Hardware Notch Metrics

    /// Returns the physical notch width (camera region only) by reading auxiliary screen areas.
    /// Falls back to 160pt if auxiliary areas are unavailable (older API or non-notch display).
    @MainActor
    public static func notchWidth(for screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            let leftWidth  = screen.auxiliaryTopLeftArea?.width  ?? 0
            let rightWidth = screen.auxiliaryTopRightArea?.width ?? 0
            let notch = screen.frame.width - leftWidth - rightWidth
            // Sanity check: real MacBook notches are approx 100–230pt wide
            if notch > 80 && notch < 300 {
                return notch
            }
        }
        return 160  // documented fallback per NotchKit spec
    }

    /// Returns the physical notch height from safeAreaInsets.top.
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
        return hasPhysicalNotch ? defaultNotchHeight + 22.0 : 18.0
    }

    // MARK: - Dimensions (static fallback — no NSScreen required)

    /// Returns dimensions using static fallback values.
    /// Use `calculateFrame(for:screen:)` when a real screen is available for hardware accuracy.
    public static func dimensions(
        for state: NotchState,
        hasPhysicalNotch: Bool = false
    ) -> (width: CGFloat, height: CGFloat) {
        let notchH: CGFloat = hasPhysicalNotch ? defaultNotchHeight : 0
        let fallbackNotchW: CGFloat = hasPhysicalNotch ? 160 : 0

        switch state {
        case .hidden:
            return (0, 0)
        case .collapsed:
            // Collapsed pill aligns to hardware notch area + wings (115pt each side)
            let w: CGFloat = hasPhysicalNotch ? fallbackNotchW + 230 : 160
            let h: CGFloat = hasPhysicalNotch ? defaultNotchHeight : 32
            return (w, h)
        case .voiceActive:
            return (400, 64 + notchH)
        case .liveActivity:
            return (360, 48 + notchH)
        case .expanded:
            let expandedW = hasPhysicalNotch ? max(620, fallbackNotchW + 420) : 580
            return (expandedW, 400 + notchH)
        }
    }

    // MARK: - Frame Calculation (preferred — uses actual NSScreen)

    /// Calculates the precise window frame using hardware notch metrics from NSScreen.
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
        let notchW   = hasNotch ? notchWidth(for: screen)  : 0
        let notchH   = hasNotch ? notchHeight(for: screen) : 0

        switch state {
        case .hidden:
            return NSRect(x: screenFrame.midX, y: screenFrame.maxY, width: 0, height: 0)

        case .collapsed:
            // Collapsed: window spans notchWidth + wings on both sides (115pt wing each side)
            let wingW: CGFloat = hasNotch ? 115 : 0
            let w = hasNotch ? notchW + (2 * wingW) : 160
            let h = hasNotch ? notchH : 32
            let x = screenFrame.midX - (w / 2.0)
            let y = hasNotch ? screenFrame.maxY - h : screenFrame.maxY - h - 10
            return NSRect(x: x, y: y, width: w, height: h)

        case .voiceActive:
            let w: CGFloat = 400
            let h: CGFloat = 64 + notchH
            return NSRect(x: screenFrame.midX - (w / 2.0), y: screenFrame.maxY - h, width: w, height: h)

        case .liveActivity:
            let w: CGFloat = 360
            let h: CGFloat = 48 + notchH
            return NSRect(x: screenFrame.midX - (w / 2.0), y: screenFrame.maxY - h, width: w, height: h)

        case .expanded:
            // Expanded: width and height have ample room for all components comfortably
            let rawW = hasNotch ? max(620, notchW + 420) : 580
            let w = min(rawW, screenFrame.width - 48)
            let h: CGFloat = 400 + notchH
            return NSRect(x: screenFrame.midX - (w / 2.0), y: screenFrame.maxY - h, width: w, height: h)
        }
    }

    /// Compatibility overload for call-sites that only have screenFrame + hasPhysicalNotch.
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
