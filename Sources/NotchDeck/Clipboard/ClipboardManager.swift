import Foundation

public struct ClipboardItemAnalysis: Codable, Sendable {
    public let category: String
    public let hasSecret: Bool
    public let detectedType: String?
    public let maskedPreview: String
    public let language: String?
    public let suggestedActions: [String]
    public let cardBadge: String

    public init(category: String, hasSecret: Bool, detectedType: String?, maskedPreview: String, language: String?, suggestedActions: [String], cardBadge: String) {
        self.category = category
        self.hasSecret = hasSecret
        self.detectedType = detectedType
        self.maskedPreview = maskedPreview
        self.language = language
        self.suggestedActions = suggestedActions
        self.cardBadge = cardBadge
    }
}

public struct ClipboardManager: Sendable {
    public static func analyze(text: String) -> ClipboardItemAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Detect Secret Keys
        if trimmed.hasPrefix("sk-proj-") || trimmed.hasPrefix("sk-") || trimmed.hasPrefix("ghp_") || trimmed.hasPrefix("AKIA") {
            let prefixLen = min(8, trimmed.count)
            let suffixLen = min(4, max(0, trimmed.count - prefixLen))
            
            let prefix = String(trimmed.prefix(prefixLen))
            let suffix = String(trimmed.suffix(suffixLen))
            let maskCount = max(0, trimmed.count - prefixLen - suffixLen)
            let masked = prefix + String(repeating: "*", count: maskCount) + suffix

            return ClipboardItemAnalysis(
                category: "secret_token",
                hasSecret: true,
                detectedType: trimmed.hasPrefix("sk") ? "openai_api_key" : "api_key",
                maskedPreview: masked,
                language: nil,
                suggestedActions: ["Copy Masked", "Clear Clipboard"],
                cardBadge: "Masked Secret"
            )
        }

        // 2. Detect Code Snippets
        if trimmed.contains("struct ") || trimmed.contains("func ") || trimmed.contains("import ") || trimmed.contains("const ") || trimmed.contains("def ") {
            let lang = trimmed.contains("import SwiftUI") || trimmed.contains("func ") ? "swift" : "code"
            return ClipboardItemAnalysis(
                category: "code_snippet",
                hasSecret: false,
                detectedType: nil,
                maskedPreview: trimmed,
                language: lang,
                suggestedActions: ["Explain Code", "Format"],
                cardBadge: "\(lang.capitalized)"
            )
        }

        return ClipboardItemAnalysis(
            category: "plain_text",
            hasSecret: false,
            detectedType: nil,
            maskedPreview: trimmed,
            language: nil,
            suggestedActions: ["Copy"],
            cardBadge: "📝 Text"
        )
    }
}
