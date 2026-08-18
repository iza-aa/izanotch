import Testing
import Foundation
@testable import NotchDeck

@Suite("Multi AI Client Tests")
struct MultiAIClientTests {
    @Test("Build Anthropic Claude API Request Payload")
    func testAnthropicPayloadBuilding() throws {
        let request = MultiAIClient.buildClaudeRequest(
            apiKey: "sk-ant-testkey12345",
            prompt: "Refactor this swift code",
            model: "claude-3-5-sonnet-20241022"
        )

        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-testkey12345")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.httpMethod == "POST")
    }

    @Test("Build Google Gemini API Request Payload")
    func testGeminiPayloadBuilding() throws {
        let request = MultiAIClient.buildGeminiRequest(
            apiKey: "AIzaSyTest123",
            prompt: "Parse schedule",
            model: "gemini-2.5-flash"
        )

        #expect(request.url?.absoluteString.contains("generativelanguage.googleapis.com") == true)
        #expect(request.httpMethod == "POST")
    }

    @Test("Build OpenAI / Codex API Request Payload")
    func testOpenAIPayloadBuilding() throws {
        let request = MultiAIClient.buildOpenAIRequest(
            apiKey: "sk-proj-testkey123",
            prompt: "Optimize database query",
            model: "gpt-4o"
        )

        #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-proj-testkey123")
        #expect(request.httpMethod == "POST")
    }

    @Test("Build Claude and Codex CLI Arguments without duplication")
    func testCLIArguments() {
        let prompt = "Explain SwiftUI State"
        let claudeArgs = MultiAIClient.buildClaudeCLIArguments(prompt: prompt)
        let codexArgs = MultiAIClient.buildCodexCLIArguments(prompt: prompt)

        #expect(claudeArgs == ["-p", prompt])
        #expect(codexArgs == ["exec", prompt])
    }

    @Test("Find standard executable path without shell injection")
    func testFindExecutable() {
        let shPath = MultiAIClient.findExecutable(named: "sh")
        #expect(shPath != nil)
    }
}
