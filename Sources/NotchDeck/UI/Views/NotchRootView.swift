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
    public var onAddSchedule: (@MainActor (String) -> Void)?

    public init(
        stateController: NotchStateController,
        cardStore: CardDataStore = .shared,
        hoverMonitor: NotchHoverMonitor? = nil,
        audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7],
        hasPhysicalNotch: Bool = true,
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
        self.onSubmitPrompt = onSubmitPrompt
        self.onReplyClarification = onReplyClarification
        self.onToggleMic = onToggleMic
        self.onStopMic = onStopMic
        self.onAddSchedule = onAddSchedule
    }

    private var contentTopPadding: CGFloat {
        NotchGeometryCalculator.contentTopInset(hasPhysicalNotch: hasPhysicalNotch)
    }

    public var body: some View {
        Group {
            if stateController.currentState == .hidden {
                Color.clear.frame(width: 0, height: 0)
            } else {
                ZStack {
                    // 1. Matte Pitch Black Notch Background
                    NotchEarShape(hasPhysicalNotch: hasPhysicalNotch, cornerRadius: 24, earRadius: 14)
                        .fill(Color.black.opacity(0.98))
                        .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 7)

                    // 2. Foreground Content
                    Group {
                        switch stateController.currentState {
                        case .hidden:
                            EmptyView()

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
                                // 1. Top Feature Navigation Dock
                                FeatureNavigationDock(stateController: stateController)

                                // 2. Active Feature Panel
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
                                .transition(.opacity)

                                Spacer(minLength: 0)
                            }
                            .padding(.top, contentTopPadding)
                            .padding(.bottom, 10)
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
        }
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).width
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).height
    }
}
