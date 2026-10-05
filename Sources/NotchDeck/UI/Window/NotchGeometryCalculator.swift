import Foundation
import AppKit

public struct NotchGeometryCalculator: Sendable {
    /// Default notch height used as fallback when `safeAreaInsets` cannot be read.
    public static let defaultNotchHeight: CGFloat = 36.0

    /// Wing extension on each side of the notch for expanded state.
    /// Per NotchKit reference: expandedWidth = notchWidth + 2 * wingExtension
    public static let wingExtension: CGFloat = 180

    /// Width of each side wing in the connected standby notch surface.
    /// The physical camera notch occupies the center; status content uses the
    /// native menu-bar space on both sides of it.
    public static let collapsedStatusWidth: CGFloat = 120

    /// Extra reserved space on each side of the camera notch so text never
    /// touches the physical camera/safe-area boundary.
    public static let statusCameraClearance: CGFloat = 18

    /// Height of the compact standby/status pill.
    public static let collapsedStatusHeight: CGFloat = 30

    /// Height of the connected voice activity surface.
    public static let voiceActiveHeight: CGFloat = 76

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

    public static func contentTopInset(
        hasPhysicalNotch: Bool,
        physicalNotchHeight: CGFloat = defaultNotchHeight
    ) -> CGFloat {
        // Expanded content starts below the camera cutout while the tray
        // itself remains flush with the top edge of the screen.
        return hasPhysicalNotch ? physicalNotchHeight + 12.0 : 18.0
    }

    // MARK: - Dimensions (static fallback — no NSScreen required)

    /// Returns dimensions using static fallback values.
    /// Use `calculateFrame(for:screen:)` when a real screen is available for hardware accuracy.
    public static func dimensions(
        for state: NotchState,
        hasPhysicalNotch: Bool = false
    ) -> (width: CGFloat, height: CGFloat) {
        let fallbackNotchW: CGFloat = hasPhysicalNotch ? 160 : 0

        switch state {
        case .hidden:
            return (0, 0)
        case .collapsed:
            // One connected surface: left wing + camera notch + right wing.
            let w: CGFloat = hasPhysicalNotch
                ? fallbackNotchW + (2 * collapsedStatusWidth)
                : 180
            let h: CGFloat = hasPhysicalNotch
                ? max(defaultNotchHeight, collapsedStatusHeight)
                : 32
            return (w, h)
        case .voiceActive:
            let w: CGFloat = hasPhysicalNotch
                ? fallbackNotchW + (2 * collapsedStatusWidth)
                : 400
            return (w, hasPhysicalNotch ? voiceActiveHeight : 64)
        case .liveActivity:
            // Live activities occupy the existing standby notch instead of
            // growing into a Dynamic-Island-style HUD.
            return dimensions(for: .collapsed, hasPhysicalNotch: hasPhysicalNotch)
        case .expanded:
            let expandedW = hasPhysicalNotch ? max(740, fallbackNotchW + 540) : 700
            return (expandedW, 400)
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
            // One connected black surface wraps the camera notch and uses
            // the menu-bar space on both sides. There is no floating card.
            let w = hasNotch
                ? notchW + (2 * collapsedStatusWidth)
                : 180
            let h = hasNotch
                ? max(notchH, collapsedStatusHeight)
                : 32
            let x = screenFrame.midX - (w / 2.0)
            let y = hasNotch ? screenFrame.maxY - h : screenFrame.maxY - h - 10
            return NSRect(x: x, y: y, width: w, height: h)

        case .voiceActive:
            let w: CGFloat = hasNotch
                ? notchW + (2 * collapsedStatusWidth)
                : 400
            let h: CGFloat = hasNotch ? voiceActiveHeight : 64
            return NSRect(x: screenFrame.midX - (w / 2.0), y: screenFrame.maxY - h, width: w, height: h)

        case .liveActivity:
            // Live activities stay inside the same frame as the standby notch.
            return calculateFrame(for: .collapsed, screen: screen)

        case .expanded:
            // Expanded: width accommodates main tray plus floating side docks on left and right
            let rawW = hasNotch ? max(740, notchW + 540) : 700
            let w = min(rawW, screenFrame.width - 24)
            let h: CGFloat = 400
            // The expanded tray is flush with the menu bar. Its SwiftUI
            // surface remains connected to the camera region.
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
        let originX: CGFloat
        let originY: CGFloat

        if hasPhysicalNotch {
            switch state {
            case .collapsed, .voiceActive, .liveActivity:
                originX = screenFrame.midX - (width / 2.0)
                originY = screenFrame.maxY - height
            case .expanded, .hidden:
                originX = screenFrame.midX - (width / 2.0)
                originY = screenFrame.maxY - height
            }
        } else {
            originX = screenFrame.midX - (width / 2.0)
            originY = screenFrame.maxY - height - 10.0
        }
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
