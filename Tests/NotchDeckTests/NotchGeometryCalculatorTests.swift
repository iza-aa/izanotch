import Testing
import AppKit
@testable import NotchDeck

@Suite("Notch Geometry Calculator Tests")
struct NotchGeometryCalculatorTests {

    // MARK: - Static `dimensions()` — unit-test safe (no NSScreen needed)

    @Test("Collapsed physical notch uses one compact status surface")
    func testCollapsedDimensionsPhysicalNotch() {
        let (w, h) = NotchGeometryCalculator.dimensions(for: .collapsed, hasPhysicalNotch: true)
        #expect(w == 160 + (2 * NotchGeometryCalculator.collapsedStatusWidth))
        #expect(h == NotchGeometryCalculator.defaultNotchHeight)
    }

    @Test("Collapsed pill on external display uses 180x32 floating pill dimensions")
    func testCollapsedDimensionsExternal() {
        let (w, h) = NotchGeometryCalculator.dimensions(for: .collapsed, hasPhysicalNotch: false)
        #expect(w == 180)
        #expect(h == 32)
    }

    @Test("Live activity reuses standby notch dimensions")
    func testLiveActivityUsesStandbyDimensions() {
        let standbyNotch = NotchGeometryCalculator.dimensions(for: .collapsed, hasPhysicalNotch: true)
        let liveActivityNotch = NotchGeometryCalculator.dimensions(for: .liveActivity(title: "Build", countdown: "Running"), hasPhysicalNotch: true)
        #expect(liveActivityNotch.width == standbyNotch.width)
        #expect(liveActivityNotch.height == standbyNotch.height)

        let standbyExternal = NotchGeometryCalculator.dimensions(for: .collapsed, hasPhysicalNotch: false)
        let liveActivityExternal = NotchGeometryCalculator.dimensions(for: .liveActivity(title: "Build", countdown: "Running"), hasPhysicalNotch: false)
        #expect(liveActivityExternal.width == standbyExternal.width)
        #expect(liveActivityExternal.height == standbyExternal.height)
    }

    @Test("Expanded state is wider than collapsed and at least 200pt tall")
    func testExpandedDimensionsAreReasonable() {
        let (w, h) = NotchGeometryCalculator.dimensions(for: .expanded, hasPhysicalNotch: true)
        #expect(w >= 300)        // must have room for content
        #expect(h >= 200)        // must have room for panels
    }

    @Test("Hidden state returns zero dimensions")
    func testHiddenDimensions() {
        let (w, h) = NotchGeometryCalculator.dimensions(for: .hidden, hasPhysicalNotch: true)
        #expect(w == 0)
        #expect(h == 0)
    }

    // MARK: - Legacy `calculateFrame(for:screenFrame:hasPhysicalNotch:)` overload

    @Test("Legacy overload: collapsed pill sits to the left of the physical camera notch")
    func testLegacyCollapsedFramePhysicalNotch() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(
            for: .collapsed,
            screenFrame: mockScreenFrame,
            hasPhysicalNotch: true
        )

        #expect(frame.width == 160 + (2 * NotchGeometryCalculator.collapsedStatusWidth))
        #expect(frame.height == NotchGeometryCalculator.defaultNotchHeight)
        #expect(frame.midX == mockScreenFrame.midX)
        #expect(frame.maxY == mockScreenFrame.maxY)
    }

    @Test("Legacy overload: expanded frame is wider than collapsed and stays centered")
    func testLegacyExpandedFrameCentered() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let collapsedFrame = NotchGeometryCalculator.calculateFrame(
            for: .collapsed,
            screenFrame: mockScreenFrame,
            hasPhysicalNotch: true
        )
        let expandedFrame = NotchGeometryCalculator.calculateFrame(
            for: .expanded,
            screenFrame: mockScreenFrame,
            hasPhysicalNotch: true
        )

        #expect(expandedFrame.width > collapsedFrame.width)
        #expect(expandedFrame.height > collapsedFrame.height)
        #expect(expandedFrame.midX == mockScreenFrame.midX)
        #expect(expandedFrame.maxY == mockScreenFrame.maxY)
        // Must not overflow screen width
        #expect(expandedFrame.width <= mockScreenFrame.width)
    }

    @Test("Legacy overload: external display floating pill has 10pt top margin")
    func testLegacyExternalScreenFloatingPill() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frame = NotchGeometryCalculator.calculateFrame(
            for: .collapsed,
            screenFrame: mockScreenFrame,
            hasPhysicalNotch: false
        )

        #expect(frame.width == 180)
        #expect(frame.height == 32)
        #expect(frame.maxY == mockScreenFrame.maxY - 10)
    }

    @Test("Legacy overload: hidden state returns zero-size rect at screen top-center")
    func testLegacyHiddenFrame() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(
            for: .hidden,
            screenFrame: mockScreenFrame,
            hasPhysicalNotch: true
        )
        #expect(frame.width == 0)
        #expect(frame.height == 0)
        #expect(frame.origin.x == mockScreenFrame.midX)
    }

    // MARK: - Content Insets

    @Test("Content top inset is internal after physical notch window is repositioned")
    func testNotchHeightAndInset() {
        let notchHeight = NotchGeometryCalculator.defaultNotchHeight
        #expect(notchHeight >= 32.0 && notchHeight <= 40.0)

        let insetNotched  = NotchGeometryCalculator.contentTopInset(hasPhysicalNotch: true)
        let insetExternal = NotchGeometryCalculator.contentTopInset(hasPhysicalNotch: false)

        #expect(insetNotched > insetExternal)
        #expect(insetNotched >= notchHeight)
    }
}
