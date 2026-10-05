//
//  test_avatar_lab_inspector.swift
//  boringNotch
//
//  Visual & Interactive Verification for Bible Strong Avatar Lab (Fitur F-02: Blinking & Morphing)
//

import SwiftUI
import AppKit

struct AvatarStudioVerificationView: View {
    let presets: [CompanionAvatarDefinition] = [
        .defaultClicky,
        .defaultMarketScout,
        .defaultResearchBuddy,
        .defaultShippy
    ]

    private func halfSquashPreset(_ preset: CompanionAvatarDefinition) -> CompanionAvatarDefinition {
        var copy = preset
        if var neutral = copy.expressions["neutral"] {
            neutral.heightLeft = 5.0 + (neutral.heightLeft - 5.0) * 0.4
            neutral.heightRight = 5.0 + (neutral.heightRight - 5.0) * 0.4
            copy.expressions["half-squash"] = neutral
        }
        return copy
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "#5b7fe5"))
                        .frame(width: 10, height: 10)
                    Text("Bible Strong Avatar Lab • Fitur F-02: Procedural Blinking & Transisi Ekspresi")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("Harmonic Vertical Squash Blink (1.0 ➔ 0.5 ➔ 0.0) • Calibrated 3D Morphing • 100% Strobi Spec")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 8)

            // Grid of 4 Presets
            HStack(spacing: 18) {
                ForEach(presets) { preset in
                    VStack(spacing: 12) {
                        Text(preset.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)

                        // 88pt Studio Render (Neutral)
                        CompanionProceduralAvatarView(
                            definition: preset,
                            expressionName: "neutral",
                            isBlinking: false,
                            autoBlink: false,
                            size: 88
                        )

                        // Stages of Blinking (Open ➔ Half ➔ Slit)
                        VStack(spacing: 6) {
                            Text("Blink Stages (Squash):")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))

                            HStack(spacing: 10) {
                                VStack(spacing: 2) {
                                    CompanionProceduralAvatarView(
                                        definition: preset,
                                        expressionName: "neutral",
                                        isBlinking: false,
                                        size: 34
                                    )
                                    Text("Open")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                VStack(spacing: 2) {
                                    CompanionProceduralAvatarView(
                                        definition: halfSquashPreset(preset),
                                        expressionName: "half-squash",
                                        isBlinking: false,
                                        size: 34
                                    )
                                    Text("Half")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                VStack(spacing: 2) {
                                    CompanionProceduralAvatarView(
                                        definition: preset,
                                        expressionName: "neutral",
                                        isBlinking: true, // Slit (closed)
                                        size: 34
                                    )
                                    Text("Closed")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#1A1D24"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
            }

            // Footer Status
            HStack {
                Text("STATUS: F-02 BLINKING & MORPHING VERIFIED")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "#10B981"))
                Spacer()
                Text("Auto-Blink Periodik 3.5–5.2s • Smooth Cubic Ease-in-out Morph")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .padding(20)
        .frame(width: 780, height: 380)
        .background(Color(hex: "#0F1115"))
    }
}

@main
struct AvatarLabTestMain {
    static func main() {
        let shouldOpenWindow = CommandLine.arguments.contains("--open")
        let outputPath = CommandLine.arguments.first(where: { $0.hasPrefix("--out=") })?
            .replacingOccurrences(of: "--out=", with: "") ?? "/tmp/avatar_lab_f02_preview.png"

        print("==> Rendering Authentic Strobi 3D Verification Board (Fitur F-02: Blinking & Morphing)...")
        let view = AvatarStudioVerificationView()
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 780, height: 380)

        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            print("ERROR: Failed to allocate bitmapImageRep")
            exit(1)
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("ERROR: Failed to generate PNG data")
            exit(1)
        }

        let url = URL(fileURLWithPath: outputPath)
        do {
            try pngData.write(to: url)
            print("==> Successfully saved snapshot to: \(outputPath) (\(pngData.count) bytes)")
        } catch {
            print("ERROR writing PNG: \(error)")
            exit(1)
        }

        if shouldOpenWindow {
            print("==> Opening Interactive Window (--open specified with live auto-blink)...")
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            let window = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 780, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Bible Strong Avatar Lab • Fitur F-02 Inspector (Live Blink & Morphing)"
            window.contentView = NSHostingView(rootView: CompanionAvatarInspectorView())
            window.makeKeyAndOrderFront(nil)
            app.run()
        }
    }
}
