import Testing
import SwiftUI
@testable import NotchDeck

@Suite("Notch Shape Tests")
struct NotchShapeTests {
    @Test("NotchEarShape path builds without empty bounds")
    func testShapePath() {
        let shape = NotchEarShape(hasPhysicalNotch: true, cornerRadius: 22, earRadius: 10)
        let rect = CGRect(x: 0, y: 0, width: 560, height: 280)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }

    @Test("NotchEarShape for external screen builds valid rounded path")
    func testExternalShapePath() {
        let shape = NotchEarShape(hasPhysicalNotch: false, cornerRadius: 22, earRadius: 10)
        let rect = CGRect(x: 0, y: 0, width: 560, height: 280)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
    }
}
