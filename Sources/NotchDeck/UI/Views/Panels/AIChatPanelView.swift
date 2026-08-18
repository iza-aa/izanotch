import SwiftUI

public struct AIChatPanelView: View {
    @ObservedObject public var stateController: NotchStateController
    public var onSubmitPrompt: (@MainActor (String) -> Void)?
    public var onReplyClarification: (@MainActor (String) -> Void)?
    public var onToggleMic: (@MainActor () -> Void)?

    public struct SupportedAIModel: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let shortName: String
        public let iconName: String
        public let accentColor: Color
    }

    private let availableModels: [SupportedAIModel] = [
        SupportedAIModel(id: "Antigravity", name: "Antigravity 2.0", shortName: "Antigravity", iconName: "sparkles", accentColor: Color.cyan),
        SupportedAIModel(id: "Codex", name: "Codex ChatGPT", shortName: "Codex", iconName: "cpu.fill", accentColor: Color.green),
        SupportedAIModel(id: "Claude Code", name: "Claude Code", shortName: "Claude", iconName: "terminal.fill", accentColor: Color.orange)
    ]

    public init(
        stateController: NotchStateController,
        onSubmitPrompt: (@MainActor (String) -> Void)? = nil,
        onReplyClarification: (@MainActor (String) -> Void)? = nil,
        onToggleMic: (@MainActor () -> Void)? = nil
    ) {
        self.stateController = stateController
        self.onSubmitPrompt = onSubmitPrompt
        self.onReplyClarification = onReplyClarification
        self.onToggleMic = onToggleMic
    }

    public var body: some View {
        VStack(spacing: 10) {
            // 0. System status / error banner
            if let statusMsg = stateController.systemStatusMessage, !statusMsg.isEmpty {
                let isError = statusMsg.lowercased().contains("error") || statusMsg.lowercased().contains("failed")
                HStack(spacing: 6) {
                    Image(systemName: isError ? "exclamationmark.circle.fill" : "info.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isError ? Color.red.opacity(0.9) : Color.yellow.opacity(0.85))
                    Text(statusMsg)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                    Spacer()
                    Button(action: { stateController.systemStatusMessage = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isError ? Color.red.opacity(0.15) : Color.yellow.opacity(0.1))
                )
                .padding(.horizontal, 28)
            }

            // 1. Model Header Bar (Clean status header — Switcher is floating outside on the left)
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(modelAccentColor(stateController.activeAIModel))
                        .frame(width: 7, height: 7)

                    Text(displayModelName(stateController.activeAIModel))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Agent Active")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 28)

            // 2. Chat Stream or Empty State (Fills available vertical space)
            if stateController.chatMessages.isEmpty && stateController.pendingClarification == nil {
                // Honest empty state centered in the middle of tray
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "message.badge.waveform")
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.25))
                    Text("Tidak ada pesan AI")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Ketik di bawah untuk mulai.")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundColor(.white.opacity(0.28))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(stateController.chatMessages) { msg in
                                HStack {
                                    if msg.isUser {
                                        Spacer(minLength: 40)
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text(renderMarkdown(msg.text))
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(Color.white.opacity(0.2))
                                                )
                                            Text(msg.timestamp)
                                                .font(.system(size: 9, design: .rounded))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 4) {
                                                Text(msg.sender)
                                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.75))
                                                Text("• " + msg.timestamp)
                                                    .font(.system(size: 9, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.35))
                                            }
                                            Text(renderMarkdown(msg.text))
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundColor(.white.opacity(0.95))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .fill(Color.white.opacity(0.08))
                                                )
                                        }
                                        Spacer(minLength: 40)
                                    }
                                }
                                .id(msg.id)
                            }

                            // 3. Interactive Clarification Question Banner
                            if let item = stateController.pendingClarification {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "questionmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white)
                                        Text(item.question)
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)
                                        Spacer()
                                        Button(action: { stateController.clearClarification() }) {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 9))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if let options = item.options, !options.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 6) {
                                                ForEach(options, id: \.self) { opt in
                                                    Button(action: {
                                                        if let onReply = onReplyClarification {
                                                             onReply(opt)
                                                        } else {
                                                             onSubmitPrompt?(opt)
                                                        }
                                                        stateController.clearClarification()
                                                    }) {
                                                        Text(opt)
                                                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 4)
                                                            .background(Capsule().fill(Color.white.opacity(0.18)))
                                                            .foregroundColor(.white)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.1))
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: stateController.chatMessages.count) { _, _ in
                        if let last = stateController.chatMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // 4. Dedicated Bottom Reply Input Bar pinned at the bottom
            HStack(spacing: 8) {
                TextField("Reply to \(stateController.activeAIModel)...", text: $stateController.commandPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundColor(.white)
                    .onSubmit {
                        submitReply()
                    }

                if !stateController.commandPrompt.isEmpty {
                    Button(action: { submitReply() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { onToggleMic?() }) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)   // input inset per design reference
            .padding(.vertical, 12)      // input vertical inset per design reference
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .padding(.horizontal, 28)    // outer margin aligning with panels
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submitReply() {
        let text = stateController.commandPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // NOTE: Do NOT appendChatMessage here — AppDelegate.submitPrompt is the
        // single source of truth and will append the user bubble itself.
        onSubmitPrompt?(text)
        stateController.commandPrompt = ""
    }

    private func renderMarkdown(_ text: String) -> AttributedString {
        let cleaned = preprocessMarkdownText(text)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        if let attr = try? AttributedString(markdown: cleaned, options: options) {
            return attr
        }
        return AttributedString(cleaned)
    }

    private func preprocessMarkdownText(_ raw: String) -> String {
        let lines = raw.components(separatedBy: "\n")
        var processedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Convert Markdown Headings (e.g. # Header, ## Subheader, ### Section) to bold text
            if trimmed.hasPrefix("###### ") {
                let content = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                processedLines.append("**\(content)**")
            } else if trimmed.hasPrefix("##### ") {
                let content = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                processedLines.append("**\(content)**")
            } else if trimmed.hasPrefix("#### ") {
                let content = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                processedLines.append("**\(content)**")
            } else if trimmed.hasPrefix("### ") {
                let content = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                processedLines.append("**\(content)**")
            } else if trimmed.hasPrefix("## ") {
                let content = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                processedLines.append("**\(content)**")
            } else if trimmed.hasPrefix("# ") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                processedLines.append("**\(content)**")
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                // Divider line
                processedLines.append("")
            } else if trimmed.hasPrefix("- ") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                processedLines.append("• \(content)")
            } else if trimmed.hasPrefix("* ") && !trimmed.hasPrefix("**") {
                let content = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                processedLines.append("• \(content)")
            } else {
                processedLines.append(line)
            }
        }

        return processedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func displayModelName(_ modelId: String) -> String {
        switch modelId {
        case "Antigravity": return "Antigravity 2.0"
        case "Codex": return "Codex ChatGPT"
        case "Claude Code": return "Claude Code"
        default: return modelId
        }
    }

    private func modelAccentColor(_ modelId: String) -> Color {
        switch modelId {
        case "Antigravity": return Color.cyan
        case "Codex": return Color.green
        case "Claude Code": return Color.orange
        default: return Color.white
        }
    }
}
