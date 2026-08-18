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
    /// Falls back to 150pt if auxiliary areas are unavailable (older API or non-notch display).
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
        return 150  // documented fallback per NotchKit spec
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
        return hasPhysicalNotch ? defaultNotchHeight + 10.0 : 14.0
    }

    // MARK: - Dimensions (static fallback — no NSScreen required)

    /// Returns dimensions using static fallback values.
    /// Use `calculateFrame(for:screen:)` when a real screen is available for hardware accuracy.
    public static func dimensions(
        for state: NotchState,
        hasPhysicalNotch: Bool = false
    ) -> (width: CGFloat, height: CGFloat) {
        let notchH: CGFloat = hasPhysicalNotch ? defaultNotchHeight : 0
        // Fallback notch width used when no NSScreen is available
        let fallbackNotchW: CGFloat = hasPhysicalNotch ? 150 : 0

        switch state {
        case .hidden:
            return (0, 0)
        case .collapsed:
            // Collapsed pill aligns to hardware notch area + small wings
            let w: CGFloat = hasPhysicalNotch ? fallbackNotchW + 180 : 160
            let h: CGFloat = hasPhysicalNotch ? defaultNotchHeight : 32
            return (w, h)
        case .voiceActive:
            return (360, 60 + notchH)
        case .liveActivity:
            return (320, 44 + notchH)
        case .expanded:
            // Expanded = notchWidth + 2 * wingExtension per NotchKit spec
            let expandedW = fallbackNotchW + (2 * wingExtension)
            return (expandedW, 250 + notchH)
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
            // Collapsed: window spans notchWidth + wings on both sides
            // This makes the collapsed pill align exactly with the physical notch
            let wingW: CGFloat = hasNotch ? 90 : 0   // small wing per side
            let w = hasNotch ? notchW + (2 * wingW) : 160
            let h = hasNotch ? notchH : 32
            let x = screenFrame.midX - (w / 2.0)
            let y = hasNotch ? screenFrame.maxY - h : screenFrame.maxY - h - 10
            return NSRect(x: x, y: y, width: w, height: h)

        case .voiceActive:
            let w: CGFloat = 360
            let h: CGFloat = 60 + notchH
            return NSRect(x: screenFrame.midX - (w / 2.0), y: screenFrame.maxY - h, width: w, height: h)

        case .liveActivity:
            let w: CGFloat = 320
            let h: CGFloat = 44 + notchH
            return NSRect(x: screenFrame.midX - (w / 2.0), y: screenFrame.maxY - h, width: w, height: h)

        case .expanded:
            // Expanded = notchWidth + 2 * wingExtension, capped to screen width - 48
            let rawW = hasNotch ? notchW + (2 * wingExtension) : 480
            let w = min(rawW, screenFrame.width - 48)
            let h: CGFloat = 250 + notchH
            return NSRect(x: screenFrame.midX - (w / 2.0), y: screenFrame.maxY - h, width: w, height: h)
        }
    }

    /// Compatibility overload for call-sites that only have screenFrame + hasPhysicalNotch.
    /// Used by unit tests and legacy code paths.
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
