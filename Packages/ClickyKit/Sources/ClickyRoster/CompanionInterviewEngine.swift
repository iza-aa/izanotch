//
//  CompanionInterviewEngine.swift
//  izaNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//

import SwiftUI
import Combine
import ClickyFoundation
import ClickyAIProviders
import ClickySpeech

public enum NewClickyStage: Equatable {
    case interviewing
    case reviewingSpec
    case customizingCharacter
}

@MainActor
public final class CompanionInterviewEngine: ObservableObject {
    public static let shared = CompanionInterviewEngine()

    @Published public var stage: NewClickyStage = .interviewing
    @Published public var conversationLog: [(speaker: String, text: String)] = []
    @Published public var currentBubbleTitle: String = "Tell me what this new Clicky should handle."
    @Published public var currentBubbleBody: String = "What background work, using its memory and files, would move your work forward?"
    @Published public var isThinking: Bool = false
    @Published public var userTurnCount: Int = 0

    // Synthesized Spec Fields
    @Published public var synthesizedName: String = "Research Buddy"
    @Published public var synthesizedRole: String = "Market & Web Researcher"
    @Published public var synthesizedSpecMarkdown: String = ""
    @Published public var synthesizedFirstMessage: String = "I'm ready to research your topics and organize findings. What would you like to explore first?"
    @Published public var synthesizedSummary: String = ""

    // Character Styling
    @Published public var selectedTheme: CompanionColorTheme = CompanionColorTheme.allThemes[0]
    @Published public var customCloudColorHex: String = "#4ADE80"
    @Published public var customRingColorHex: String = "#FBCFE8"
    @Published var selectedMood: AgentCloudFaceMood = .happy
    @Published public var selectedTemplateId: String = "strobi"
    @Published public var selectedAvatarLabExpression: String = "neutral"

    private lazy var geminiClient: GeminiBridgeClient = {
        GeminiBridgeClient()
    }()

    private init() {
        reset()
    }

    public func reset() {
        stage = .interviewing
        conversationLog = [
            ("Clicky", "Tell me what this new Clicky should handle. What background work, using its memory and files, would move your work forward?")
        ]
        currentBubbleTitle = "Tell me what this new Clicky should handle."
        currentBubbleBody = "What background work, using its memory and files, would move your work forward?"
        isThinking = false
        userTurnCount = 0

        synthesizedName = "Research Buddy"
        synthesizedRole = "Market & Web Researcher"
        synthesizedSpecMarkdown = defaultMarkdownSpec(name: "Research Buddy", role: "Market & Web Researcher", summary: "Researches active topics, reads screen context, and structures findings.")
        synthesizedFirstMessage = "I'm ready to research your topics and organize findings. What would you like to explore first?"
        synthesizedSummary = "Researches active topics, reads screen context, and structures findings."

        let theme = CompanionColorTheme.allThemes.randomElement() ?? CompanionColorTheme.allThemes[0]
        selectedTheme = theme
        customCloudColorHex = theme.cloudColorHex
        customRingColorHex = theme.ringColorHex
        selectedMood = .happy
        selectedTemplateId = "strobi"
        selectedAvatarLabExpression = "neutral"
    }

    // MARK: - Answer Submission
    public func submitUserAnswer(_ answer: String) {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        conversationLog.append(("User", trimmed))
        userTurnCount += 1
        isThinking = true

        let turnCount = userTurnCount
        let answersLog = conversationLog

        Task {
            // Build conversation history for Model
            var history: [(userPlaceholder: String, assistantResponse: String)] = []
            var pendingUser: String?

            for entry in answersLog {
                if entry.speaker == "User" {
                    pendingUser = entry.text
                } else if let u = pendingUser, entry.speaker == "Clicky" {
                    history.append((userPlaceholder: u, assistantResponse: entry.text))
                    pendingUser = nil
                }
            }

            let isExplicitFinalize = trimmed.lowercased().contains("buat") || trimmed.lowercased().contains("make") || trimmed.lowercased().contains("cukup")
            let promptToModel = CompanionInterviewPolicy.promptForTurn(
                userAnswer: trimmed,
                turnCount: turnCount,
                isExplicitFinalize: isExplicitFinalize
            )

            do {
                let (responseText, _) = try await geminiClient.analyzeImageStreaming(
                    images: [],
                    systemPrompt: CompanionInterviewPolicy.systemPrompt,
                    conversationHistory: history,
                    userPrompt: promptToModel,
                    onTextChunk: { _ in }
                )

                await MainActor.run {
                    self.processModelResponse(responseText, userPrompt: trimmed)
                }
            } catch {
                ClickyLogger.warning("[INTERVIEW]", "Claude API call failed (\(error.localizedDescription)), using local heuristic fallback")
                await MainActor.run {
                    self.fallbackLocalResponse(userPrompt: trimmed)
                }
            }
        }
    }

    // MARK: - Response Processing
    private func processModelResponse(_ text: String, userPrompt: String) {
        isThinking = false

        if text.contains("[FOUND_CLICKY]") {
            parseAndSynthesizeSpec(from: text, fallbackUserPrompt: userPrompt)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.stage = .reviewingSpec
            }
            ClickySoundEngine.shared.play(.open)
        } else {
            // Display normal question in the bubble
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let sentences = cleaned.components(separatedBy: CharacterSet(charactersIn: ".?!")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

            if sentences.count >= 2 {
                currentBubbleTitle = sentences[0] + "."
                currentBubbleBody = sentences[1] + (cleaned.hasSuffix("?") ? "?" : ".")
            } else {
                currentBubbleTitle = "Got it."
                currentBubbleBody = cleaned
            }

            conversationLog.append(("Clicky", cleaned))
        }
    }

    // MARK: - Local Heuristic Fallback (Zero Hallucination / Offline Safety)
    private func fallbackLocalResponse(userPrompt: String) {
        isThinking = false
        let lower = userPrompt.lowercased()

        if userTurnCount < 2 && !lower.contains("buat") && !lower.contains("make") && !lower.contains("langsung") {
            // Ask Question 2
            let questionTitle: String
            let questionBody: String

            if lower.contains("riset") || lower.contains("research") || lower.contains("market") || lower.contains("data") {
                questionTitle = "Got it, research & data analysis."
                questionBody = "What apps or documents will it summarize, and should it produce notes or spreadsheets?"
            } else if lower.contains("code") || lower.contains("web") || lower.contains("swift") || lower.contains("bug") {
                questionTitle = "Great, a development companion."
                questionBody = "Should it focus on debugging active code, reviewing pull requests, or writing new features?"
            } else if lower.contains("write") || lower.contains("tulis") || lower.contains("doc") || lower.contains("content") {
                questionTitle = "Understood, writing & content creation."
                questionBody = "Who is the audience for these drafts, and what tone of voice should it write in?"
            } else {
                questionTitle = "Sounds very helpful."
                questionBody = "What specific apps on your Mac should it connect to, and does this work repeat daily?"
            }

            currentBubbleTitle = questionTitle
            currentBubbleBody = questionBody
            conversationLog.append(("Clicky", "\(questionTitle) \(questionBody)"))
        } else {
            // Synthesize based on collected prompts
            let combined = conversationLog.filter { $0.speaker == "User" }.map(\.text).joined(separator: " ").lowercased()

            let name: String
            let role: String
            let summary: String

            if combined.contains("code") || combined.contains("web") || combined.contains("swift") || combined.contains("dev") {
                name = "Code Buddy"
                role = "Software Engineer"
                summary = "Reviews active codebases, helps debug terminal errors, and drafts clean architecture solutions."
            } else if combined.contains("write") || combined.contains("tulis") || combined.contains("copy") || combined.contains("draft") {
                name = "Writer Buddy"
                role = "Content Strategist"
                summary = "Drafts clear documents, refines copywriting, and keeps messaging aligned with audience goals."
            } else if combined.contains("design") || combined.contains("ui") || combined.contains("ux") {
                name = "Design Scout"
                role = "UI/UX Specialist"
                summary = "Inspects screen designs, audits layout alignment, and suggests polished interaction tokens."
            } else {
                let firstWord = userPrompt.components(separatedBy: .whitespaces).first?.capitalized ?? "Focus"
                name = "\(firstWord) Buddy"
                role = "Desktop Assistant"
                summary = "Specialized macOS companion designed for focused daily tasks and screen collaboration."
            }

            synthesizedName = name
            synthesizedRole = role
            synthesizedSummary = summary
            synthesizedFirstMessage = "I'm ready to assist with \(name.lowercased()) tasks. What are we tackling right now?"
            synthesizedSpecMarkdown = defaultMarkdownSpec(name: name, role: role, summary: summary)

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                self.stage = .reviewingSpec
            }
            ClickySoundEngine.shared.play(.open)
        }
    }

    // MARK: - Spec Parser
    private func parseAndSynthesizeSpec(from text: String, fallbackUserPrompt: String) {
        func extract(tag: String) -> String? {
            guard let range = text.range(of: "\(tag):") else { return nil }
            let remainder = text[range.upperBound...]
            let line = remainder.components(separatedBy: .newlines).first ?? ""
            return line.trimmingCharacters(in: .whitespaces)
        }

        if let name = extract(tag: "NAME"), !name.isEmpty {
            synthesizedName = name
        }
        if let role = extract(tag: "ROLE"), !role.isEmpty {
            synthesizedRole = role
        }
        if let firstMsg = extract(tag: "FIRST_MESSAGE"), !firstMsg.isEmpty {
            synthesizedFirstMessage = firstMsg
        }
        if let sum = extract(tag: "SUMMARY"), !sum.isEmpty {
            synthesizedSummary = sum
        }

        // Extract SPEC markdown between SPEC: and [/FOUND_CLICKY]
        if let specStart = text.range(of: "SPEC:\n")?.upperBound ?? text.range(of: "SPEC:")?.upperBound {
            let specRemainder = text[specStart...]
            if let specEnd = specRemainder.range(of: "[/FOUND_CLICKY]")?.lowerBound {
                let rawMarkdown = String(specRemainder[..<specEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rawMarkdown.isEmpty {
                    synthesizedSpecMarkdown = rawMarkdown
                    return
                }
            }
        }

        // Default markdown if block wasn't cleanly extracted
        synthesizedSpecMarkdown = defaultMarkdownSpec(name: synthesizedName, role: synthesizedRole, summary: synthesizedSummary)
    }

    private func defaultMarkdownSpec(name: String, role: String, summary: String) -> String {
        return """
        # \(name) (\(role))

        <!-- Generated by Izanotchy Companion Studio -->
        <!-- Date: \(ISO8601DateFormatter().string(from: Date())) -->

        ## 🎯 Primary Goal & Identity
        - **Name**: \(name)
        - **Role**: \(role)
        - **Summary**: \(summary.isEmpty ? "Specialized assistant designed for desktop collaboration." : summary)

        ## ⚡ Core Capabilities & Integrations
        - Screen context awareness and spatial pointing
        - Structured document reading & OCR summarization
        - Native macOS desktop tool orchestration

        ## 🧠 Rules & Standing Behavior
        - Standing rule: Verify physical screen state before claiming task completion.
        - Maintain concise, warm, and highly actionable answers.
        - Cite relevant filenames and window titles when giving guidance.
        """
    }

    // MARK: - Navigation Between Stages
    public func proceedToCharacterCustomization() {
        // Validate name
        if synthesizedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            synthesizedName = "My Buddy"
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            stage = .customizingCharacter
        }
    }

    public func backToInterview() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            stage = .interviewing
        }
    }

    public func backToSpecReview() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            stage = .reviewingSpec
        }
    }

    // MARK: - Final Launch
    public func finalizeAndLaunch() -> CompanionProfile {
        let cleanName = synthesizedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Buddy" : synthesizedName
        let cleanRole = synthesizedRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Specialist" : synthesizedRole
        let slug = cleanName.lowercased().replacingOccurrences(of: " ", with: "-")

        // 1. Write physical .md spec file
        let specURL = CompanionWorkspaceManager.shared.saveCustomCompanionSpec(slug: slug, markdownContent: synthesizedSpecMarkdown)

        // 2. Build Companion Profile (Empty messages so new companion displays clean centered Welcome State)
        let profile = CompanionProfile(
            slug: slug,
            name: cleanName,
            role: cleanRole,
            summary: synthesizedSummary.isEmpty ? cleanRole : synthesizedSummary,
            cloudColorHex: customCloudColorHex,
            ringColorHex: customRingColorHex,
            status: .idle,
            lastMessage: "",
            activeSkills: ["screen-reading", "documents"],
            mdPath: specURL.path,
            isPinnedToRail: true,
            messages: [],
            mood: selectedMood,
            templateId: selectedTemplateId
        )

        // 3. Register in Roster Store (persists and triggers syncSessionsFromRoster)
        CompanionRosterStore.shared.addOrUpdateCompanion(profile)

        // 4. Select active session via delegate registry
        CompanionSessionDelegateRegistry.shared?.selectSession(id: profile.id)

        ClickySoundEngine.shared.play(.open)
        ClickyLogger.success("[INTERVIEW]", "Successfully created & launched companion: \(cleanName) (\(cleanRole)) with spec at \(specURL.path)")

        return profile
    }
}

