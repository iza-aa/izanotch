import SwiftUI

public struct NotchRootView: View {
    @ObservedObject public var stateController: NotchStateController
    public var audioLevels: [CGFloat]

    public init(stateController: NotchStateController, audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7]) {
        self.stateController = stateController
        self.audioLevels = audioLevels
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            switch stateController.currentState {
            case .collapsed:
                HStack(spacing: 8) {
                    Circle().fill(Color.cyan).frame(width: 8, height: 8)
                    Text("NotchDeck").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.white)
                }
                .padding(.horizontal, 12)

            case .voiceActive:
                HStack(spacing: 12) {
                    AudioWaveformView(levels: audioLevels)
                    Text(stateController.commandPrompt.isEmpty ? "Mendengarkan..." : stateController.commandPrompt)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { stateController.transition(to: .collapsed) }) {
                        Image(systemName: "stop.circle.fill").foregroundColor(.orange).font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

            case .liveActivity(let title, let countdown):
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock").foregroundColor(.green)
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Text(countdown).font(.system(size: 11, weight: .bold)).foregroundColor(.yellow)
                }
                .padding(.horizontal, 16)

            case .expanded:
                VStack(spacing: 12) {
                    HStack {
                        Menu {
                            Button("Antigravity") { stateController.activeAIModel = "Antigravity" }
                            Button("Claude Code") { stateController.activeAIModel = "Claude Code" }
                        } label: {
                            Text("✨ \(stateController.activeAIModel) ▾")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.white.opacity(0.1)).cornerRadius(8)
                        }
                        .menuStyle(.borderlessButton)

                        TextField("Ask AI or speak reminder...", text: $stateController.commandPrompt)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)

                        Button(action: { stateController.transition(to: .voiceActive) }) {
                            Image(systemName: "mic.fill").foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding(16)
            }
        }
        .frame(
            width: widthForState(stateController.currentState),
            height: heightForState(stateController.currentState)
        )
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: return 180
        case .voiceActive: return 360
        case .liveActivity: return 320
        case .expanded: return 540
        }
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: return 32
        case .voiceActive: return 60
        case .liveActivity: return 44
        case .expanded: return 380
        }
    }
}
