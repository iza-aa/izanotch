import SwiftUI

// MARK: - BallClickyState
// State mesin bola Clicky meniru graph Rive Grokbot (hub Main + satelit).
// Nilai terukur dari frame referensi ada di komentar tiap case.

enum BallClickyState: Equatable {
    case idle        // kapsul normal, abu netral
    case working     // badge biru + halo biru + bob
    case talking     // bounce 2Hz selama streaming
    case needsYes    // kapsul tall + halo amber (consent)
    case annoyed     // mata miring + shake (klik 3x / slap 3x, auto-recovery)
    case dizzy       // mata dot + wobble (fling, auto-recovery)
    case error       // bars + pink wash + red dot
    case done        // big+small dot + green dot, 4s -> idle

    // MARK: - Resolver (satu-satunya sumber kebenaran, meniru input boolean Rive)

    static func resolve(
        isProcessingTask: Bool,
        isStreaming: Bool,
        voiceState: CompanionVoiceState,
        hasPendingConsent: Bool
    ) -> BallClickyState {
        if hasPendingConsent { return .needsYes }
        if isStreaming || voiceState == .responding { return .talking }
        if isProcessingTask || voiceState == .processing { return .working }
        return .idle
    }
}

// MARK: - BallClickyView
// Bola abu + 2 mata kapsul hitam, tanpa mulut — meniru bahasa bentuk Grokbot.
// Ukuran terukur: mata w=0.126D h=0.298D, gap ~= 1 lebar mata, pusat dy +0.19D.

struct BallClickyView: View {
    var state: BallClickyState = .idle
    var diameter: CGFloat = 72
    var gaze: CGSize = .zero          // -0.5...0.5, mengikuti cursor (gaze delay di caller)
    var showBadge: Bool = false      // lingkaran biru + 3 bars (working)
    var proximity: Bool = false      // membesar saat cursor dekat (diukur dari jarak)
    var statusDot: Color? = nil      // hijau/merah/amber di kanan-atas

    @State private var blinkScale: CGFloat = 1
    @State private var breathY: CGFloat = 0
    @State private var talkPhase: Bool = false

    private var eyeW: CGFloat { diameter * 0.126 }
    private var eyeH: CGFloat { diameter * 0.298 }
    private var eyeGap: CGFloat { eyeW }
    private var eyeY: CGFloat { diameter * 0.19 }

    private var bodyGrad: LinearGradient {
        switch state {
        case .working, .talking, .needsYes:
            // terukur focus: #adadad -> #70abd0
            return LinearGradient(
                colors: [Color(hex: "#adadad"), Color(hex: "#ababac"), Color(hex: "#70abd0")],
                startPoint: .top, endPoint: .bottom
            )
        case .error:
            // terukur e1: pink wash bawah
            return LinearGradient(
                colors: [Color(hex: "#c9cccf"), Color(hex: "#d8b9bb"), Color(hex: "#d3a3a6")],
                startPoint: .top, endPoint: .bottom
            )
        default:
            // terukur idle: #c6c6c6 -> #ada6a8
            return LinearGradient(
                colors: [Color(hex: "#d7d3d0"), Color(hex: "#c6c6c6"), Color(hex: "#ada6a8")],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private var haloColor: Color {
        switch state {
        case .working, .talking: return Color(red: 46/255, green: 168/255, blue: 245/255, opacity: 0.22)
        case .needsYes: return Color(red: 1.0, green: 0.75, blue: 0.14, opacity: 0.22)
        case .error: return Color(red: 248/255, green: 113/255, blue: 113/255, opacity: 0.22)
        case .done: return Color(red: 52/255, green: 211/255, blue: 153/255, opacity: 0.22)
        case .annoyed: return Color(red: 251/255, green: 146/255, blue: 60/255, opacity: 0.22)
        default: return Color(red: 1.0, green: 0.88, blue: 0.66, opacity: 0.20)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(haloColor)
                .blur(radius: diameter * 0.18)
                .frame(width: diameter * 1.35, height: diameter * 1.35)

            Circle()
                .fill(bodyGrad)
                .frame(width: diameter, height: diameter)
                .scaleEffect(x: bodySquashX, y: bodySquashY)
                .offset(y: breathY + (state == .working ? workBob : 0))

            HStack(spacing: eyeGap) {
                eyeView(isLeft: true)
                eyeView(isLeft: false)
            }
            .scaleEffect(proximity ? 1.15 : 1.0)
            .offset(x: gaze.width * diameter * 0.09, y: eyeY + gaze.height * diameter * 0.07)
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.72), value: gaze)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: proximity)

            if showBadge || state == .working {
                Circle()
                    .fill(Color(hex: "#2ea8f5"))
                    .frame(width: diameter * 0.28, height: diameter * 0.28)
                    .overlay(
                        HStack(spacing: diameter * 0.025) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: diameter * 0.02)
                                    .fill(Color.black)
                                    .frame(width: diameter * 0.038, height: diameter * 0.11)
                            }
                        }
                    )
                    .offset(x: -diameter * 0.42, y: -diameter * 0.42)
            }

            if let dot = statusDot {
                Circle()
                    .fill(dot)
                    .frame(width: diameter * 0.10, height: diameter * 0.10)
                    .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
                    .offset(x: diameter * 0.30, y: -diameter * 0.34)
            } else if state == .error {
                Circle()
                    .fill(Color(hex: "#f60000"))
                    .frame(width: diameter * 0.10, height: diameter * 0.10)
                    .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
                    .offset(x: -diameter * 0.30, y: -diameter * 0.28)
            } else if state == .done {
                Circle()
                    .fill(Color(hex: "#45f600"))
                    .frame(width: diameter * 0.10, height: diameter * 0.10)
                    .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
                    .offset(x: -diameter * 0.30, y: -diameter * 0.28)
            }
        }
        .frame(width: diameter * 1.35, height: diameter * 1.35)
        .onAppear { startIdleLife() }
        .onChange(of: state) { _, s in
            if s == .talking {
                withAnimation(.easeInOut(duration: 0.25).repeatForever(autoreverses: true)) {
                    talkPhase = true
                }
            } else {
                talkPhase = false
            }
        }
    }

    @State private var workBob: CGFloat = 0

    @ViewBuilder
    private func eyeView(isLeft: Bool) -> some View {
        switch state {
        case .dizzy, .done:
            // mata dot kecil (terukur f1/f2 + merge)
            HStack(spacing: eyeGap * 0.6) {
                Circle().fill(Color.black).frame(width: eyeW * 0.85, height: eyeW * 0.85)
            }
            .frame(width: eyeW, height: eyeH)
        case .error:
            // bars horizontal pendek (terukur e2: w=0.22D h=0.13D)
            RoundedRectangle(cornerRadius: eyeW * 0.25)
                .fill(Color.black)
                .frame(width: diameter * 0.20, height: diameter * 0.11)
                .frame(width: eyeW, height: eyeH)
        case .annoyed:
            RoundedRectangle(cornerRadius: eyeW / 2)
                .fill(Color.black)
                .frame(width: eyeW, height: eyeH)
                .scaleEffect(x: 1, y: blinkScale)
                .rotationEffect(.degrees(isLeft ? -16 : 16))
        default:
            RoundedRectangle(cornerRadius: eyeW / 2)
                .fill(Color.black)
                .frame(width: eyeW, height: eyeH * (state == .needsYes ? 1.28 : 1.0))
                .scaleEffect(x: 1, y: blinkScale)
        }
    }

    private var bodySquashX: CGFloat {
        switch state {
        case .annoyed: return 1.04
        case .talking: return talkPhase ? 1.03 : 1.0
        default: return 1.0
        }
    }

    private var bodySquashY: CGFloat {
        switch state {
        case .annoyed: return 0.93
        case .talking: return talkPhase ? 0.96 : 1.0
        default: return 1.0
        }
    }

    private func startIdleLife() {
        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
            breathY = -2
        }
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.4...5.0)))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.08)) { blinkScale = 0.08 }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.14)) { blinkScale = 1 }
            }
        }
    }
}

// MARK: - BallClickyFace (stateful wrapper: gaze + triple-tap annoyed + auto-recovery)

struct BallClickyFace: View {
    @ObservedObject var companion = CompanionManager.shared
    @ObservedObject private var coordinator = IzaViewCoordinator.shared
    var diameter: CGFloat = 72
    var showBadgeOverride: Bool? = nil
    var statusDotOverride: Color? = nil
    var interactive: Bool = true

    @State private var localGaze: CGSize = .zero
    @State private var overrideState: BallClickyState? = nil
    @State private var taps: [Date] = []

    private var resolved: BallClickyState {
        if let o = overrideState { return o }
        return BallClickyState.resolve(
            isProcessingTask: companion.isProcessingTask,
            isStreaming: companion.isHomeSpaceStreaming,
            voiceState: companion.voiceState,
            hasPendingConsent: companion.pendingComputerUseRequest != nil
        )
    }

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named("OpenNotchContainer"))
            let center = CGPoint(
                x: frame.midX > 0 ? frame.midX : diameter / 2,
                y: frame.midY > 0 ? frame.midY : diameter / 2
            )
            BallClickyView(
                state: resolved,
                diameter: diameter,
                gaze: notchGaze(center: center),
                showBadge: showBadgeOverride ?? (resolved == .working),
                proximity: notchProximity(center: center),
                statusDot: statusDotOverride
            )
        }
        .onContinuousHover { phase in
            guard interactive else { return }
            switch phase {
            case .active(let location):
                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.72)) {
                    localGaze = CGSize(
                        width: max(-0.5, min(0.5, location.x / diameter - 0.5)),
                        height: max(-0.5, min(0.5, location.y / diameter - 0.5))
                    )
                }
            case .ended:
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    localGaze = .zero
                }
            }
        }
        .onTapGesture {
            guard interactive else { return }
            let now = Date()
            taps = taps.filter { now.timeIntervalSince($0) < 2 } + [now]
            if taps.count >= 3 {
                taps = []
                triggerOverride(.annoyed, after: 1.4)
            }
        }
    }

    private func notchGaze(center: CGPoint) -> CGSize {
        if let mouse = coordinator.openNotchMouseLocation {
            return CGSize(
                width: max(-1, min(1, (mouse.x - center.x) / 240)),
                height: max(-1, min(1, (mouse.y - center.y) / 90))
            )
        }
        return localGaze
    }

    private func notchProximity(center: CGPoint) -> Bool {
        guard let mouse = coordinator.openNotchMouseLocation else { return false }
        let dx = mouse.x - center.x, dy = mouse.y - center.y
        return (dx * dx + dy * dy).squareRoot() < 120
    }

    private func triggerOverride(_ s: BallClickyState, after seconds: Double) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            overrideState = s
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                overrideState = nil
            }
        }
    }
}
