import Testing
import AppKit
@testable import NotchDeck

@Suite("Notch Geometry Calculator Tests")
struct NotchGeometryCalculatorTests {
    @Test("Calculate frame for collapsed state centered at top")
    func testCollapsedFrame() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(for: .collapsed, screenFrame: mockScreenFrame, hasPhysicalNotch: true)
        
        #expect(frame.width == 180)
        #expect(frame.height == 32)
        #expect(frame.midX == mockScreenFrame.midX)
        #expect(frame.maxY == mockScreenFrame.maxY)
    }

    @Test("Calculate frame for expanded state centered at top")
    func testExpandedFrame() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(for: .expanded, screenFrame: mockScreenFrame, hasPhysicalNotch: true)
        
        #expect(frame.width == 540)
        #expect(frame.height == 380)
        #expect(frame.midX == mockScreenFrame.midX)
        #expect(frame.maxY == mockScreenFrame.maxY)
    }

    @Test("External screen without notch adds 10px top margin")
    func testExternalScreenFloatingPill() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frame = NotchGeometryCalculator.calculateFrame(for: .collapsed, screenFrame: mockScreenFrame, hasPhysicalNotch: false)
        
        #expect(frame.width == 180)
        #expect(frame.maxY == mockScreenFrame.maxY - 10)
    }
}
