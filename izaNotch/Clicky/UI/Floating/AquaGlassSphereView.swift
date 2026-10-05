//
//  AquaGlassSphereView.swift
//  izaNotch (Izanotchy)
//
//  Floating Aqua-Glass companion sphere that lives on the right side of the screen.
//  Features an expressive animated Clicky character with interactive eye-tracking pupils,
//  blinking animations, and instant trigger to open Home Space.
//

import SwiftUI
import Defaults

struct AquaGlassSphereView: View {
    @ObservedObject var companion = CompanionManager.shared
    @State private var isHovered = false
    @State private var isBlinking = false
    @State private var eyeOffsetX: CGFloat = 0
    @State private var eyeOffsetY: CGFloat = 0
    @State private var blinkTimer: Timer?

    var onToggleHomeSpace: () -> Void

    var body: some View {
        ZStack {
            // Outer ambient glow ring when AI is thinking or speaking
            if companion.voiceState == .listening || companion.voiceState == .processing || companion.voiceState == .responding {
                Circle()
                    .stroke(DS.Colors.overlayCursorBlue.opacity(0.6), lineWidth: 3)
                    .frame(width: 54, height: 54)
                    .blur(radius: 4)
                    .scaleEffect(isHovered ? 1.12 : 1.05)
            }

            // Liquid Aqua-Glass Base Sphere
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(white: 0.25).opacity(0.65),
                            Color.black.opacity(0.85)
                        ]),
                        center: .topLeading,
                        startRadius: 4,
                        endRadius: 36
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    DS.Colors.overlayCursorBlue.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 4)

            // Specular Reflection Highlight (Glass Sheen)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 24, height: 12)
                .offset(y: -14)

            // Clicky Character Face Inside Sphere
            VStack(spacing: 2) {
                // Eyes
                HStack(spacing: 9) {
                    // Left Eye
                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 5, height: isBlinking ? 1 : 6)
                        if !isBlinking {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 2.8, height: 2.8)
                                .offset(x: eyeOffsetX, y: eyeOffsetY)
                        }
                    }

                    // Right Eye
                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 5, height: isBlinking ? 1 : 6)
                        if !isBlinking {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 2.8, height: 2.8)
                                .offset(x: eyeOffsetX, y: eyeOffsetY)
                        }
                    }
                }
                .offset(y: -1)

                // Gentle smile / mouth
                if isHovered || companion.voiceState == .responding {
                    Circle()
                        .trim(from: 0.15, to: 0.85)
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                        .frame(width: 6, height: 4)
                }
            }
            .offset(y: 1)
        }
        .scaleEffect(isHovered ? 1.08 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        .contentShape(Circle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                updateEyeTracking()
            }
        }
        .onTapGesture {
            ClickySoundEngine.shared.play(.open)
            onToggleHomeSpace()
        }
        .onAppear {
            startBlinkCycle()
            startEyeTrackingTimer()
        }
        .onDisappear {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
    }

    private func startBlinkCycle() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 4.2, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isBlinking = true
                }
                try? await Task.sleep(nanoseconds: 140_000_000)
                withAnimation(.easeInOut(duration: 0.12)) {
                    isBlinking = false
                }
            }
        }
    }

    private func startEyeTrackingTimer() {
        // Track mouse gaze periodically when hovered or active
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            updateEyeTracking()
            return event
        }
    }

    private func updateEyeTracking() {
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.main {
            let sphereX = screen.visibleFrame.maxX - 44
            let sphereY = screen.visibleFrame.midY
            let dx = mouse.x - sphereX
            let dy = mouse.y - sphereY
            let dist = max(1.0, hypot(dx, dy))
            let maxOffset: CGFloat = 1.6
            eyeOffsetX = (dx / dist) * maxOffset
            eyeOffsetY = -(dy / dist) * maxOffset // Cocoa Y inversion
        }
    }
}
