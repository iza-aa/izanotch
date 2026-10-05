//
//  test_grokbot_studio.swift
//  Standalone Visual Testing Studio for Grokbot (Novra Model)
//  Izanotchy Phase 1 Testing Harness
//

import SwiftUI
import AppKit

struct GrokbotInteractiveTestHarnessView: View {
    @State private var state: GrokbotState = .idle
    @State private var personality: GrokbotEyePersonality = .grokbotPill
    @State private var gaze: CGSize = .zero
    @State private var tapCount: Int = 0
    @State private var statusMessage: String = "Move mouse across the character canvas to inspect 3D eye foreshortening & boundary clipping (Foto 1)."

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                    Text("Grokbot 3D Testing Studio (Novra Model)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Stage Canvas
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.07, blue: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                VStack(spacing: 12) {
                    // Character with Live Hover
                    GrokbotNotchCharacterView(
                        diameter: 130,
                        state: state,
                        personality: personality,
                        gaze: gaze,
                        showBadge: state == .working,
                        onTap: {
                            handleCharacterTap()
                        }
                    )
                    .frame(width: 170, height: 170)

                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .frame(height: 250)
            .padding(.horizontal, 16)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let normalizedX = max(-1.0, min(1.0, (location.x - 240) / 140))
                    let normalizedY = max(-1.0, min(1.0, (location.y - 125) / 100))
                    withAnimation(.interactiveSpring(response: 0.16, dampingFraction: 0.72)) {
                        gaze = CGSize(width: normalizedX, height: normalizedY)
                    }
                    let clipStatus = abs(normalizedX) > 0.60 ? "⚠️ Limb Clipping Active (Foto 1)" : "Normal Sphere View"
                    statusMessage = String(format: "Gaze X: %+.2f | Gaze Y: %+.2f | %@", normalizedX, normalizedY, clipStatus)
                case .ended:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        gaze = .zero
                    }
                    statusMessage = "Mouse centered. Move cursor across canvas to test 3D spherical projection."
                }
            }

            // Controls: Eye Personalities (Foto 5)
            VStack(alignment: .leading, spacing: 6) {
                Text("EYE PERSONALITY (PHASE 2 ROSTER - FOTO 5)")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.horizontal, 18)

                HStack(spacing: 8) {
                    ForEach(GrokbotEyePersonality.allCases) { p in
                        Button(action: {
                            personality = p
                        }) {
                            Text(p.rawValue)
                                .font(.system(size: 11, weight: personality == p ? .bold : .medium))
                                .foregroundColor(personality == p ? .white : .white.opacity(0.65))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(personality == p ? Color(red: 0.05, green: 0.65, blue: 0.91) : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }

            // Controls: State Triggers (Foto 2 & 3)
            VStack(alignment: .leading, spacing: 6) {
                Text("TRIGGER SIMULATION (FOTO 2 & 3)")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.horizontal, 18)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    triggerButton(title: "Slap 1x", subtitle: "Startle", color: .orange) {
                        triggerState(.slap1, after: 0.7)
                    }
                    triggerButton(title: "Slap 2x", subtitle: "Annoyed", color: .orange) {
                        triggerState(.slap2, after: 1.2)
                    }
                    triggerButton(title: "Slap 3x", subtitle: "Dizzy Stars", color: .yellow) {
                        triggerState(.dizzy, after: 2.6)
                    }
                    triggerButton(title: "Working", subtitle: "Blue Badge", color: .cyan) {
                        state = .working
                    }
                    triggerButton(title: "Error", subtitle: "Red Wash", color: .red) {
                        state = .error
                    }
                    triggerButton(title: "Finished", subtitle: "Green Upward", color: .green) {
                        triggerState(.finished, after: 3.0)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Reset Button
            Button(action: {
                withAnimation(.spring()) {
                    state = .idle
                    gaze = .zero
                    statusMessage = "Reset to Default Idle Grokbot (Pure White, Zero Glow)."
                }
            }) {
                Text("Reset to Idle")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 490)
        .background(Color(red: 0.08, green: 0.08, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func triggerButton(title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundColor(color.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(color.opacity(0.35), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func handleCharacterTap() {
        tapCount += 1
        if tapCount == 1 {
            triggerState(.slap1, after: 0.7)
        } else if tapCount == 2 {
            triggerState(.slap2, after: 1.2)
        } else if tapCount >= 3 {
            tapCount = 0
            triggerState(.dizzy, after: 2.6)
        }
    }

    private func triggerState(_ newState: GrokbotState, after seconds: Double) {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
            state = newState
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                if state == newState {
                    state = .idle
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 490, height: 570),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true

        let hosting = NSHostingView(rootView: GrokbotInteractiveTestHarnessView())
        w.contentView = hosting

        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (490 / 2)
            let y = screenRect.midY - (570 / 2)
            w.setFrameOrigin(NSPoint(x: x, y: y))
        }

        w.makeKeyAndOrderFront(nil)
        self.window = w
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct GrokbotStudioMain {
    static var strongDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        strongDelegate = delegate
        app.delegate = delegate
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
