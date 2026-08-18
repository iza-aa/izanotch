import SwiftUI

public struct NotchRootView: View {
    @ObservedObject public var stateController: NotchStateController
    @ObservedObject public var cardStore: CardDataStore = .shared
    public var hoverMonitor: NotchHoverMonitor?
    public var audioLevels: [CGFloat]
    public var hasPhysicalNotch: Bool
    /// The physical hardware notch width (camera region), used to keep camera gap clear.
    public var hardwareNotchWidth: CGFloat
    public var onSubmitPrompt: (@MainActor (String) -> Void)?
    public var onReplyClarification: (@MainActor (String) -> Void)?
    public var onToggleMic: (@MainActor () -> Void)?
    public var onStopMic: (@MainActor () -> Void)?
    public var onAddSchedule: (@MainActor (String) -> Void)?

    public init(
        stateController: NotchStateController,
        cardStore: CardDataStore = .shared,
        hoverMonitor: NotchHoverMonitor? = nil,
        audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7],
        hasPhysicalNotch: Bool = true,
        hardwareNotchWidth: CGFloat = 150,
        onSubmitPrompt: (@MainActor (String) -> Void)? = nil,
        onReplyClarification: (@MainActor (String) -> Void)? = nil,
        onToggleMic: (@MainActor () -> Void)? = nil,
        onStopMic: (@MainActor () -> Void)? = nil,
        onAddSchedule: (@MainActor (String) -> Void)? = nil
    ) {
        self.stateController = stateController
        self.cardStore = cardStore
        self.hoverMonitor = hoverMonitor
        self.audioLevels = audioLevels
        self.hasPhysicalNotch = hasPhysicalNotch
        self.hardwareNotchWidth = hardwareNotchWidth
        self.onSubmitPrompt = onSubmitPrompt
        self.onReplyClarification = onReplyClarification
        self.onToggleMic = onToggleMic
        self.onStopMic = onStopMic
        self.onAddSchedule = onAddSchedule
    }

    private var contentTopPadding: CGFloat {
        NotchGeometryCalculator.contentTopInset(hasPhysicalNotch: hasPhysicalNotch)
    }

    /// Camera gap width ensures that the hardware notch area is completely clear of text.
    private var cameraGapWidth: CGFloat {
        hasPhysicalNotch ? hardwareNotchWidth : 8
    }

    public var body: some View {
        Group {
            if stateController.currentState == .hidden {
                Color.clear.frame(width: 0, height: 0)
            } else if stateController.currentState == .expanded {
                // EXPANDED: Floating Side Dock (DI LUAR TRAY SEBELAH KIRI) + Main Notch Tray
                HStack(alignment: .top, spacing: 12) {
                    // 1. FLOATING SIDE DOCK (DI LUAR NOTCH SEBELAH KIRI)
                    VStack(spacing: 9) {
                        floatingSideButton(id: "Antigravity", icon: "sparkles", color: .cyan, name: "Antigravity 2.0")
                        floatingSideButton(id: "Codex", icon: "cpu.fill", color: .green, name: "Codex ChatGPT")
                        floatingSideButton(id: "Claude Code", icon: "terminal.fill", color: .orange, name: "Claude Code")
                    }
                    .padding(6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.9))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 10, x: -2, y: 4)
                    )
                    .padding(.top, contentTopPadding + 4)

                    // 2. MAIN TRAY NOTCH
                    ZStack {
                        NotchShape(
                            topCornerRadius: 19,
                            bottomCornerRadius: 24
                        )
                        .fill(Color.black)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

                        expandedContent
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.leading, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onHover { isHovered in
                    if isHovered {
                        hoverMonitor?.mouseEntered()
                    } else {
                        hoverMonitor?.mouseExited()
                    }
                }
            } else {
                // COLLAPSED / LIVE ACTIVITY / VOICE ACTIVE
                ZStack {
                    NotchShape(
                        topCornerRadius: 6,
                        bottomCornerRadius: 14
                    )
                    .fill(Color.black)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)

                    Group {
                        switch stateController.currentState {
                        case .hidden, .expanded:
                            EmptyView()

                        case .collapsed:
                            collapsedContent

                        case .voiceActive:
                            voiceActiveContent

                        case .liveActivity(let title, let countdown):
                            liveActivityContent(title: title, countdown: countdown)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onHover { isHovered in
                    if isHovered {
                        hoverMonitor?.mouseEntered()
                    } else {
                        hoverMonitor?.mouseExited()
                    }
                }
            }
        }
    }

    private func floatingSideButton(id: String, icon: String, color: Color, name: String) -> some View {
        let isSelected = stateController.activeAIModel == id
        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                stateController.activeAIModel = id
            }
        }) {
            ZStack {
                Circle()
                    .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.1))
                    .frame(width: 32, height: 32)

                if isSelected {
                    Circle()
                        .strokeBorder(color.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }

                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? color : .white.opacity(0.65))
            }
        }
        .buttonStyle(.plain)
        .help(name)
    }

    // MARK: - Collapsed: Left Wing Floating Action Buttons + Camera Gap + Right Wing

    private var collapsedContent: some View {
        HStack(spacing: 0) {
            // LEFT WING — Floating Circular App Switcher Icons (di luar notch, di sebelah kiri status bar)
            HStack(spacing: 6) {
                // 1. Antigravity 2.0
                floatingModelCircle(id: "Antigravity", icon: "sparkles", color: .cyan, name: "Antigravity 2.0")
                // 2. Codex (ChatGPT)
                floatingModelCircle(id: "Codex", icon: "cpu.fill", color: .green, name: "Codex ChatGPT")
                // 3. Claude Code
                floatingModelCircle(id: "Claude Code", icon: "terminal.fill", color: .orange, name: "Claude Code")
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .center)

            // CAMERA GAP — covers hardware camera area entirely (Klik untuk expand notch)
            Button(action: { stateController.transition(to: .expanded) }) {
                Color.clear
                    .frame(width: cameraGapWidth)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // RIGHT WING — active model indicator with status dot (Klik untuk expand notch)
            Button(action: { stateController.transition(to: .expanded) }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green.opacity(0.95))
                        .frame(width: 5, height: 5)
                    Text(displayModelName(stateController.activeAIModel))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func floatingModelCircle(id: String, icon: String, color: Color, name: String) -> some View {
        let isSelected = stateController.activeAIModel == id
        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                stateController.activeAIModel = id
            }
        }) {
            ZStack {
                Circle()
                    .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.12))
                    .frame(width: 22, height: 22)

                if isSelected {
                    Circle()
                        .strokeBorder(color.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }

                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? color : .white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .help(name)
    }

    private func displayModelName(_ modelId: String) -> String {
        switch modelId {
        case "Antigravity": return "Antigravity"
        case "Codex": return "Codex"
        case "Claude Code": return "Claude"
        default: return modelId
        }
    }

    // MARK: - Voice Active

    private var voiceActiveContent: some View {
        VStack {
            Spacer(minLength: hasPhysicalNotch ? 34 : 4)
            HStack(spacing: 12) {
                AudioWaveformView(levels: audioLevels)

                Text(stateController.commandPrompt.isEmpty ? "Listening..." : stateController.commandPrompt)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Button(action: { onStopMic?() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Live Activity

    // MARK: - Live Activity (Dynamic Island Style Pill)

    private func liveActivityContent(title: String, countdown: String) -> some View {
        Button(action: { stateController.transition(to: .expanded) }) {
            VStack {
                Spacer(minLength: hasPhysicalNotch ? 30 : 4)
                HStack(spacing: 10) {
                    // Contextual SF Symbol indicator (no emojis)
                    ZStack {
                        Circle()
                            .fill(liveActivityAccentColor(for: title).opacity(0.2))
                            .frame(width: 22, height: 22)

                        Image(systemName: liveActivityIconName(for: title))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(liveActivityAccentColor(for: title))
                    }

                    Text(cleanTitle(title))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)

                    Spacer()

                    Text(countdown)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func liveActivityIconName(for title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("done") || lower.contains("complete") {
            return "checkmark"
        } else if lower.contains("tool") || lower.contains("running") || lower.contains("exec") {
            return "gearshape.2.fill"
        } else if lower.contains("clarification") || lower.contains("question") || lower.contains("action") {
            return "questionmark.bubble.fill"
        } else if lower.contains("schedule") || lower.contains("meeting") || lower.contains("remind") {
            return "calendar.badge.clock"
        } else {
            return "sparkles"
        }
    }

    private func liveActivityAccentColor(for title: String) -> Color {
        let lower = title.lowercased()
        if lower.contains("done") || lower.contains("complete") {
            return Color.green
        } else if lower.contains("tool") || lower.contains("running") {
            return Color.orange
        } else if lower.contains("clarification") || lower.contains("question") {
            return Color.cyan
        } else {
            return Color.white
        }
    }

    private func cleanTitle(_ text: String) -> String {
        // Strip out any accidental unicode emoji characters
        text.unicodeScalars.filter { !$0.properties.isEmojiPresentation && $0.value > 127 ? false : true }.map(String.init).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Expanded: Feature Panels

    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Top Feature Navigation Dock
            FeatureNavigationDock(stateController: stateController)
                .padding(.top, contentTopPadding)
                .padding(.bottom, 12)

            // Active Feature Panel — each panel owns its own internal padding (16pt cards, 24pt page)
            Group {
                switch stateController.activeTab {
                case .aiChat:
                    AIChatPanelView(
                        stateController: stateController,
                        onSubmitPrompt: onSubmitPrompt,
                        onReplyClarification: onReplyClarification,
                        onToggleMic: onToggleMic
                    )

                case .notes:
                    NotesPanelView(cardStore: cardStore)

                case .schedule:
                    SchedulePanelView(
                        cardStore: cardStore,
                        onAddSchedule: onAddSchedule
                    )

                case .music:
                    MusicLyricsPanelView()

                case .clipboard:
                    ClipboardPanelView(cardStore: cardStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        }
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private var isExpanded: Bool {
        stateController.currentState == .expanded
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).width
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).height
    }
}
