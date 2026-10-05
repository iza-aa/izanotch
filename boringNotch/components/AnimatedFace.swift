//
//  AnimatedFace.swift
//  boringNotch
//

import SwiftUI
import Combine
import AppKit
import Defaults

// MARK: - Face Expressions

enum FaceExpression: Equatable {
    case happy      // Default cheerful smile with tilted eyes
    case wink       // Winking one eye on hover/click
    case surprised  // Wide eyes, open 'O' mouth
    case curious    // Look up-right with sly smirk
    case chill      // Relaxed breathing
    case sad        // Drooped puppy eyes + downturned pout when hovering tabs
}

// MARK: - Animatable Smile Shape

struct AnimatableSmileShape: Shape {
    var smileDepth: Double    // Depth of curve: positive = smile, 0 = neutral, negative = pout/frown
    var smileWidth: Double    // Width of smile
    var mouthOpenness: Double // 0 = line, >0 = open mouth

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(smileDepth, AnimatablePair(smileWidth, mouthOpenness)) }
        set {
            smileDepth = newValue.first
            smileWidth = newValue.second.first
            mouthOpenness = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let startX = midX - smileWidth / 2
        let endX = midX + smileWidth / 2

        // Dynamic baseline so smiles curve down and frows curve up gracefully
        let baselineY = rect.midY - smileDepth * 0.35
        let controlY = baselineY + smileDepth

        path.move(to: CGPoint(x: startX, y: baselineY))
        path.addQuadCurve(
            to: CGPoint(x: endX, y: baselineY),
            control: CGPoint(x: midX, y: controlY)
        )

        if mouthOpenness > 0.5 {
            // Optional bottom loop for open mouth
            path.addQuadCurve(
                to: CGPoint(x: startX, y: baselineY),
                control: CGPoint(x: midX, y: controlY + mouthOpenness)
            )
        }

        return path
    }
}

// MARK: - Capsule Eye View (Flat Top/Bottom with Crisp Rounded Corners)

struct CapsuleEyeView: View {
    let isLeftEye: Bool
    let isBlinking: Bool
    let expression: FaceExpression
    let gazeDx: Double
    let gazeDy: Double
    let proximityBoost: Bool

    // Base dimensions for outer eye (crisp flat top and bottom with rounded corners)
    private var baseWidth: CGFloat {
        (expression == .surprised ? 19 : 17.5) * (proximityBoost ? 1.2 : 1.0)
    }

    private var baseHeight: CGFloat {
        if isBlinking { return 2.5 }
        return (expression == .surprised ? 32 : 27.5) * (proximityBoost ? 1.2 : 1.0)
    }

    // Balanced corner radius for soft organic squircle (not too boxy, not fully round)
    private var cornerRadius: CGFloat {
        isBlinking ? 1.25 : 6.5
    }

    // Inner pupil (matches outer eye curvature)
    private var pupilWidth: CGFloat {
        baseWidth * 0.58
    }

    private var pupilHeight: CGFloat {
        if isBlinking { return 0 }
        return baseHeight * 0.58
    }

    private var pupilCornerRadius: CGFloat {
        isBlinking ? 0 : 3.8
    }

    // Rotation based on expression
    private var eyeRotation: Double {
        switch expression {
        case .sad:
            // Drooped puppy eyes pleadingly
            return isLeftEye ? -12.0 : 12.0
        case .surprised:
            return 0.0
        default:
            return 20.0 + gazeDx * 5.0
        }
    }

    var body: some View {
        ZStack {
            // Outer Sclera (White rectangle with flat top/bottom and rounded corners)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
                .frame(width: baseWidth, height: baseHeight)

            // Inner Pupil (Black rectangle with flat top/bottom and rounded corners)
            if !isBlinking {
                RoundedRectangle(cornerRadius: pupilCornerRadius, style: .continuous)
                    .fill(Color.black)
                    .frame(width: pupilWidth, height: pupilHeight)
                    .offset(
                        x: CGFloat(expression == .sad ? -3.5 : (gazeDx * 3.8)),
                        y: CGFloat(expression == .sad ? -4.0 : (gazeDy * 4.5))
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 2.5, height: 2.5)
                            .offset(x: -1.5, y: 1.5)
                    }
                    .overlay(alignment: .bottomLeading) {
                        if expression == .sad {
                            // Tiny teary shimmer
                            Circle()
                                .fill(Color.cyan.opacity(0.8))
                                .frame(width: 2.0, height: 2.0)
                                .offset(x: 1.0, y: -1.0)
                        }
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .rotationEffect(.degrees(eyeRotation))
        .offset(
            x: CGFloat(expression == .sad ? -2.5 : (gazeDx * 3.5)),
            y: CGFloat(expression == .sad ? -2.0 : (gazeDy * 2.0))
        )
    }
}

// MARK: - Playful Animated Vector Face (4 Pillars Engine)

struct PlayfulAnimatedFaceView: View {
    var mouseLocationInHome: CGPoint? = nil

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @State private var expression: FaceExpression = .happy
    @State private var isLeftEyeBlinking: Bool = false
    @State private var isRightEyeBlinking: Bool = false
    @State private var idleTilt: Double = 0
    @State private var idleBreathY: CGFloat = 0
    @State private var isHovered: Bool = false

    private var unifiedMouseLocation: CGPoint? {
        coordinator.openNotchMouseLocation ?? mouseLocationInHome
    }

    private var isHeadingToTabs: Bool {
        coordinator.isHeadingToTabs
    }

    private var activeExpression: FaceExpression {
        if isHeadingToTabs { return .sad }
        return expression
    }

    var body: some View {
        GeometryReader { geo in
            let faceFrame = geo.frame(in: .named("OpenNotchContainer"))
            let faceCenter = CGPoint(x: faceFrame.midX > 0 ? faceFrame.midX : 70, y: faceFrame.midY > 0 ? faceFrame.midY : 110)

            let gaze = computeGaze(from: faceCenter, to: unifiedMouseLocation)
            let proximityBoost = computeProximity(distance: gaze.distance)

            VStack(spacing: 8) {
                // Eyes Row (Flat-top/bottom eyes with Gliding Pupils)
                HStack(spacing: 14) {
                    CapsuleEyeView(
                        isLeftEye: true,
                        isBlinking: isLeftEyeBlinking,
                        expression: activeExpression,
                        gazeDx: gaze.dx,
                        gazeDy: gaze.dy,
                        proximityBoost: proximityBoost
                    )

                    CapsuleEyeView(
                        isLeftEye: false,
                        isBlinking: isRightEyeBlinking,
                        expression: activeExpression,
                        gazeDx: gaze.dx,
                        gazeDy: gaze.dy,
                        proximityBoost: proximityBoost
                    )
                }

                // Smile Curve (Morphs into sad downturned pout when heading to tabs)
                AnimatableSmileShape(
                    smileDepth: smileDepth * (proximityBoost && activeExpression != .sad ? 1.3 : 1.0),
                    smileWidth: smileWidth,
                    mouthOpenness: mouthOpenness
                )
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 60, height: 18)
                .offset(x: activeExpression == .sad ? -2.0 : (gaze.dx * 3.0), y: activeExpression == .sad ? -1.0 : (gaze.dy * 2.0))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .rotationEffect(.degrees(activeExpression == .sad ? -6.0 : (idleTilt + gaze.dx * 6.5)))
            .offset(x: activeExpression == .sad ? -2.0 : (gaze.dx * 2.5), y: idleBreathY)
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.72), value: gaze.dx)
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.72), value: gaze.dy)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: activeExpression)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: proximityBoost)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    if hovering {
                        triggerWink()
                    } else {
                        expression = .happy
                    }
                }
            }
            .onTapGesture {
                triggerSurpriseAndWink()
            }
        }
        .onAppear {
            startIdleBreathing()
            startOrganicBlinking()
        }
    }

    private func computeGaze(from center: CGPoint, to mouse: CGPoint?) -> (dx: Double, dy: Double, distance: Double) {
        guard let mouse = mouse else { return (0, 0, 9999) }
        let deltaX = Double(mouse.x - center.x)
        let deltaY = Double(mouse.y - center.y)
        let dist = sqrt(deltaX * deltaX + deltaY * deltaY)

        let clampedDx = max(-1.0, min(1.0, deltaX / 240.0))
        let clampedDy = max(-1.0, min(1.0, deltaY / 90.0))
        return (clampedDx, clampedDy, dist)
    }

    private func computeProximity(distance: Double) -> Bool {
        return distance < 120.0
    }

    // Dynamic animation parameters based on expression
    private var smileDepth: Double {
        switch activeExpression {
        case .sad: return -12.0 // Downturned sad pout
        case .happy: return isHovered ? 20.0 : 16.0
        case .wink: return 18.0
        case .surprised: return 22.0
        case .curious: return 10.0
        case .chill: return 14.0
        }
    }

    private var smileWidth: Double {
        switch activeExpression {
        case .sad: return 34.0 // Smaller pouty mouth
        case .happy: return isHovered ? 52.0 : 46.0
        case .wink: return 48.0
        case .surprised: return 32.0
        case .curious: return 38.0
        case .chill: return 42.0
        }
    }

    private var mouthOpenness: Double {
        switch activeExpression {
        case .surprised: return 12.0
        default: return 0.0
        }
    }

    // MARK: - Animation Drivers

    private func triggerWink() {
        expression = .wink
        withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
            isRightEyeBlinking = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                isRightEyeBlinking = false
                expression = .happy
            }
        }
    }

    private func triggerSurpriseAndWink() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            expression = .surprised
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            triggerWink()
        }
    }

    private func startIdleBreathing() {
        withAnimation(
            .easeInOut(duration: 2.4)
            .repeatForever(autoreverses: true)
        ) {
            idleTilt = 2.0
            idleBreathY = -2.0
        }
    }

    private func startOrganicBlinking() {
        Task { @MainActor in
            while true {
                // Random natural delay between 2.4s and 4.8s
                let randomDelay = Double.random(in: 2.4...4.8)
                try? await Task.sleep(for: .seconds(randomDelay))
                guard !Task.isCancelled else { return }

                if expression == .happy || expression == .chill {
                    // Blink down
                    withAnimation(.spring(response: 0.1, dampingFraction: 0.8)) {
                        isLeftEyeBlinking = true
                        isRightEyeBlinking = true
                    }
                    try? await Task.sleep(for: .milliseconds(85))
                    // Blink up
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.65)) {
                        isLeftEyeBlinking = false
                        isRightEyeBlinking = false
                    }

                    // 18% chance of immediate realistic double-blink
                    if Double.random(in: 0...1) < 0.18 {
                        try? await Task.sleep(for: .milliseconds(90))
                        withAnimation(.spring(response: 0.08, dampingFraction: 0.8)) {
                            isLeftEyeBlinking = true
                            isRightEyeBlinking = true
                        }
                        try? await Task.sleep(for: .milliseconds(75))
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.65)) {
                            isLeftEyeBlinking = false
                            isRightEyeBlinking = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - GitHub Badge

struct GitHubOctocatPath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let sx = w / 24.0
        let sy = h / 24.0

        p.move(to: CGPoint(x: 12 * sx, y: 2 * sy))
        p.addCurve(to: CGPoint(x: 2 * sx, y: 12.017 * sy), control1: CGPoint(x: 6.477 * sx, y: 2 * sy), control2: CGPoint(x: 2 * sx, y: 6.484 * sy))
        p.addCurve(to: CGPoint(x: 8.839 * sx, y: 21.521 * sy), control1: CGPoint(x: 2 * sx, y: 16.442 * sy), control2: CGPoint(x: 4.865 * sx, y: 20.197 * sy))
        p.addCurve(to: CGPoint(x: 9.521 * sx, y: 21.038 * sy), control1: CGPoint(x: 9.339 * sx, y: 21.613 * sy), control2: CGPoint(x: 9.521 * sx, y: 21.304 * sy))
        p.addLine(to: CGPoint(x: 9.508 * sx, y: 19.335 * sy))
        p.addCurve(to: CGPoint(x: 6.139 * sx, y: 17.992 * sy), control1: CGPoint(x: 6.726 * sx, y: 19.94 * sy), control2: CGPoint(x: 6.139 * sx, y: 17.992 * sy))
        p.addCurve(to: CGPoint(x: 5.029 * sx, y: 16.526 * sy), control1: CGPoint(x: 5.685 * sx, y: 16.834 * sy), control2: CGPoint(x: 5.029 * sx, y: 16.526 * sy))
        p.addCurve(to: CGPoint(x: 5.098 * sx, y: 15.918 * sy), control1: CGPoint(x: 4.121 * sx, y: 15.906 * sy), control2: CGPoint(x: 5.098 * sx, y: 15.918 * sy))
        p.addCurve(to: CGPoint(x: 6.628 * sx, y: 16.95 * sy), control1: CGPoint(x: 6.101 * sx, y: 15.988 * sy), control2: CGPoint(x: 6.628 * sx, y: 16.95 * sy))
        p.addCurve(to: CGPoint(x: 9.538 * sx, y: 17.782 * sy), control1: CGPoint(x: 7.52 * sx, y: 18.48 * sy), control2: CGPoint(x: 8.969 * sx, y: 18.038 * sy))
        p.addCurve(to: CGPoint(x: 10.174 * sx, y: 16.444 * sy), control1: CGPoint(x: 9.63 * sx, y: 17.135 * sy), control2: CGPoint(x: 9.888 * sx, y: 16.694 * sy))
        p.addCurve(to: CGPoint(x: 5.619 * sx, y: 11.493 * sy), control1: CGPoint(x: 7.954 * sx, y: 16.191 * sy), control2: CGPoint(x: 5.619 * sx, y: 15.331 * sy))
        p.addCurve(to: CGPoint(x: 6.648 * sx, y: 8.805 * sy), control1: CGPoint(x: 5.619 * sx, y: 10.4 * sy), control2: CGPoint(x: 6.009 * sx, y: 9.505 * sy))
        p.addCurve(to: CGPoint(x: 6.746 * sx, y: 6.155 * sy), control1: CGPoint(x: 6.545 * sx, y: 8.552 * sy), control2: CGPoint(x: 6.202 * sx, y: 7.533 * sy))
        p.addCurve(to: CGPoint(x: 9.496 * sx, y: 7.181 * sy), control1: CGPoint(x: 7.586 * sx, y: 5.885 * sy), control2: CGPoint(x: 9.496 * sx, y: 7.181 * sy))
        p.addCurve(to: CGPoint(x: 12.0 * sx, y: 6.844 * sy), control1: CGPoint(x: 10.28 * sx, y: 6.963 * sy), control2: CGPoint(x: 11.13 * sx, y: 6.844 * sy))
        p.addCurve(to: CGPoint(x: 14.504 * sx, y: 7.181 * sy), control1: CGPoint(x: 12.85 * sx, y: 6.844 * sy), control2: CGPoint(x: 13.705 * sx, y: 6.963 * sy))
        p.addCurve(to: CGPoint(x: 17.254 * sx, y: 6.155 * sy), control1: CGPoint(x: 14.504 * sx, y: 7.181 * sy), control2: CGPoint(x: 16.414 * sx, y: 5.885 * sy))
        p.addCurve(to: CGPoint(x: 17.352 * sx, y: 8.805 * sy), control1: CGPoint(x: 17.8 * sx, y: 7.533 * sy), control2: CGPoint(x: 17.455 * sx, y: 8.552 * sy))
        p.addCurve(to: CGPoint(x: 18.38 * sx, y: 11.493 * sy), control1: CGPoint(x: 17.992 * sx, y: 9.505 * sy), control2: CGPoint(x: 18.38 * sx, y: 10.4 * sy))
        p.addCurve(to: CGPoint(x: 13.814 * sx, y: 16.436 * sy), control1: CGPoint(x: 18.38 * sx, y: 15.341 * sy), control2: CGPoint(x: 16.041 * sx, y: 16.188 * sy))
        p.addCurve(to: CGPoint(x: 14.492 * sx, y: 18.291 * sy), control1: CGPoint(x: 14.173 * sx, y: 16.745 * sy), control2: CGPoint(x: 14.492 * sx, y: 17.356 * sy))
        p.addLine(to: CGPoint(x: 14.48 * sx, y: 21.038 * sy))
        p.addCurve(to: CGPoint(x: 15.168 * sx, y: 21.521 * sy), control1: CGPoint(x: 14.48 * sx, y: 21.306 * sy), control2: CGPoint(x: 14.66 * sx, y: 21.618 * sy))
        p.addCurve(to: CGPoint(x: 22.0 * sx, y: 12.017 * sy), control1: CGPoint(x: 19.135 * sx, y: 20.197 * sy), control2: CGPoint(x: 22.0 * sx, y: 16.442 * sy))
        p.addCurve(to: CGPoint(x: 12.0 * sx, y: 2.0 * sy), control1: CGPoint(x: 22.0 * sx, y: 6.484 * sy), control2: CGPoint(x: 17.522 * sx, y: 2.0 * sy))
        p.closeSubpath()
        return p
    }
}

struct GitHubBadgeView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                .fill(Color(red: 18/255, green: 22/255, blue: 28/255))
                .frame(width: 26, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.65), radius: 4, x: 0, y: 2)

            GitHubOctocatPath()
                .fill(Color.white)
                .frame(width: 16, height: 16)
        }
        .offset(x: 6, y: 6)
    }
}

// MARK: - GitHub Contribution Grid View

struct GitHubContributionGridView: View {
    // 7 rows x 7 columns (Square matrix matching music album art)
    private let rows = 7
    private let cols = 7
    @State private var hoveredTileIndex: Int? = nil
    @ObservedObject private var githubManager = GitHubManager.shared

    var body: some View {
        GeometryReader { geo in
            let cardSize = min(geo.size.width, geo.size.height)
            let padding: CGFloat = 8.5
            let spacing: CGFloat = 3.2
            let availableSize = cardSize - (padding * 2)
            let tileSize = max(10.0, (availableSize - (spacing * CGFloat(cols - 1))) / CGFloat(cols))

            ZStack {
                // 1. Music Tab Style Ambient Glow Lighting Effect
                if Defaults[.lightingEffect] {
                    githubGlowBackground(cardSize: cardSize)
                }

                // 2. Foreground Glass Card & Matrix Grid
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.6), Color.black.opacity(0.38)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 2)

                    // Heatmap Grid
                    commitGridTiles(tileSize: tileSize, spacing: spacing, isInteractive: true)
                }
                .frame(width: cardSize, height: cardSize)
                .overlay(alignment: .bottomTrailing) {
                    GitHubBadgeView()
                }
            }
            .frame(width: cardSize, height: cardSize)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func githubGlowBackground(cardSize: CGFloat) -> some View {
        commitGridTiles(tileSize: 13, spacing: 3.2, isInteractive: false)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: Defaults[.cornerRadiusScaling]
                        ? MusicPlayerImageSizes.cornerRadiusInset.opened
                        : MusicPlayerImageSizes.cornerRadiusInset.closed
                )
            )
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(x: 1.3, y: 1.4)
            .blur(radius: 35)
            .opacity(0.7)
    }

    @ViewBuilder
    private func commitGridTiles(tileSize: CGFloat, spacing: CGFloat, isInteractive: Bool) -> some View {
        let days = githubManager.contributionDays
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<cols, id: \.self) { col in
                        // Column-major order: weeks across columns, days of week down rows
                        let index = (col * rows) + row
                        let day = index < days.count ? days[index] : nil
                        let level = day?.level ?? 0

                        tileShape(row: row, col: col)
                            .fill(colorForLevel(level))
                            .frame(width: tileSize, height: tileSize)
                            .conditionalModifier(isInteractive) { view in
                                view
                                    .overlay(
                                        tileShape(row: row, col: col)
                                            .stroke(hoveredTileIndex == index ? Color.white.opacity(0.9) : Color.clear, lineWidth: 1.2)
                                    )
                                    .scaleEffect(hoveredTileIndex == index ? 1.28 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: hoveredTileIndex == index)
                                    .help(day != nil && !day!.date.starts(with: "pad-") && !day!.date.starts(with: "sample-") ? "\(day!.date): \(day!.count) commit\(day!.count == 1 ? "" : "s")" : "GitHub Activity")
                                    .onHover { isHover in
                                        hoveredTileIndex = isHover ? index : nil
                                    }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tileShape(row: Int, col: Int) -> some Shape {
        let isTopLeft = (row == 0 && col == 0)
        let isTopRight = (row == 0 && col == cols - 1)
        let isBottomLeft = (row == rows - 1 && col == 0)
        let isBottomRight = (row == rows - 1 && col == cols - 1)

        UnevenRoundedRectangle(
            topLeadingRadius: isTopLeft ? 6.5 : 2.5,
            bottomLeadingRadius: isBottomLeft ? 6.5 : 2.5,
            bottomTrailingRadius: isBottomRight ? 6.5 : 2.5,
            topTrailingRadius: isTopRight ? 6.5 : 2.5,
            style: .continuous
        )
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return Color.white.opacity(0.08)
        case 1: return Color(red: 14/255, green: 68/255, blue: 41/255)   // #0e4429
        case 2: return Color(red: 0/255, green: 109/255, blue: 50/255)   // #006d32
        case 3: return Color(red: 38/255, green: 166/255, blue: 65/255)  // #26a641
        case 4: return Color(red: 57/255, green: 211/255, blue: 83/255)  // #39d353 (bright neon)
        default: return Color.white.opacity(0.08)
        }
    }
}

enum PokeReactionPhase {
    case none
    case angry   // Preset 25 (Marah, merah, getar, aura merah)
    case annoyed // Preset 22 (Bete, mata datar pipih, aura lembut)
}

// MARK: - Faint Concentric Green Pulse Wave View (Opsi B: Jarak 11px Seragam + Aura Hijau)
struct FaintConcentricGreenPulseView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let period: Double = 2.4
            let startRadius: CGFloat = 33.0
            let maxRadius: CGFloat = 66.0
            let ringSpacing: CGFloat = 11.0

            ZStack {
                // 1. Ambient Green Aura Glow (Stabil di tengah belakang karakter)
                Circle()
                    .fill(Color(hex: "#0F624C"))
                    .frame(width: 80, height: 80)
                    .blur(radius: 18)
                    .opacity(0.60)

                // 2. Garis-garis pudar berulang (garis yang sama) merambat keluar dengan jarak 11px
                ForEach(0..<4, id: \.self) { i in
                    let phaseOffset = Double(i) * (period / 4.0)
                    let prog = (t + phaseOffset).truncatingRemainder(dividingBy: period) / period
                    let radius = startRadius + CGFloat(prog) * (maxRadius - startRadius + ringSpacing)

                    if radius >= startRadius && radius <= maxRadius + 6.0 {
                        let edgeFade = min(1.0, (maxRadius + 6.0 - radius) / 12.0)
                        let spawnFade = min(1.0, (radius - startRadius) / 5.0)
                        let opacity = 0.36 * edgeFade * spawnFade

                        Circle()
                            .stroke(
                                Color(hex: "#34D399").opacity(opacity),
                                lineWidth: 1.3
                            )
                            .frame(width: radius * 2, height: radius * 2)
                            .blur(radius: 0.9)
                    }
                }
            }
            .frame(width: 76, height: 76)
            .allowsHitTesting(false)
        }
    }
}

struct GreetingFaceCardView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    let userName: String
    let rotatingQuote: String

    @State private var pokeReaction: PokeReactionPhase = .none
    @State private var pokeTask: Task<Void, Never>? = nil
    @State private var isCharaHovered: Bool = false
    @State private var isRoundEyesActive: Bool = false
    @State private var hoverHoldTask: Task<Void, Never>? = nil

    private var isHeadingToTabs: Bool {
        coordinator.isHeadingToTabs
    }

    private var resolvedExpression: String {
        switch pokeReaction {
        case .angry:
            return "preset-25" // Marah saat baru dipoke
        case .annoyed:
            return "preset-22" // Datar/bete beberapa detik setelah marah
        case .none:
            if isHeadingToTabs {
                return "preset-26" // Sedih saat kursor hover mau pindah tab/halaman
            } else if isRoundEyesActive {
                return "hover-focus-upright" // Pose 1:1 Foto + Slow Shake setelah jeda 0.5s!
            } else {
                return "neutral"
            }
        }
    }

    private var statusEmoji: String {
        switch pokeReaction {
        case .angry:
            return "💢"
        case .annoyed:
            return "😑"
        case .none:
            if isHeadingToTabs {
                return "🥺"
            } else if isRoundEyesActive {
                return "🤭"
            } else {
                return "👋"
            }
        }
    }

    private var currentSubtitle: String {
        switch pokeReaction {
        case .angry:
            return "Don't poke me!"
        case .annoyed:
            return "Hmph..."
        case .none:
            if isHeadingToTabs {
                return "Don't leave me..."
            } else if isRoundEyesActive {
                return "Stop tickling me!"
            } else {
                return rotatingQuote
            }
        }
    }

    private var subtitleColor: Color {
        switch pokeReaction {
        case .angry:
            return Color(hex: "#ba3636")
        case .annoyed:
            return Color(hex: "#9CA3AF")
        case .none:
            if isHeadingToTabs {
                return Color(hex: "#adc3ff")
            } else if isRoundEyesActive {
                return Color(hex: "#34D399")
            } else {
                return .white.opacity(0.65)
            }
        }
    }

    private var auraColor: Color {
        switch pokeReaction {
        case .angry:
            return Color(hex: "#ba3636")
        case .annoyed:
            return Color(hex: "#E8D2B4")
        case .none:
            if isHeadingToTabs {
                return Color.clear
            } else {
                return Color(hex: "#E8D2B4") // Warm golden halo 1:1 Foto 1
            }
        }
    }

    private var auraOpacity: Double {
        switch pokeReaction {
        case .angry:
            return 0.65
        case .annoyed:
            return 0.38
        case .none:
            if isHeadingToTabs {
                return 0.0 // Aura padam total saat mau ditinggal!
            } else if isRoundEyesActive {
                return 0.58 // Luminous glow saat pupil membulat tatap muka
            } else {
                return 0.45 // Soft ambient glow 1:1 Foto 1
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 4) {
                    Text("Hello \(userName)!")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(statusEmoji)
                        .font(.system(size: 12))
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: statusEmoji)
                }

                Text(currentSubtitle)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundColor(subtitleColor)
                    .animation(.easeInOut(duration: 0.25), value: currentSubtitle)
                    .lineLimit(1)
            }
            .padding(.top, 7)
            .padding(.horizontal, 8)

            Spacer(minLength: 0)

            HStack {
                Spacer()
                CompanionProceduralAvatarView(
                    definition: .defaultGrokBotWhite,
                    expressionName: resolvedExpression,
                    autoBlink: pokeReaction != .angry,
                    trackMouse: true,
                    size: 76
                )
                .background(
                    ZStack {
                        if isRoundEyesActive {
                            // Opsi B: Garis-garis pudar seragam (jarak 11px) berulang keluar + aura hijau
                            FaintConcentricGreenPulseView()
                                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        } else {
                            // Ambient Glow / Aura (1:1 Foto 1)
                            Circle()
                                .fill(auraColor)
                                .frame(width: 64, height: 64)
                                .blur(radius: 14)
                                .opacity(auraOpacity)
                                .allowsHitTesting(false)
                                .animation(.easeInOut(duration: 0.35), value: auraColor)
                                .animation(.easeInOut(duration: 0.35), value: auraOpacity)
                                .transition(.opacity)
                        }
                    }
                    .frame(width: 76, height: 76)
                    .allowsHitTesting(false)
                )
                .frame(width: 76, height: 76)
                .contentShape(Circle().inset(by: 7.5))
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        let dx = location.x - 38.0
                        let dy = location.y - 38.0
                        let isInside = (dx * dx + dy * dy) <= (30.4 * 30.4)
                        if isInside != isCharaHovered {
                            isCharaHovered = isInside
                            if isInside {
                                // Mulai jeda 0.5 detik sebelum pose foto & pulse aktif
                                hoverHoldTask?.cancel()
                                hoverHoldTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    guard !Task.isCancelled else { return }
                                    withAnimation(.easeInOut(duration: 0.65)) {
                                        isRoundEyesActive = true
                                    }
                                }
                            } else {
                                // Kursor keluar dari lingkaran karakter
                                hoverHoldTask?.cancel()
                                withAnimation(.easeInOut(duration: 0.4)) {
                                    isRoundEyesActive = false
                                }
                            }
                        }
                    case .ended:
                        hoverHoldTask?.cancel()
                        if isCharaHovered {
                            isCharaHovered = false
                        }
                        if isRoundEyesActive {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isRoundEyesActive = false
                            }
                        }
                    }
                }
                .onTapGesture {
                    triggerPoke()
                }
                .help("Grok Bot • White Edition (Klik untuk poke/ganggu)")
                Spacer()
            }
            .padding(.bottom, 6)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: isHeadingToTabs) { _, heading in
            if heading {
                hoverHoldTask?.cancel()
                isRoundEyesActive = false
            }
        }
    }

    private func triggerPoke() {
        hoverHoldTask?.cancel()
        isRoundEyesActive = false
        pokeTask?.cancel()
        pokeReaction = .angry
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }

        pokeTask = Task { @MainActor in
            // Fase 1: Marah selama 2.0 detik
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                pokeReaction = .annoyed
            }

            // Fase 2: Bete (Preset 22 Mata Datar) selama 2.2 detik
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                pokeReaction = .none
            }
        }
    }
}

// MARK: - Mini Month Calendar Widget View

struct MiniMonthCalendarView: View {
    @State private var displayedMonth: Date = Date()
    @State private var hoveredDate: Date? = nil

    private let calendar = Calendar.current
    private let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 2)

            VStack(spacing: 2) {
                // 1. Month & Year Header with navigation
                HStack(alignment: .center) {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            displayedMonth = Date()
                        }
                    }) {
                        Text(monthYearFormatter.string(from: displayedMonth))
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    HStack(spacing: 4) {
                        Button(action: {
                            changeMonth(by: -1)
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 16, height: 16)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            changeMonth(by: 1)
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 16, height: 16)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6.5)

                // 2. Day of Week Header (S M T W T F S)
                HStack(spacing: 0) {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 6)

                Spacer(minLength: 0)

                // 3. Month Date Grid
                let days = generateDaysInMonth(for: displayedMonth)
                VStack(spacing: 1.2) {
                    ForEach(0..<days.count / 7, id: \.self) { weekIndex in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                let date = days[weekIndex * 7 + dayIndex]
                                dayCell(date: date)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6.5)
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func dayCell(date: Date) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)
        let dayNumber = calendar.component(.day, from: date)

        ZStack(alignment: .center) {
            if isToday {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14.5, height: 14.5)
                    .shadow(color: Color.blue.opacity(0.6), radius: 2.5)
            } else if hoveredDate == date {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 14.5, height: 14.5)
            }

            Text("\(dayNumber)")
                .font(.system(size: 8.5, weight: isToday ? .bold : .medium, design: .rounded))
                .foregroundColor(
                    isToday ? .white : (isCurrentMonth ? .white.opacity(0.85) : .white.opacity(0.22))
                )
                .multilineTextAlignment(.center)
        }
        .frame(width: 15, height: 13, alignment: .center)
        .contentShape(Rectangle())
        .onHover { isHover in
            hoveredDate = isHover ? date : nil
        }
    }

    private func changeMonth(by amount: Int) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            if let newDate = calendar.date(byAdding: .month, value: amount, to: displayedMonth) {
                displayedMonth = newDate
            }
        }
    }

    private func generateDaysInMonth(for date: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let startOfMonth = monthInterval.start

        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = firstWeekday - 1

        var days: [Date] = []

        for i in (1...leadingDays).reversed() {
            if let prevDate = calendar.date(byAdding: .day, value: -i, to: startOfMonth) {
                days.append(prevDate)
            }
        }

        guard let range = calendar.range(of: .day, in: .month, for: date) else { return days }
        for i in 0..<range.count {
            if let currentDay = calendar.date(byAdding: .day, value: i, to: startOfMonth) {
                days.append(currentDay)
            }
        }

        let totalCells = (days.count <= 35) ? 35 : 42
        let trailingDays = totalCells - days.count
        if let lastDay = days.last {
            for i in 1...trailingDays {
                if let nextDate = calendar.date(byAdding: .day, value: i, to: lastDay) {
                    days.append(nextDate)
                }
            }
        }

        return days
    }
}

// MARK: - Timer Scroll Monitor via NSEvent (Controlled, Smooth Trackpad / Mouse Scroll)

struct TimerScrollMonitor: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> TimerScrollNSView {
        let view = TimerScrollNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: TimerScrollNSView, context: Context) {
        nsView.onScroll = onScroll
    }

    class TimerScrollNSView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var monitor: Any?
        private var accumulatedDelta: CGFloat = 0
        private var lastStepTime: TimeInterval = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                installMonitor()
            } else {
                removeMonitor()
            }
        }

        func installMonitor() {
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
                guard let self = self, event.window === self.window else { return event }
                guard BoringViewCoordinator.shared.isHoveringTimerCard else { return event }

                // Ignore momentum phase events so it doesn't spin out of control after releasing fingers
                if event.momentumPhase.contains(.changed) || event.momentumPhase.contains(.began) {
                    return nil
                }

                let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
                self.accumulatedDelta += delta

                let now = ProcessInfo.processInfo.systemUptime
                // Deliberate threshold for controlled, smooth number stepping
                let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 18.0 : 1.2
                let minStepInterval: TimeInterval = 0.08

                if abs(self.accumulatedDelta) >= threshold && (now - self.lastStepTime >= minStepInterval) {
                    let dir = self.accumulatedDelta
                    self.accumulatedDelta = 0
                    self.lastStepTime = now
                    self.onScroll?(dir)
                }
                return nil
            }
        }

        func removeMonitor() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            accumulatedDelta = 0
            lastStepTime = 0
        }

        deinit {
            removeMonitor()
        }
    }
}

// MARK: - Time Unit & Interactive Wheel Column

enum TimeUnit {
    case hours, minutes, seconds

    var suffix: String {
        switch self {
        case .hours: return "h"
        case .minutes: return "m"
        case .seconds: return "s"
        }
    }

    var maxValue: Int {
        switch self {
        case .hours: return 23
        case .minutes, .seconds: return 59
        }
    }
}

struct TimerWheelColumn: View {
    let unit: TimeUnit
    @Binding var value: Int
    let isHoveredUnit: Bool
    let onHoverUnit: () -> Void

    @State private var hoveredRow: Int? = nil // -1: top, 1: bottom

    private var prevValue: Int {
        (value - 1 + (unit.maxValue + 1)) % (unit.maxValue + 1)
    }

    private var nextValue: Int {
        (value + 1) % (unit.maxValue + 1)
    }

    var body: some View {
        VStack(spacing: 1.5) {
            // Top Row: Previous value (Click to decrease)
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                    value = prevValue
                }
            }) {
                Text("\(prevValue)\(unit.suffix)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(hoveredRow == -1 ? .white.opacity(0.85) : .white.opacity(0.35))
                    .frame(width: 26, height: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isH in hoveredRow = isH ? -1 : nil }

            // Middle Row: Current active value (White & Crisp like iOS Clock)
            Text("\(value)\(unit.suffix)")
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 26, height: 16)

            // Bottom Row: Next value (Click to increase)
            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                    value = nextValue
                }
            }) {
                Text("\(nextValue)\(unit.suffix)")
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundColor(hoveredRow == 1 ? .white.opacity(0.85) : .white.opacity(0.35))
                    .frame(width: 26, height: 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { isH in hoveredRow = isH ? 1 : nil }
        }
        .frame(width: 28)
        .contentShape(Rectangle())
        .onHover { isH in
            if isH {
                onHoverUnit()
            }
        }
    }
}

// MARK: - Quick Timer Widget View

struct QuickTimerView: View {
    @ObservedObject var timerManager = BoringTimerManager.shared
    var animationNamespace: Namespace.ID? = nil
    @State private var hoveredUnit: TimeUnit = .minutes
    @State private var hapticsTrigger: Int = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.65), Color.black.opacity(0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(
                            timerManager.isCompleted
                                ? Color.green.opacity(0.85)
                                : (timerManager.isRunning ? Color.orange.opacity(0.6) : Color.white.opacity(0.12)),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 2)

            VStack(spacing: 0) {
                // 1. Header: "Timer" (Rata Kiri, Putih)
                HStack {
                    Text("Timer")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 9)
                .padding(.top, 6.5)

                if timerManager.isRunning {
                    // Running Mode: Angka dan tombol bulat berada dead-center di tengah kartu
                    Spacer(minLength: 0)

                    VStack(spacing: 7) {
                        // Digital Countdown Text (Besar & Oranye #FF7F00)
                        Text(timerManager.formatCountdown())
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 127/255, blue: 0.0))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .conditionalModifier(animationNamespace != nil) { view in
                                view.matchedGeometryEffect(id: "timerCountdownDigits", in: animationNamespace!)
                            }

                        // Circular Action Controls (Pause & Cancel)
                        HStack(spacing: 14) {
                            // Pause / Resume circular button
                            Button(action: {
                                if Defaults[.enableHaptics] {
                                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                                }
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                    timerManager.togglePauseResume()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.38, green: 0.20, blue: 0.04))
                                        .frame(width: 27, height: 27)
                                        .overlay(
                                            Circle()
                                                .stroke(Color(red: 1.0, green: 127/255, blue: 0.0).opacity(0.4), lineWidth: 0.8)
                                        )
                                    Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(Color(red: 1.0, green: 127/255, blue: 0.0))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .conditionalModifier(animationNamespace != nil) { view in
                                view.matchedGeometryEffect(id: "timerPauseBtn", in: animationNamespace!)
                            }

                            // Cancel / X circular button
                            Button(action: {
                                if Defaults[.enableHaptics] {
                                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                                }
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    timerManager.stop()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 27, height: 27)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .conditionalModifier(animationNamespace != nil) { view in
                                view.matchedGeometryEffect(id: "timerCancelBtn", in: animationNamespace!)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                } else {
                    // Setup Mode: Spacer di atas & di bawah agar Time Wheel berada dead-center di tengah kartu
                    Spacer(minLength: 0)

                    // 2. Interactive Time Wheel
                    ZStack {
                        // Middle Row Highlight Pill (Dark Translucent Gray like iOS Clock)
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 90, height: 20)

                        HStack(spacing: 2) {
                            TimerWheelColumn(
                                unit: .hours,
                                value: $timerManager.hours,
                                isHoveredUnit: hoveredUnit == .hours,
                                onHoverUnit: { hoveredUnit = .hours }
                            )
                            TimerWheelColumn(
                                unit: .minutes,
                                value: $timerManager.minutes,
                                isHoveredUnit: hoveredUnit == .minutes,
                                onHoverUnit: { hoveredUnit = .minutes }
                            )
                            TimerWheelColumn(
                                unit: .seconds,
                                value: $timerManager.seconds,
                                isHoveredUnit: hoveredUnit == .seconds,
                                onHoverUnit: { hoveredUnit = .seconds }
                            )
                        }
                    }
                    .frame(height: 46)

                    Spacer(minLength: 0)

                    // 3. Action Presets (1m, 5m) & Apple Green Start Button
                    HStack(alignment: .center) {
                        // Rata kiri: 1m & 5m
                        HStack(spacing: 3.5) {
                            Button(action: {
                                if Defaults[.enableHaptics] {
                                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                                }
                                timerManager.setPreset(hours: 0, minutes: 1, seconds: 0)
                            }) {
                                Text("1m")
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundColor(timerManager.isMatchingPreset(h: 0, m: 1, s: 0) ? .black : .white)
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 4.5)
                                    .background(
                                        Capsule()
                                            .fill(timerManager.isMatchingPreset(h: 0, m: 1, s: 0) ? Color.white : Color.white.opacity(0.12))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                if Defaults[.enableHaptics] {
                                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                                }
                                timerManager.setPreset(hours: 0, minutes: 5, seconds: 0)
                            }) {
                                Text("5m")
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundColor(timerManager.isMatchingPreset(h: 0, m: 5, s: 0) ? .black : .white)
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 4.5)
                                    .background(
                                        Capsule()
                                            .fill(timerManager.isMatchingPreset(h: 0, m: 5, s: 0) ? Color.white : Color.white.opacity(0.12))
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Spacer()

                        // Rata kanan: Start Button in Apple Clock Dark Green Pill
                        Button(action: {
                            if Defaults[.enableHaptics] {
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            }
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                timerManager.start()
                            }
                        }) {
                            Text("Start")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.28, green: 0.90, blue: 0.42))
                                .padding(.vertical, 3)
                                .padding(.horizontal, 7)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.08, green: 0.30, blue: 0.14))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color(red: 0.28, green: 0.90, blue: 0.42).opacity(0.35), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 6.5)
                    .padding(.horizontal, 7)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .sensoryFeedback(.selection, trigger: hapticsTrigger)
        .background(
            TimerScrollMonitor(onScroll: handleScroll)
        )
        .onHover { isHovering in
            BoringViewCoordinator.shared.isHoveringTimerCard = isHovering
        }
    }

    private func handleScroll(delta: CGFloat) {
        guard !timerManager.isRunning else { return }
        if Defaults[.enableHaptics] {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            hapticsTrigger += 1
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            switch hoveredUnit {
            case .hours:
                if delta > 0 {
                    timerManager.hours = (timerManager.hours - 1 + 24) % 24
                } else {
                    timerManager.hours = (timerManager.hours + 1) % 24
                }
            case .minutes:
                if delta > 0 {
                    timerManager.minutes = (timerManager.minutes - 1 + 60) % 60
                } else {
                    timerManager.minutes = (timerManager.minutes + 1) % 60
                }
            case .seconds:
                if delta > 0 {
                    timerManager.seconds = (timerManager.seconds - 1 + 60) % 60
                } else {
                    timerManager.seconds = (timerManager.seconds + 1) % 60
                }
            }
        }
    }
}

// MARK: - Native Calendar Card View (Integrated Calendar from BoringCalendar)

struct NativeCalendarCardView: View {
    @EnvironmentObject var vm: BoringViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.65), Color.black.opacity(0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            CalendarView()
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .environmentObject(vm)
        }
    }
}

// MARK: - Home Greeting Main View (4-Card Experience)

struct HomeGreetingView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared
    var animationNamespace: Namespace.ID? = nil
    @State private var quoteIndex: Int = 0

    private let userName: String = {
        let full = NSFullUserName()
        if !full.isEmpty && full != "User" { return full.components(separatedBy: " ").first ?? "Heizaa" }
        return "Heizaa"
    }()

    private let rotatingQuotes: [String] = [
        "How are you today",
        "Ready to build something great?",
        "Keep pushing, great progress!",
        "Simplicity is the soul of efficiency.",
        "Code. Create. Inspire."
    ]

    private let timer = Timer.publish(every: 8.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Card 1: GitHub Contribution Matrix with Badge & Music-Style Ambient Glow (Far Left)
            GitHubContributionGridView()

            // Card 2: Combined Greeting & Animated Face Card (Middle Left) OR Live Mirror Camera View
            Group {
                if vm.isCameraExpanded {
                    CameraPreviewView(webcamManager: webcamManager)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                } else {
                    GreetingFaceCardView(
                        userName: userName,
                        rotatingQuote: rotatingQuotes[quoteIndex]
                    )
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }

            // Card 3: Native Calendar Widget Card (Middle Right - Full Height)
            NativeCalendarCardView()
                .environmentObject(vm)
                .frame(maxWidth: .infinity)

            // Card 4: Quick Timer Widget Card (Far Right - Full Height)
            QuickTimerView(animationNamespace: animationNamespace)
                .frame(width: 112)
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: "HomeGreetingContainer")
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.isCameraExpanded)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                quoteIndex = (quoteIndex + 1) % rotatingQuotes.count
            }
        }
    }
}



// MARK: - Legacy Minimal Face Features (Kept for Closed Notch Animation)

struct MinimalFaceFeatures: View {
    @State private var isBlinking = false
    @State var height: CGFloat = 20
    @State var width: CGFloat = 30

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Eye(isBlinking: $isBlinking)
                Eye(isBlinking: $isBlinking)
            }
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 3, height: 4)
                GeometryReader { geometry in
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height
                        path.move(to: CGPoint(x: 0, y: height / 2))
                        path.addQuadCurve(to: CGPoint(x: width, y: height / 2), control: CGPoint(x: width / 2, y: height))
                    }
                    .stroke(Color.white, lineWidth: 2)
                }
                .frame(width: 14, height: 10)
            }
        }
        .frame(width: self.width, height: self.height)
        .onAppear {
            startBlinking()
        }
    }

    func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            withAnimation(.spring(duration: 0.2)) {
                isBlinking = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(duration: 0.2)) {
                    isBlinking = false
                }
            }
        }
    }
}

struct Eye: View {
    @Binding var isBlinking: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white)
            .frame(width: 4, height: isBlinking ? 1 : 4)
            .frame(maxWidth: 15, maxHeight: 15)
            .animation(.easeInOut(duration: 0.1), value: isBlinking)
    }
}
