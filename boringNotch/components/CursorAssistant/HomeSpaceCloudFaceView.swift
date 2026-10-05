import SwiftUI

// MARK: - HomeSpaceAmbientMotionFrozenKey
// Binary-confirmed: HomeSpaceAmbientMotionFrozenKey
struct HomeSpaceAmbientMotionFrozenKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var homeSpaceAmbientMotionFrozen: Bool {
        get { self[HomeSpaceAmbientMotionFrozenKey.self] }
        set { self[HomeSpaceAmbientMotionFrozenKey.self] = newValue }
    }
}

// MARK: - ColorBlob
// Binary-confirmed: ColorBlob
struct ColorBlob: View {
    var color: Color = Color(red: 0.12, green: 0.52, blue: 0.95)
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 6)
    }
}

// MARK: - HomeSpaceCloudFaceView
// Binary-confirmed: HomeSpaceCloudFaceView (View.task @ HeyClicky/HomeSpaceCloudFaceView.swift)
struct HomeSpaceCloudFaceView: View {
    var mood: AgentCloudFaceMood = .happy
    var expression: CloudFaceExpression = .idle
    var tintColor: Color = Color(hex: "#FDE047") // Warm sunny golden yellow
    var glowColor: Color = Color(hex: "#F59E0B") // Warm amber aura
    var eyeColor: Color = .white
    var width: CGFloat = 52
    var height: CGFloat = 36

    @Environment(\.homeSpaceAmbientMotionFrozen) private var isAmbientFrozen

    @State private var isBlinking = false
    @State private var breathingOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Ambient Aura Glow (Signature HeyClicky glow)
            AgentCloudShape()
                .fill(tintColor)
                .blur(radius: 8)
                .opacity(0.65)
                .frame(width: width * 1.05, height: height * 1.05)
                .offset(y: isAmbientFrozen ? 0 : breathingOffset)

            // Cloud body
            AgentCloudShape()
                .fill(
                    LinearGradient(
                        colors: [
                            tintColor.opacity(0.95),
                            tintColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: glowColor.opacity(0.55), radius: 10, x: 0, y: 2)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                .frame(width: width, height: height)
                .offset(y: isAmbientFrozen ? 0 : breathingOffset)

            // Dynamic Facial Features based on Mood (Pure Vector SVG Geometry)
            ZStack {
                switch mood {
                case .happy, .neutral:
                    HStack(spacing: width * 0.16) {
                        AgentCloudCurvedHappyEyeShape(isOpen: !isBlinking)
                            .stroke(eyeColor, style: StrokeStyle(lineWidth: max(2.2, width * 0.055), lineCap: .round, lineJoin: .round))
                            .frame(width: width * 0.18, height: isBlinking ? 1.5 : height * 0.20)

                        AgentCloudCurvedHappyEyeShape(isOpen: !isBlinking)
                            .stroke(eyeColor, style: StrokeStyle(lineWidth: max(2.2, width * 0.055), lineCap: .round, lineJoin: .round))
                            .frame(width: width * 0.18, height: isBlinking ? 1.5 : height * 0.20)
                    }

                case .focused:
                    HStack(spacing: width * 0.18) {
                        if isBlinking {
                            Capsule()
                                .fill(eyeColor)
                                .frame(width: width * 0.16, height: 2)
                            Capsule()
                                .fill(eyeColor)
                                .frame(width: width * 0.16, height: 2)
                        } else {
                            Circle()
                                .fill(eyeColor)
                                .frame(width: width * 0.15, height: width * 0.15)
                            Circle()
                                .fill(eyeColor)
                                .frame(width: width * 0.15, height: width * 0.15)
                        }
                    }

                case .thinking:
                    HStack(alignment: .center, spacing: width * 0.16) {
                        if isBlinking {
                            Capsule()
                                .fill(eyeColor)
                                .frame(width: width * 0.16, height: 2)
                            Capsule()
                                .fill(eyeColor)
                                .frame(width: width * 0.16, height: 2)
                        } else {
                            Circle()
                                .fill(eyeColor)
                                .frame(width: width * 0.14, height: width * 0.14)
                                .offset(y: 1)

                            AgentCloudThinkingEyeShape()
                                .stroke(eyeColor, style: StrokeStyle(lineWidth: max(2.2, width * 0.055), lineCap: .round, lineJoin: .round))
                                .frame(width: width * 0.18, height: height * 0.22)
                                .offset(y: -2)
                        }
                    }

                case .surprised:
                    VStack(spacing: height * 0.06) {
                        HStack(spacing: width * 0.18) {
                            if isBlinking {
                                Capsule()
                                    .fill(eyeColor)
                                    .frame(width: width * 0.16, height: 2)
                                Capsule()
                                    .fill(eyeColor)
                                    .frame(width: width * 0.16, height: 2)
                            } else {
                                Circle()
                                    .stroke(eyeColor, lineWidth: max(2.0, width * 0.05))
                                    .frame(width: width * 0.15, height: width * 0.15)
                                Circle()
                                    .stroke(eyeColor, lineWidth: max(2.0, width * 0.05))
                                    .frame(width: width * 0.15, height: width * 0.15)
                            }
                        }

                        if !isBlinking {
                            Ellipse()
                                .fill(eyeColor.opacity(0.85))
                                .frame(width: width * 0.09, height: height * 0.12)
                        }
                    }

                case .sleepy:
                    HStack(spacing: width * 0.16) {
                        Capsule()
                            .fill(eyeColor)
                            .frame(width: width * 0.16, height: 2)
                        Capsule()
                            .fill(eyeColor)
                            .frame(width: width * 0.16, height: 2)
                    }
                }
            }
            .offset(y: (isAmbientFrozen ? 0 : breathingOffset) - (height * 0.04))
        }
        .frame(width: width, height: height)
        .onAppear {
            guard !isAmbientFrozen else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathingOffset = -3
            }
            startBlinkLoop()
        }
    }

    private func startBlinkLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 3.0...6.5)))
                guard !Task.isCancelled else { break }
                withAnimation(.easeOut(duration: 0.1)) {
                    isBlinking = true
                }
                try? await Task.sleep(for: .milliseconds(140))
                withAnimation(.easeIn(duration: 0.12)) {
                    isBlinking = false
                }
            }
        }
    }
}
