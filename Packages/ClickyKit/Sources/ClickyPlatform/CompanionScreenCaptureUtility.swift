//
//  CompanionScreenCaptureUtility.swift
//  leanring-buddy
//
//  Standalone screenshot capture for the companion voice flow.
//  Decoupled from the legacy ScreenshotManager so the companion mode
//  can capture screenshots independently without session state.
//

import ClickyFoundation
import AppKit
import ScreenCaptureKit

public struct CompanionScreenCapture {
    public var imageData: Data
    public let label: String
    public let isCursorScreen: Bool
    public let displayWidthInPoints: Int
    public let displayHeightInPoints: Int
    public let displayFrame: CGRect
    public let screenshotWidthInPixels: Int
    public let screenshotHeightInPixels: Int

    /// Convenience accessor that decodes `imageData` to a CGImage for Vision framework requests.
    /// NOTE: this re-decodes the lossy JPEG — prefer `sourceCGImage` (lossless)
    /// for grounding work (ROI crops, HSV checks) to avoid chroma/edge artifacts.
    public var cgImage: CGImage? {
        if let lossless = sourceCGImage { return lossless }
        guard let nsImage = NSImage(data: imageData) else { return nil }
        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    /// Lossless source frame straight from ScreenCaptureKit, retained for
    /// grounding (ROI crops, HSV color checks). Nil when capture predates it.
    public let sourceCGImage: CGImage?

    public init(
        imageData: Data,
        label: String,
        isCursorScreen: Bool,
        displayWidthInPoints: Int,
        displayHeightInPoints: Int,
        displayFrame: CGRect,
        screenshotWidthInPixels: Int,
        screenshotHeightInPixels: Int,
        sourceCGImage: CGImage? = nil
    ) {
        self.imageData = imageData
        self.label = label
        self.isCursorScreen = isCursorScreen
        self.displayWidthInPoints = displayWidthInPoints
        self.displayHeightInPoints = displayHeightInPoints
        self.displayFrame = displayFrame
        self.screenshotWidthInPixels = screenshotWidthInPixels
        self.screenshotHeightInPixels = screenshotHeightInPixels
        self.sourceCGImage = sourceCGImage
    }
}

@MainActor
public enum CompanionScreenCaptureUtility {

    /// Captures all connected displays as JPEG data, labeling each with
    /// whether the user's cursor is on that screen. This gives the AI
    /// full context across multiple monitors.
    public static func captureAllScreensAsJPEG() async throws -> [CompanionScreenCapture] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard !content.displays.isEmpty else {
            throw NSError(domain: "CompanionScreenCapture", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No display available for capture"])
        }

        let mouseLocation = NSEvent.mouseLocation

        // Exclude all windows belonging to this app so the AI sees
        // only the user's content, not our overlays or panels.
        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let ownAppWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == ownBundleIdentifier
        }

        // Build a lookup from display ID to NSScreen so we can use AppKit-coordinate
        // frames instead of CG-coordinate frames. NSEvent.mouseLocation and NSScreen.frame
        // both use AppKit coordinates (bottom-left origin), while SCDisplay.frame uses
        // Core Graphics coordinates (top-left origin). On multi-display setups, the Y
        // origins differ for secondary displays, which breaks cursor-contains checks
        // and downstream coordinate conversions.
        var nsScreenByDisplayID: [CGDirectDisplayID: NSScreen] = [:]
        for screen in NSScreen.screens {
            if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                nsScreenByDisplayID[screenNumber] = screen
            }
        }

        // Sort displays so the cursor screen is always first
        let sortedDisplays = content.displays.sorted { displayA, displayB in
            let frameA = nsScreenByDisplayID[displayA.displayID]?.frame ?? displayA.frame
            let frameB = nsScreenByDisplayID[displayB.displayID]?.frame ?? displayB.frame
            let aContainsCursor = frameA.contains(mouseLocation)
            let bContainsCursor = frameB.contains(mouseLocation)
            if aContainsCursor != bContainsCursor { return aContainsCursor }
            return false
        }

        var capturedScreens: [CompanionScreenCapture] = []

        for (displayIndex, display) in sortedDisplays.enumerated() {
            // Use NSScreen.frame (AppKit coordinates, bottom-left origin) so
            // displayFrame is in the same coordinate system as NSEvent.mouseLocation
            // and the overlay window's screenFrame in BlueCursorView.
            let displayFrame = nsScreenByDisplayID[display.displayID]?.frame
                ?? CGRect(x: display.frame.origin.x, y: display.frame.origin.y,
                          width: CGFloat(display.width), height: CGFloat(display.height))
            let isCursorScreen = displayFrame.contains(mouseLocation)

            let filter = SCContentFilter(display: display, excludingWindows: ownAppWindows)

            let configuration = SCStreamConfiguration()
            let (calibratedWidth, calibratedHeight) = calibratedCaptureDimensions(
                forDisplayWidth: Int(displayFrame.width),
                displayHeight: Int(displayFrame.height)
            )
            configuration.width = calibratedWidth
            configuration.height = calibratedHeight

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            guard let jpegData = NSBitmapImageRep(cgImage: cgImage)
                    .representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                continue
            }

            let screenLabel: String
            if sortedDisplays.count == 1 {
                screenLabel = "user's screen (cursor is here)"
            } else if isCursorScreen {
                screenLabel = "screen \(displayIndex + 1) of \(sortedDisplays.count) — cursor is on this screen (primary focus)"
            } else {
                screenLabel = "screen \(displayIndex + 1) of \(sortedDisplays.count) — secondary screen"
            }

            capturedScreens.append(CompanionScreenCapture(
                imageData: jpegData,
                label: screenLabel,
                isCursorScreen: isCursorScreen,
                displayWidthInPoints: Int(displayFrame.width),
                displayHeightInPoints: Int(displayFrame.height),
                displayFrame: displayFrame,
                screenshotWidthInPixels: configuration.width,
                screenshotHeightInPixels: configuration.height,
                sourceCGImage: cgImage
            ))
        }

        guard !capturedScreens.isEmpty else {
            throw NSError(domain: "CompanionScreenCapture", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to capture any screen"])
        }

        return capturedScreens
    }

    /// Supported Computer Use resolutions paired with their aspect ratios (based on Farza's ElementLocationDetector).
    /// Prevents image distortion that degrades coordinate prediction accuracy.
    private static let supportedComputerUseResolutions: [(width: Int, height: Int, aspectRatio: Double)] = [
        (1024, 768,  1024.0 / 768.0),  // 4:3   = 1.333 (legacy displays)
        (1280, 800,  1280.0 / 800.0),  // 16:10 = 1.600 (MacBook Air, MacBook Pro, most Macs)
        (1366, 768,  1366.0 / 768.0)   // ~16:9 = 1.779 (external monitors, ultrawide fallback)
    ]

    /// Selects the resolution closest to the actual display aspect ratio to avoid distortion.
    public static func calibratedCaptureDimensions(forDisplayWidth displayWidth: Int, displayHeight: Int) -> (width: Int, height: Int) {
        let displayAspectRatio = Double(displayWidth) / Double(max(1, displayHeight))
        var bestWidth = 1280
        var bestHeight = 800
        var smallestDiff = Double.greatestFiniteMagnitude

        for res in supportedComputerUseResolutions {
            let diff = abs(displayAspectRatio - res.aspectRatio)
            if diff < smallestDiff {
                smallestDiff = diff
                bestWidth = res.width
                bestHeight = res.height
            }
        }
        return (bestWidth, bestHeight)
    }
}

