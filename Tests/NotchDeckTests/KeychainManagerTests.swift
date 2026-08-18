import Testing
import Foundation
@testable import NotchDeck

@Suite("Keychain Manager Tests")
struct KeychainManagerTests {
    let testKey = "notchdeck.test.apikey.\(UUID().uuidString)"

    @Test("Save and load API Key from Keychain")
    func testSaveAndLoadKey() throws {
        try KeychainManager.save(key: testKey, value: "test-secret-key-12345")
        let loaded = KeychainManager.load(key: testKey)
        #expect(loaded == "test-secret-key-12345")
        
        try KeychainManager.delete(key: testKey)
        #expect(KeychainManager.load(key: testKey) == nil)
    }
}
