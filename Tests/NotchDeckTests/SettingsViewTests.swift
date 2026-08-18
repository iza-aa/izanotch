import Testing
@testable import NotchDeck

@Suite("Settings View Tests")
struct SettingsViewTests {
    @Test("Save API Key to Keychain")
    func testSaveAPIKeyFromSettings() throws {
        try KeychainManager.save(key: "notchdeck.gemini.apikey", value: "AIzaSyTest123")
        let loaded = KeychainManager.load(key: "notchdeck.gemini.apikey")
        #expect(loaded == "AIzaSyTest123")
    }
}
