import Testing
@testable import NotchDeck

@Suite("NotchDeck Sanity Tests")
struct NotchDeckSanityTests {
    @Test("Package initialization sanity test")
    func testPackageInitialization() {
        #expect(true == true)
    }
}
