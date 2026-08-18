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
            } else {
                ZStack {
                    // 1. Black notch background — merges with hardware
                    //    Use NotchShape with correct radii per NotchKit spec.
                    //    Collapsed: top=6 bottom=14 / Expanded: top=19 bottom=24
                    NotchShape(
                        topCornerRadius: isExpanded ? 19 : 6,
                        bottomCornerRadius: isExpanded ? 24 : 14
                    )
                    .fill(Color.black)
                    // Shadow: subtle downward-only per design reference (opacity 0.03–0.08, no x offset)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)

                    // 2. Foreground Content
                    Group {
                        switch stateController.currentState {
                        case .hidden:
                            EmptyView()

                        case .collapsed:
                            collapsedContent

                        case .voiceActive:
                            voiceActiveContent

                        case .liveActivity(let title, let countdown):
                            liveActivityContent(title: title, countdown: countdown)

                        case .expanded:
                            expandedContent
                        }
                    }
                }
                // Do NOT set an explicit frame here.
                // The NSWindow frame is already set correctly by NotchWindowController
                // via NotchGeometryCalculator.calculateFrame(for:screen:) which reads
                // real hardware notch dimensions. NSHostingView fills the window frame
                // automatically — setting a second frame here causes a size mismatch
                // that makes content overflow or get clipped incorrectly.
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

    // MARK: - Collapsed: Left Wing + Camera Gap + Right Wing (NotchKit spec)

    private var collapsedContent: some View {
        Button(action: { stateController.transition(to: .expanded) }) {
            HStack(spacing: 0) {
                // LEFT WING — status dot + app name (placed completely to the left of notch)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 5, height: 5)
                    Text("NotchDeck")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .center)

                // CAMERA GAP — covers hardware camera area entirely
                Color.clear.frame(width: cameraGapWidth)

                // RIGHT WING — active model indicator with status dot (placed completely to the right of notch)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green.opacity(0.95))
                        .frame(width: 5, height: 5)
                    Text(stateController.activeAIModel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func liveActivityContent(title: String, countdown: String) -> some View {
        VStack {
            Spacer(minLength: hasPhysicalNotch ? 30 : 4)
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))

                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
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
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Expanded: Feature Panels

    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Top Feature Navigation Dock
            FeatureNavigationDock(stateController: stateController)
                .padding(.top, contentTopPadding)
                .padding(.bottom, 8)

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
            .transition(.opacity.animation(.easeInOut(duration: 0.2)))

            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
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
