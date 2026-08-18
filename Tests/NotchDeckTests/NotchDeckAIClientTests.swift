import Testing
import Foundation
@testable import NotchDeck

@Suite("NotchDeck AI Client Tests")
struct NotchDeckAIClientTests {
    @Test("Missing API Key throws missingAPIKey error")
    func testMissingAPIKey() async {
        let client = NotchDeckAIClient()
        do {
            _ = try await client.parseSchedule(userUtterance: "meeting jam 2", apiKey: "")
            #expect(Bool(false), "Should have thrown AIClientError.missingAPIKey")
        } catch let error as AIClientError {
            switch error {
            case .missingAPIKey: #expect(true)
            default: #expect(Bool(false), "Wrong error: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}
