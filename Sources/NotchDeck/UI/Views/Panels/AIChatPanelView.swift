import SwiftUI

public struct AIChatPanelView: View {
    @ObservedObject public var stateController: NotchStateController
    public var onSubmitPrompt: (@MainActor (String) -> Void)?
    public var onReplyClarification: (@MainActor (String) -> Void)?
    public var onToggleMic: (@MainActor () -> Void)?

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
        VStack(spacing: 8) {
            // 0. System status / error banner
            if let statusMsg = stateController.systemStatusMessage, !statusMsg.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: statusMsg.hasPrefix("❌") ? "exclamationmark.circle.fill" : "info.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(statusMsg.hasPrefix("❌") ? Color.red.opacity(0.9) : Color.yellow.opacity(0.85))
                    Text(statusMsg)
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                    Spacer()
                    Button(action: { stateController.systemStatusMessage = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(statusMsg.hasPrefix("❌") ? Color.red.opacity(0.15) : Color.yellow.opacity(0.1))
                )
            }

            // 1. Model Header Bar
            HStack(spacing: 8) {
                Menu {
                    Button("Antigravity") { stateController.activeAIModel = "Antigravity" }
                    Button("Claude Code") { stateController.activeAIModel = "Claude Code" }
                    Button("Gemini Flash") { stateController.activeAIModel = "Gemini Flash" }
                    Button("Codex") { stateController.activeAIModel = "Codex" }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                        Text(stateController.activeAIModel)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .foregroundColor(.white)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Agent Active")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)   // page inset per design reference

            // 2. Chat Stream or Empty State
            if stateController.chatMessages.isEmpty && stateController.pendingClarification == nil {
                // Honest empty state
                VStack(spacing: 6) {
                    Spacer(minLength: 10)
                    Image(systemName: "message.badge.waveform")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.2))
                    Text("Tidak ada pesan AI")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                    Text("Ketik di bawah untuk mulai.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.25))
                    Spacer(minLength: 10)
                }
                .frame(maxHeight: 120)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(stateController.chatMessages) { msg in
                                HStack {
                                    if msg.isUser {
                                        Spacer(minLength: 40)
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(msg.text)
                                                .font(.system(size: 11.5))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .fill(Color.white.opacity(0.2))
                                                )
                                            Text(msg.timestamp)
                                                .font(.system(size: 9))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(msg.sender)
                                                    .font(.system(size: 9.5, weight: .semibold))
                                                    .foregroundColor(.white.opacity(0.7))
                                                Text("• " + msg.timestamp)
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.white.opacity(0.35))
                                            }
                                            Text(msg.text)
                                                .font(.system(size: 11.5))
                                                .foregroundColor(.white.opacity(0.95))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                                            .font(.system(size: 11, weight: .semibold))
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
                                                        stateController.appendChatMessage(sender: "You", text: opt, isUser: true)
                                                        stateController.clearClarification()
                                                    }) {
                                                        Text(opt)
                                                            .font(.system(size: 10.5, weight: .medium))
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
                                .padding(8)
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
                }
                .frame(maxHeight: 120)
            }

            // 4. Dedicated Bottom Reply Input Bar
            HStack(spacing: 8) {
                TextField("Reply to \(stateController.activeAIModel)...", text: $stateController.commandPrompt)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
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
                        .padding(5)
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
            .padding(.horizontal, 8)    // outer margin
        }
    }

    private func submitReply() {
        let text = stateController.commandPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stateController.appendChatMessage(sender: "You", text: text, isUser: true)
        onSubmitPrompt?(text)
        stateController.commandPrompt = ""
    }
}
