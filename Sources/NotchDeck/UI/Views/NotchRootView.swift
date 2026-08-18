import SwiftUI

public struct NotchRootView: View {
    @ObservedObject public var stateController: NotchStateController
    @ObservedObject public var cardStore: CardDataStore = .shared
    public var hoverMonitor: NotchHoverMonitor?
    public var audioLevels: [CGFloat]
    public var hasPhysicalNotch: Bool
    public var onSubmitPrompt: (@MainActor (String) -> Void)?
    public var onReplyClarification: (@MainActor (String) -> Void)?
    public var onToggleMic: (@MainActor () -> Void)?
    public var onStopMic: (@MainActor () -> Void)?

    public init(
        stateController: NotchStateController,
        cardStore: CardDataStore = .shared,
        hoverMonitor: NotchHoverMonitor? = nil,
        audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7],
        hasPhysicalNotch: Bool = true,
        onSubmitPrompt: (@MainActor (String) -> Void)? = nil,
        onReplyClarification: (@MainActor (String) -> Void)? = nil,
        onToggleMic: (@MainActor () -> Void)? = nil,
        onStopMic: (@MainActor () -> Void)? = nil
    ) {
        self.stateController = stateController
        self.cardStore = cardStore
        self.hoverMonitor = hoverMonitor
        self.audioLevels = audioLevels
        self.hasPhysicalNotch = hasPhysicalNotch
        self.onSubmitPrompt = onSubmitPrompt
        self.onReplyClarification = onReplyClarification
        self.onToggleMic = onToggleMic
        self.onStopMic = onStopMic
    }

    private var contentTopPadding: CGFloat {
        NotchGeometryCalculator.contentTopInset(hasPhysicalNotch: hasPhysicalNotch)
    }

    public var body: some View {
        ZStack {
            // 1. Deep Matte Pitch Black Background (Zero Outer Borders)
            NotchEarShape(hasPhysicalNotch: hasPhysicalNotch, cornerRadius: 24, earRadius: 14)
                .fill(Color.black.opacity(0.98))
                .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)

            // 2. Foreground Content
            Group {
                switch stateController.currentState {
                case .collapsed:
                    Button(action: {
                        stateController.transition(to: .expanded)
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.white.opacity(0.85))
                                .frame(width: 7, height: 7)

                            Text("NotchDeck")
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, hasPhysicalNotch ? 10 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                case .voiceActive:
                    VStack {
                        Spacer(minLength: hasPhysicalNotch ? 34 : 4)
                        HStack(spacing: 12) {
                            AudioWaveformView(levels: audioLevels)

                            Text(stateController.commandPrompt.isEmpty ? "Listening..." : stateController.commandPrompt)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Button(action: {
                                onStopMic?()
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }

                case .liveActivity(let title, let countdown):
                    VStack {
                        Spacer(minLength: hasPhysicalNotch ? 30 : 4)
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))

                            Text(title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Text(countdown)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }

                case .expanded:
                    VStack(spacing: 10) {
                        // 1. Header Command Bar (Monochrome & Action Wired)
                        HStack(spacing: 8) {
                            Menu {
                                Button("Antigravity") { stateController.activeAIModel = "Antigravity" }
                                Button("Claude Code") { stateController.activeAIModel = "Claude Code" }
                                Button("Gemini Flash") { stateController.activeAIModel = "Gemini Flash" }
                                Button("Codex") { stateController.activeAIModel = "Codex" }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10, weight: .medium))
                                    Text(stateController.activeAIModel)
                                        .font(.system(size: 11, weight: .medium))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                )
                                .foregroundColor(.white.opacity(0.9))
                            }
                            .menuStyle(.borderlessButton)

                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.35))

                            TextField("Ask AI or speak reminder...", text: $stateController.commandPrompt)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundColor(.white)
                                .onSubmit {
                                    onSubmitPrompt?(stateController.commandPrompt)
                                }

                            if !stateController.commandPrompt.isEmpty {
                                Button(action: {
                                    onSubmitPrompt?(stateController.commandPrompt)
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: {
                                onToggleMic?()
                            }) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 11))
                                    .padding(6)
                                    .background(Circle().fill(Color.white.opacity(0.1)))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )

                        // 2. Interactive Clarification Banner (If agent asks a question / needs input)
                        if let item = stateController.pendingClarification {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text(item.question)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                    Spacer()
                                    Button(action: { stateController.clearClarification() }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.5))
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
                                                        .font(.system(size: 10.5, weight: .medium))
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 4)
                                                        .background(Capsule().fill(Color.white.opacity(0.16)))
                                                        .foregroundColor(.white)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                        }

                        // 3. System Status / Permission Warning (If any)
                        if let statusMsg = stateController.systemStatusMessage {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                Text(statusMsg)
                                    .font(.system(size: 10.5))
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .foregroundColor(.white.opacity(0.6))
                        }

                        // 4. Category Filter Bar
                        CategoryFilterBarView(store: cardStore)

                        // 5. Horizontal Card Carousel
                        CardCarouselView(store: cardStore)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, contentTopPadding)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(
            width: widthForState(stateController.currentState),
            height: heightForState(stateController.currentState)
        )
        .clipped()
        .onHover { isHovered in
            if isHovered {
                hoverMonitor?.mouseEntered()
            } else {
                hoverMonitor?.mouseExited()
            }
        }
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).width
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        let baseHeight = NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).height
        if state == .expanded && stateController.pendingClarification != nil {
            return baseHeight + 50
        }
        return baseHeight
    }
}
