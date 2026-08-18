import SwiftUI

public struct SettingsView: View {
    @State private var geminiKey: String = ""
    @State private var claudeKey: String = ""
    @State private var statusMessage: String = ""
    @State private var isTesting: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⚙️ NotchDeck Settings")
                .font(.headline)
                .foregroundColor(.primary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Google Gemini API Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("AIzaSy...", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)

                Text("Anthropic Claude API Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("sk-ant-...", text: $claudeKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Save Keys") {
                    saveKeys()
                }
                .buttonStyle(.borderedProminent)

                Button(isTesting ? "Testing..." : "Test Connection") {
                    testConnection()
                }
                .disabled(isTesting || geminiKey.isEmpty)

                Spacer()
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(statusMessage.contains("✅") ? .green : .red)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 280)
        .onAppear {
            geminiKey = KeychainManager.load(key: "notchdeck.gemini.apikey") ?? ""
            claudeKey = KeychainManager.load(key: "notchdeck.claude.apikey") ?? ""
        }
    }

    private func saveKeys() {
        try? KeychainManager.save(key: "notchdeck.gemini.apikey", value: geminiKey)
        try? KeychainManager.save(key: "notchdeck.claude.apikey", value: claudeKey)
        statusMessage = "✅ Keys saved securely to Keychain."
    }

    private func testConnection() {
        isTesting = true
        statusMessage = "Connecting to Gemini..."
        Task {
            do {
                _ = try await NotchDeckAIClient.shared.parseSchedule(
                    userUtterance: "test ping",
                    apiKey: geminiKey
                )
                await MainActor.run {
                    self.statusMessage = "✅ Connection successful! AI is ready."
                    self.isTesting = false
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "❌ Connection failed: \(error.localizedDescription)"
                    self.isTesting = false
                }
            }
        }
    }
}
