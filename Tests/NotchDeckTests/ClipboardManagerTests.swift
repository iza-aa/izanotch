import Testing
@testable import NotchDeck

@Suite("Clipboard Manager Tests")
struct ClipboardManagerTests {
    @Test("Masking OpenAI Secret Key matches 8 prefix + *** + 4 suffix rule")
    func testOpenAIKeyMasking() {
        let rawKey = "sk-proj-1234567890abcdef1234567890" // 34 chars
        let analysis = ClipboardManager.analyze(text: rawKey)
        
        #expect(analysis.hasSecret == true)
        #expect(analysis.category == "secret_token")
        #expect(analysis.detectedType == "openai_api_key")
        #expect(analysis.maskedPreview == "sk-proj-**********************7890")
    }

    @Test("Detect Swift Code Snippet")
    func testSwiftCodeDetection() {
        let code = "import SwiftUI\nstruct ContentView: View { var body: some View { Text(\"Hello\") } }"
        let analysis = ClipboardManager.analyze(text: code)
        
        #expect(analysis.hasSecret == false)
        #expect(analysis.category == "code_snippet")
        #expect(analysis.language == "swift")
    }
}
