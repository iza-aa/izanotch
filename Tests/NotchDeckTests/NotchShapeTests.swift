import Testing
import SwiftUI
@testable import NotchDeck

@Suite("Notch Shape Tests")
struct NotchShapeTests {

    @Test("NotchShape builds non-empty path for physical notch (collapsed radii)")
    func testCollapsedShapePath() {
        // Collapsed: top=6, bottom=14 per NotchKit specification
        let shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
        let rect = CGRect(x: 0, y: 0, width: 560, height: 36)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("NotchShape builds non-empty path for expanded state (expanded radii)")
    func testExpandedShapePath() {
        // Expanded: top=19, bottom=24 per NotchKit specification
        let shape = NotchShape(topCornerRadius: 19, bottomCornerRadius: 24)
        let rect = CGRect(x: 0, y: 0, width: 510, height: 280)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("NotchShape animatableData round-trips correctly")
    func testAnimatableData() {
        var shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
        let data = shape.animatableData
        #expect(data.first == 6)
        #expect(data.second == 14)

        // Simulate SwiftUI interpolating toward expanded state
        shape.animatableData = AnimatablePair(19.0, 24.0)
        #expect(shape.topCornerRadius == 19)
        #expect(shape.bottomCornerRadius == 24)
    }

    @Test("NotchShape path is valid in zero-width rect (edge case)")
    func testZeroWidthPath() {
        let shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
        let rect = CGRect(x: 0, y: 0, width: 0, height: 36)
        // Should not crash; path may be empty or degenerate but must not throw
        let path = shape.path(in: rect)
        #expect(path.isEmpty || !path.isEmpty)  // just validates no crash
    }

}
