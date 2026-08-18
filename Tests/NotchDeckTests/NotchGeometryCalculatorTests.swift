import Testing
import AppKit
@testable import NotchDeck

@Suite("Notch Geometry Calculator Tests")
struct NotchGeometryCalculatorTests {
    @Test("Calculate frame for collapsed state centered at top on physical notch display")
    func testCollapsedFramePhysicalNotch() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(for: .collapsed, screenFrame: mockScreenFrame, hasPhysicalNotch: true)
        
        #expect(frame.width == 200)
        #expect(frame.height == 36)
        #expect(frame.midX == mockScreenFrame.midX)
        #expect(frame.maxY == mockScreenFrame.maxY)
    }

    @Test("Calculate frame for expanded state with notch clearance")
    func testExpandedFrame() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(for: .expanded, screenFrame: mockScreenFrame, hasPhysicalNotch: true)
        
        #expect(frame.width == 560)
        #expect(frame.height >= 260) // Includes notch height + content
        #expect(frame.midX == mockScreenFrame.midX)
        #expect(frame.maxY == mockScreenFrame.maxY)
    }

    @Test("External screen without notch adds 10px top margin and 160x32 floating pill")
    func testExternalScreenFloatingPill() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frame = NotchGeometryCalculator.calculateFrame(for: .collapsed, screenFrame: mockScreenFrame, hasPhysicalNotch: false)
        
        #expect(frame.width == 160)
        #expect(frame.height == 32)
        #expect(frame.maxY == mockScreenFrame.maxY - 10)
    }

    @Test("Calculate dynamic notch height and top content inset")
    func testNotchHeightAndInset() {
        let notchHeight = NotchGeometryCalculator.defaultNotchHeight
        #expect(notchHeight >= 32.0 && notchHeight <= 40.0)

        let insetNotched = NotchGeometryCalculator.contentTopInset(hasPhysicalNotch: true)
        let insetExternal = NotchGeometryCalculator.contentTopInset(hasPhysicalNotch: false)

        #expect(insetNotched > insetExternal)
        #expect(insetNotched >= notchHeight)
    }
}
