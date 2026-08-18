import SwiftUI

public struct NotchRootView: View {
    @ObservedObject public var stateController: NotchStateController
    @ObservedObject public var cardStore: CardDataStore = .shared
    public var audioLevels: [CGFloat]
    public var hasPhysicalNotch: Bool

    public init(
        stateController: NotchStateController,
        cardStore: CardDataStore = .shared,
        audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7],
        hasPhysicalNotch: Bool = true
    ) {
        self.stateController = stateController
        self.cardStore = cardStore
        self.audioLevels = audioLevels
        self.hasPhysicalNotch = hasPhysicalNotch
    }

    private var contentTopPadding: CGFloat {
        NotchGeometryCalculator.contentTopInset(hasPhysicalNotch: hasPhysicalNotch)
    }

    public var body: some View {
        ZStack {
            // 1. Dynamic Liquid Glass Background with Bézier Notch Ears
            NotchEarShape(hasPhysicalNotch: hasPhysicalNotch, cornerRadius: 24, earRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.98),
                            Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    NotchEarShape(hasPhysicalNotch: hasPhysicalNotch, cornerRadius: 24, earRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.28),
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.5), radius: 16, x: 0, y: 8)

            // 2. Foreground Content Switched by State
            VStack(spacing: 0) {
                switch stateController.currentState {
                case .collapsed:
                    HStack(spacing: 8) {
                        Circle()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                            .frame(width: 8, height: 8)
                            .shadow(color: .cyan.opacity(0.6), radius: 4)

                        Text("NotchDeck")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .voiceActive:
                    VStack {
                        Spacer(minLength: hasPhysicalNotch ? 34 : 4)
                        HStack(spacing: 12) {
                            AudioWaveformView(levels: audioLevels)

                            Text(stateController.commandPrompt.isEmpty ? "Mendengarkan ucapan Anda..." : stateController.commandPrompt)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Button(action: { stateController.transition(to: .collapsed) }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.orange)
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
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 14))
                                .foregroundColor(.green)

                            Text(title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Text(countdown)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.green.opacity(0.2)))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }

                case .expanded:
                    VStack(spacing: 12) {
                        // 1. Header Command Bar (Positioned safely below the notch cutout)
                        HStack(spacing: 8) {
                            Menu {
                                Button("✨ Antigravity") { stateController.activeAIModel = "Antigravity" }
                                Button(" Claude Code") { stateController.activeAIModel = "Claude Code" }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.cyan)
                                    Text(stateController.activeAIModel)
                                        .font(.system(size: 11, weight: .semibold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                )
                                .foregroundColor(.white)
                            }
                            .menuStyle(.borderlessButton)

                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))

                            TextField("Ask AI or speak reminder...", text: $stateController.commandPrompt)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundColor(.white)

                            Button(action: { stateController.transition(to: .voiceActive) }) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 12))
                                    .padding(6)
                                    .background(Circle().fill(Color.cyan.opacity(0.2)))
                                    .foregroundColor(.cyan)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )

                        // 2. Category Filter Bar (Image 1 Style)
                        CategoryFilterBarView(store: cardStore)

                        // 3. Horizontal Card Carousel (Image 1 & 2 Style)
                        CardCarouselView(store: cardStore)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, contentTopPadding)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(
            width: widthForState(stateController.currentState),
            height: heightForState(stateController.currentState)
        )
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).width
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).height
    }
}
