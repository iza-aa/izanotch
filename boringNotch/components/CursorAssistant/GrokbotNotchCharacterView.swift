//
//  GrokbotNotchCharacterView.swift
//  boringNotch (Izanotchy)
//
//  Grokbot Character Engine (Novra Model Adaptation)
//  Phase 1: Pure White Grokbot for Notch with 3D Spherical Eye Projection,
//  Spherical Limb Clipping (Foto 1), Hierarchical Slap Engine (Foto 2 & 3),
//  Zero Idle Glow, and Modular Eye Personalities (Foto 5).
//
//  NOTE: This file is a self-contained, drop-in component. It does NOT
//  alter existing Notch views until tested, reviewed, and approved.
//

import SwiftUI
import AppKit

// MARK: - GrokbotState (Novra State Machine Graph - Foto 2 & 3)

public enum GrokbotState: Equatable, Sendable {
    case idle        // Pure white sphere, zero glow, natural blink and gentle breathing
    case working     // Blue task pill badge, gentle work bob, soft cyan aura
    case talking     // Streaming reply bounce
    case needsYes    // Consent request (amber halo)
    case slap1       // 1st slap: recoil startle bob (recovers in 0.6s)
    case slap2       // 2nd slap: annoyed inward squint tilt (recovers in 1.2s)
    case dizzy       // 3rd slap: dizzy head wobble with orbiting stars (auto-recover 2.6s)
    case error       // Horizontal dash eyes, soft pink/red wash at bottom, red status dot
    case finished    // Happy upward curved eyes, green status dot (auto-recover 3.0s)
}

// MARK: - GrokbotEyePersonality (Foto 5 Capsule Roster)

public enum GrokbotEyePersonality: String, CaseIterable, Identifiable, Sendable {
    case grokbotPill = "Grokbot Pill"       // Default pill/capsule (Foto 1 & 4)
    case tiltedFocused = "Tilted Focused"   // Tilted dashes / / (Foto 5)
    case sleepySlit = "Sleepy Slit"         // Dot and horizontal dash • — (Foto 5)
    case roundInquisitive = "Inquisitive"   // Round dots • • (Foto 5)

    public var id: String { rawValue }
}

// MARK: - Happy Smiling Eye Shape (⌒)

public struct GrokbotSmilingEyeShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX, y: rect.maxY)
        let control = CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.15)
        let end = CGPoint(x: rect.maxX, y: rect.maxY)

        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

// MARK: - GrokbotNotchCharacterView (Core Production Component)

public struct GrokbotNotchCharacterView: View {
    public var diameter: CGFloat = 72
    public var state: GrokbotState = .idle
    public var personality: GrokbotEyePersonality = .grokbotPill
    public var gaze: CGSize = .zero                // Normalized -1.0 ... 1.0
    public var showBadge: Bool = false
    public var statusDot: Color? = nil
    public var onTap: (() -> Void)? = nil

    @State private var blinkScaleY: CGFloat = 1.0
    @State private var breathingY: CGFloat = 0.0
    @State private var talkPhase: Bool = false
    @State private var dizzyOrbitAngle: Double = 0.0
    @State private var shakeOffset: CGFloat = 0.0

    public init(
        diameter: CGFloat = 72,
        state: GrokbotState = .idle,
        personality: GrokbotEyePersonality = .grokbotPill,
        gaze: CGSize = .zero,
        showBadge: Bool = false,
        statusDot: Color? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.diameter = diameter
        self.state = state
        self.personality = personality
        self.gaze = gaze
        self.showBadge = showBadge
        self.statusDot = statusDot
        self.onTap = onTap
    }

    // MARK: - Mathematical Spherical Projection Constants (Foto 1)
    private var radius: CGFloat { diameter / 2.0 }
    private var eyeBaseW: CGFloat { diameter * 0.142 }
    private var eyeBaseH: CGFloat { diameter * 0.288 }
    private var maxYaw: CGFloat { 0.72 }          // ~41.2° max horizontal gaze angle
    private var maxPitch: CGFloat { 0.38 }        // ~21.8° max vertical gaze angle
    private var halfEyeSep: CGFloat { 0.38 }      // ~21.8° separation between eyes

    // MARK: - Clamped Dynamic Angles
    private var clampedGX: CGFloat { max(-1.0, min(1.0, gaze.width)) }
    private var clampedGY: CGFloat { max(-1.0, min(1.0, gaze.height)) }
    private var centerYaw: CGFloat { clampedGX * maxYaw }
    private var centerPitch: CGFloat { clampedGY * maxPitch }
    private var baselineY: CGFloat { radius + diameter * 0.02 }

    // MARK: - Left Eye 3D Coordinates & Foreshortening
    private var yawLeft: CGFloat { centerYaw - halfEyeSep }
    private var xLeft: CGFloat { radius + radius * sin(yawLeft) }
    private var yLeft: CGFloat { baselineY + radius * sin(centerPitch) }
    private var scaleXLeft: CGFloat { max(0.18, cos(yawLeft)) }

    // MARK: - Right Eye 3D Coordinates & Foreshortening
    private var yawRight: CGFloat { centerYaw + halfEyeSep }
    private var xRight: CGFloat { radius + radius * sin(yawRight) }
    private var yRight: CGFloat { baselineY + radius * sin(centerPitch) }
    private var scaleXRight: CGFloat { max(0.18, cos(yawRight)) }

    // MARK: - Body Gradients (Pure White Default, Zero Idle Glow)
    private var bodyGradient: LinearGradient {
        switch state {
        case .error:
            // Soft pink/red wash at bottom (Foto 3)
            return LinearGradient(
                colors: [Color.white, Color(red: 1.0, green: 0.94, blue: 0.94), Color(red: 0.99, green: 0.78, blue: 0.78)],
                startPoint: .top, endPoint: .bottom
            )
        case .working, .talking:
            // Subtle cyan wash at bottom
            return LinearGradient(
                colors: [Color.white, Color(red: 0.94, green: 0.98, blue: 1.0), Color(red: 0.73, green: 0.90, blue: 0.99)],
                startPoint: .top, endPoint: .bottom
            )
        case .needsYes:
            // Warm amber wash
            return LinearGradient(
                colors: [Color.white, Color(red: 1.0, green: 0.98, blue: 0.92), Color(red: 0.99, green: 0.90, blue: 0.54)],
                startPoint: .top, endPoint: .bottom
            )
        default:
            // Pure White Grokbot with soft bottom ambient occlusion (Foto 4)
            return LinearGradient(
                colors: [Color.white, Color(red: 0.97, green: 0.97, blue: 0.98), Color(red: 0.90, green: 0.90, blue: 0.91)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Aura Glow (ZERO GLOW during idle, glowing only on active triggers)
    private var haloColor: Color {
        switch state {
        case .working, .talking:
            return Color(red: 56/255, green: 189/255, blue: 248/255, opacity: 0.28)
        case .needsYes:
            return Color(red: 251/255, green: 191/255, blue: 36/255, opacity: 0.30)
        case .error:
            return Color(red: 239/255, green: 68/255, blue: 68/255, opacity: 0.28)
        case .finished:
            return Color(red: 34/255, green: 197/255, blue: 94/255, opacity: 0.28)
        default:
            return Color.clear // NO GLOW on Idle or Slap
        }
    }

    public var body: some View {
        ZStack {
            // Trigger-only Ambient Glow Aura
            if haloColor != Color.clear {
                Circle()
                    .fill(haloColor)
                    .blur(radius: diameter * 0.16)
                    .frame(width: diameter * 1.30, height: diameter * 1.30)
            }

            // Head Sphere Structure
            ZStack {
                // Sphere Base Body
                Circle()
                    .fill(bodyGradient)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: Color.black.opacity(0.10), radius: diameter * 0.04, x: 0, y: diameter * 0.025)

                // MARK: - 3D Eyes Layer with Spherical Limb Clipping (Foto 1)
                ZStack {
                    // Left Eye
                    eyeView(isLeft: true)
                        .scaleEffect(x: scaleXLeft, y: blinkScaleY)
                        .position(x: xLeft, y: yLeft)

                    // Right Eye
                    eyeView(isLeft: false)
                        .scaleEffect(x: scaleXRight, y: blinkScaleY)
                        .position(x: xRight, y: yRight)
                }
                .frame(width: diameter, height: diameter)
                .clipShape(Circle()) // Exact mathematical limb cutoff along sphere boundary
            }
            .scaleEffect(x: bodySquashX, y: bodySquashY)
            .offset(x: shakeOffset + (state == .dizzy ? cos(dizzyOrbitAngle) * 3.5 : 0),
                    y: breathingY + (state == .dizzy ? sin(dizzyOrbitAngle) * 2.5 : 0))

            // MARK: - Dizzy Orbiting Stars (Foto 2 & 3)
            if state == .dizzy {
                ForEach(0..<3, id: \.self) { i in
                    let angle = dizzyOrbitAngle + Double(i) * (2.0 * .pi / 3.0)
                    let starX = cos(angle) * (diameter * 0.44)
                    let starY = sin(angle) * (diameter * 0.18) - (diameter * 0.48)
                    Image(systemName: "sparkle")
                        .font(.system(size: max(8, diameter * 0.14), weight: .bold))
                        .foregroundColor(Color(red: 0.98, green: 0.80, blue: 0.08))
                        .offset(x: starX, y: starY)
                        .scaleEffect(0.85 + 0.25 * sin(angle * 2))
                }
            }

            // MARK: - Working Speech Pill Badge (Foto 3)
            if showBadge || state == .working {
                HStack(spacing: diameter * 0.024) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.white)
                            .frame(width: diameter * 0.038, height: diameter * 0.038)
                    }
                }
                .padding(.horizontal, diameter * 0.065)
                .padding(.vertical, diameter * 0.035)
                .background(
                    Capsule()
                        .fill(Color(red: 0.05, green: 0.65, blue: 0.91))
                        .shadow(color: Color(red: 0.05, green: 0.65, blue: 0.91).opacity(0.4), radius: 4, x: 0, y: 1)
                )
                .offset(x: -diameter * 0.34, y: -diameter * 0.42)
            }

            // MARK: - Status Indicators (Foto 3)
            if let dot = statusDot {
                Circle()
                    .fill(dot)
                    .frame(width: diameter * 0.11, height: diameter * 0.11)
                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.2))
                    .offset(x: diameter * 0.32, y: -diameter * 0.34)
            } else if state == .error {
                Circle()
                    .fill(Color(red: 0.94, green: 0.27, blue: 0.27))
                    .frame(width: diameter * 0.11, height: diameter * 0.11)
                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.2))
                    .offset(x: diameter * 0.32, y: -diameter * 0.34)
            } else if state == .finished {
                Circle()
                    .fill(Color(red: 0.13, green: 0.77, blue: 0.37))
                    .frame(width: diameter * 0.11, height: diameter * 0.11)
                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.2))
                    .offset(x: diameter * 0.32, y: -diameter * 0.34)
            }
        }
        .frame(width: diameter * 1.30, height: diameter * 1.30)
        .contentShape(Circle())
        .onTapGesture {
            onTap?()
        }
        .onAppear {
            startBreathingAndBlinking()
        }
        .onChange(of: state) { _, newState in
            handleStateTransition(newState)
        }
    }

    // MARK: - Eye Shape Rendering based on State & Personality (Foto 3 & 5)

    @ViewBuilder
    private func eyeView(isLeft: Bool) -> some View {
        switch state {
        case .error:
            // Horizontal sleepy dashes (Foto 3)
            Capsule()
                .fill(Color.black)
                .frame(width: eyeBaseW * 1.35, height: eyeBaseH * 0.32)

        case .finished:
            // Happy smiling curved eyes
            GrokbotSmilingEyeShape()
                .stroke(Color.black, style: StrokeStyle(lineWidth: max(2.0, eyeBaseW * 0.28), lineCap: .round))
                .frame(width: eyeBaseW * 1.25, height: eyeBaseH * 0.65)

        case .dizzy:
            // Dizzy spinning eye asterisks (Foto 2 & 3)
            Image(systemName: "asterisk")
                .font(.system(size: eyeBaseW * 1.25, weight: .black))
                .foregroundColor(Color.black)
                .rotationEffect(.degrees(dizzyOrbitAngle * 45))

        case .slap2:
            // Annoyed squinting inward tilt
            Capsule()
                .fill(Color.black)
                .frame(width: eyeBaseW, height: eyeBaseH * 0.85)
                .rotationEffect(.degrees(isLeft ? -22 : 22))

        default:
            // Personality variations (Foto 5)
            switch personality {
            case .grokbotPill:
                Capsule()
                    .fill(Color.black)
                    .frame(width: eyeBaseW, height: eyeBaseH)

            case .tiltedFocused:
                Capsule()
                    .fill(Color.black)
                    .frame(width: eyeBaseW, height: eyeBaseH * 0.95)
                    .rotationEffect(.degrees(-18))

            case .sleepySlit:
                if isLeft {
                    Circle()
                        .fill(Color.black)
                        .frame(width: eyeBaseW * 0.95, height: eyeBaseW * 0.95)
                } else {
                    Capsule()
                        .fill(Color.black)
                        .frame(width: eyeBaseW * 1.35, height: eyeBaseH * 0.32)
                }

            case .roundInquisitive:
                Circle()
                    .fill(Color.black)
                    .frame(width: eyeBaseW * 1.05, height: eyeBaseW * 1.05)
            }
        }
    }

    // MARK: - Body Squashes

    private var bodySquashX: CGFloat {
        switch state {
        case .slap1: return 1.07
        case .slap2: return 1.04
        case .talking: return talkPhase ? 1.03 : 1.0
        default: return 1.0
        }
    }

    private var bodySquashY: CGFloat {
        switch state {
        case .slap1: return 0.92
        case .slap2: return 0.94
        case .talking: return talkPhase ? 0.97 : 1.0
        default: return 1.0
        }
    }

    // MARK: - Life Animations

    private func startBreathingAndBlinking() {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            breathingY = -2.0
        }

        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 2.8...5.5)))
                guard !Task.isCancelled else { return }
                guard state != .error && state != .dizzy else { continue }

                withAnimation(.easeIn(duration: 0.08)) {
                    blinkScaleY = 0.08
                }
                try? await Task.sleep(for: .milliseconds(115))
                withAnimation(.easeOut(duration: 0.12)) {
                    blinkScaleY = 1.0
                }
            }
        }
    }

    private func handleStateTransition(_ newState: GrokbotState) {
        if newState == .dizzy {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                dizzyOrbitAngle = .pi * 2
            }
        } else {
            dizzyOrbitAngle = 0.0
        }

        if newState == .slap2 {
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3).repeatCount(3, autoreverses: true)) {
                shakeOffset = 3.5
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                shakeOffset = 0.0
            }
        }

        if newState == .talking {
            withAnimation(.easeInOut(duration: 0.25).repeatForever(autoreverses: true)) {
                talkPhase = true
            }
        } else {
            talkPhase = false
        }
    }
}
