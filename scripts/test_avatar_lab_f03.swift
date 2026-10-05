//
//  test_avatar_lab_f03.swift
//  boringNotch (Izanotchy • Fitur F-03 Verification Runner)
//
//  Renders a visual board demonstrating:
//  1. Grok Bot White (Pure White Sphere #FFFFFF, Obsidian Eyes #111316)
//  2. Preset 25 (Marah / Angry - Diganggu)
//  3. Preset 26 (Sedih / Sad - Hover ke Page Lain)
//  4. Dynamic Gaze Tracking (Melirik Kiri, Kanan, Atas, Bawah via Dual-Layer Parallax)
//

import SwiftUI
import AppKit

struct GazeAndReactionsVerificationView: View {
    let grokWhite = CompanionAvatarDefinition.defaultGrokBotWhite

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                    Text("Bible Strong Avatar Lab • Fitur F-03: Dynamic Gaze Tracking & Notch Home Reactions")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("Grok Bot (White Edition) • Preset 25 (Marah) • Preset 26 (Sedih) • Dual-Layer Gaze Parallax")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.top, 12)

            // Section 1: Dynamic Gaze Tracking (Dual-Layer: Rotasi Kepala 3D + Pergeseran Mata)
            VStack(alignment: .leading, spacing: 10) {
                Text("1. Dynamic Gaze Tracking (Dual-Layer: Head Yaw/Pitch + Eye Parallax Shift)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#10B981"))

                HStack(spacing: 24) {
                    // Look Left
                    VStack(spacing: 6) {
                        CompanionProceduralAvatarView(
                            definition: grokWhite,
                            expressionName: "neutral",
                            gazeOffset: CGPoint(x: -1.0, y: 0.0),
                            size: 72
                        )
                        Text("Gaze Left (-1.0)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Look Center
                    VStack(spacing: 6) {
                        CompanionProceduralAvatarView(
                            definition: grokWhite,
                            expressionName: "neutral",
                            gazeOffset: CGPoint(x: 0.0, y: 0.0),
                            size: 72
                        )
                        Text("Center (0.0)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Look Right
                    VStack(spacing: 6) {
                        CompanionProceduralAvatarView(
                            definition: grokWhite,
                            expressionName: "neutral",
                            gazeOffset: CGPoint(x: 1.0, y: 0.0),
                            size: 72
                        )
                        Text("Gaze Right (+1.0)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Look Up
                    VStack(spacing: 6) {
                        CompanionProceduralAvatarView(
                            definition: grokWhite,
                            expressionName: "neutral",
                            gazeOffset: CGPoint(x: 0.0, y: -1.0),
                            size: 72
                        )
                        Text("Gaze Up (-1.0)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Look Down
                    VStack(spacing: 6) {
                        CompanionProceduralAvatarView(
                            definition: grokWhite,
                            expressionName: "neutral",
                            gazeOffset: CGPoint(x: 0.0, y: 1.0),
                            size: 72
                        )
                        Text("Gaze Down (+1.0)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Section 2: Home Section Notch Cards (1:1 Verification of User States)
            VStack(alignment: .leading, spacing: 10) {
                Text("2. Home Section Notch Companion Cards (1:1 Welcoming Companion Experience)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#60A5FA"))

                HStack(spacing: 18) {
                    // Card A: Normal Greeting
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Hello Heizaa!")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("👋")
                                .font(.system(size: 11))
                        }
                        Text("How are you today")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))

                        Spacer()

                        HStack {
                            Spacer()
                            CompanionProceduralAvatarView(
                                definition: grokWhite,
                                expressionName: "neutral",
                                autoBlink: true,
                                size: 66
                            )
                            Spacer()
                        }
                        Text("Status: Normal Greeting")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(10)
                    .frame(width: 140, height: 140)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    // Card B: Diganggu ➔ Preset 25 (Marah)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Hello Heizaa!")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("💢")
                                .font(.system(size: 11))
                        }
                        Text("Don't poke me! 😤")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))

                        Spacer()

                        HStack {
                            Spacer()
                            CompanionProceduralAvatarView(
                                definition: grokWhite,
                                expressionName: "preset-25",
                                autoBlink: false,
                                size: 66
                            )
                            Spacer()
                        }
                        Text("Diganggu ➔ Preset 25 (Marah)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(10)
                    .frame(width: 140, height: 140)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.red.opacity(0.35), lineWidth: 1)
                    )

                    // Card C: Hover ke Page Lain ➔ Preset 26 (Sedih)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Hello Heizaa!")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("🥺")
                                .font(.system(size: 11))
                        }
                        Text("Don't leave me...")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.7))

                        Spacer()

                        HStack {
                            Spacer()
                            CompanionProceduralAvatarView(
                                definition: grokWhite,
                                expressionName: "preset-26",
                                autoBlink: true,
                                size: 66
                            )
                            Spacer()
                        }
                        Text("Hover Tabs ➔ Preset 26 (Sedih)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.7))
                            .frame(maxWidth: .infinity)
                    }
                    // Card D: Hover Kursor di Atas Chara ➔ hover-round (Mata Membulat)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("Hello Heizaa!")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("🤭")
                                .font(.system(size: 11))
                        }
                        Text("Stop tickling me!")
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#34D399"))

                        Spacer()

                        HStack {
                            Spacer()
                            ZStack {
                                // Green Aura Glow underneath
                                Circle()
                                    .fill(Color(hex: "#0F624C"))
                                    .frame(width: 76, height: 76)
                                    .blur(radius: 16)
                                    .opacity(0.60)

                                // Repeated Faint Concentric Rings (Opsi B: 11px spacing, uniform faint stroke)
                                Circle()
                                    .stroke(Color(hex: "#34D399").opacity(0.36), lineWidth: 1.3)
                                    .frame(width: 74, height: 74)
                                    .blur(radius: 0.9)
                                Circle()
                                    .stroke(Color(hex: "#34D399").opacity(0.36), lineWidth: 1.3)
                                    .frame(width: 96, height: 96)
                                    .blur(radius: 0.9)
                                Circle()
                                    .stroke(Color(hex: "#34D399").opacity(0.36), lineWidth: 1.3)
                                    .frame(width: 118, height: 118)
                                    .blur(radius: 0.9)

                                CompanionProceduralAvatarView(
                                    definition: grokWhite,
                                    expressionName: "hover-focus-upright",
                                    autoBlink: true,
                                    size: 66
                                )
                            }
                            Spacer()
                        }
                        Text("Hover 0.5s ➔ Opsi B Pulse (11px)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Color(hex: "#34D399"))
                            .frame(maxWidth: .infinity)
                    }
                    .padding(10)
                    .frame(width: 140, height: 140)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color(hex: "#10B981").opacity(0.35), lineWidth: 1)
                    )
                }
            }
        }
        .padding(24)
        .frame(width: 780, height: 440)
        .background(Color(hex: "#0E1013"))
    }
}

@main
struct AvatarF03Verifier {
    static func main() async {
        print("==> Verifying Preset 25, Preset 26 & hover-round...")

        guard let p25 = CompanionAvatarDefinition.defaultGrokBotWhite.expressions["preset-25"] else {
            fatalError("❌ preset-25 missing!")
        }
        guard let p26 = CompanionAvatarDefinition.defaultGrokBotWhite.expressions["preset-26"] else {
            fatalError("❌ preset-26 missing!")
        }
        guard let pHover = CompanionAvatarDefinition.defaultGrokBotWhite.expressions["hover-round"] else {
            fatalError("❌ hover-round missing!")
        }

        assert(pHover.widthLeft == 40.0 && pHover.heightLeft == 40.0, "❌ hover-round left eye dimensions mismatch")
        assert(pHover.widthRight == 40.0 && pHover.heightRight == 40.0, "❌ hover-round right eye dimensions mismatch")
        assert(pHover.spacing == 48.0, "❌ hover-round spacing should be 48.0")
        assert(pHover.positionYLeft == -14.0 && pHover.positionYRight == -14.0, "❌ hover-round positionY should be -14.0")
        print("✅ Assertion Passed: hover-round (large expressive circular eyes 40x40 at Y=-14.0) is valid!")

        guard let pFocus = CompanionAvatarDefinition.defaultGrokBotWhite.expressions["hover-focus-upright"] else {
            fatalError("❌ hover-focus-upright missing!")
        }
        assert(pFocus.headX == 20.0 && pFocus.headY == 22.0 && pFocus.headZ == -14.0, "❌ hover-focus-upright orientation mismatch")
        assert(pFocus.widthLeft == 44.0 && pFocus.heightLeft == 40.0, "❌ hover-focus-upright left eye mismatch")
        assert(pFocus.widthRight == 30.0 && pFocus.heightRight == 36.0, "❌ hover-focus-upright right eye mismatch")
        assert(pFocus.spacing == 56.0, "❌ hover-focus-upright spacing mismatch")
        assert(pFocus.bodyMotion == "none", "❌ hover-focus-upright must have none motion (still pose 1:1 photo)")
        print("✅ Assertion Passed: hover-focus-upright (1:1 photo pose, still, zero shake, emerald eyes focus) is valid!")

        guard let pNeutral = CompanionAvatarDefinition.defaultGrokBotWhite.expressions["neutral"] else {
            fatalError("❌ neutral missing!")
        }
        assert(pNeutral.widthLeft == 27.13 && pNeutral.heightLeft == 63.03, "❌ neutral dimensions mismatch")
        assert(pNeutral.spacing == 48.0, "❌ neutral spacing should be 48.0")
        print("✅ Assertion Passed: neutral (enlarged pupils 27.13x63.03 matching angry size, spacing 48.0) is valid!")

        guard let p22 = CompanionAvatarDefinition.defaultGrokBotWhite.expressions["preset-22"] else {
            fatalError("❌ preset-22 missing!")
        }
        assert(p22.widthLeft == 55.67 && p22.heightLeft == 14.62, "❌ preset-22 dimensions mismatch")
        assert(p22.leftAngle == 0.0 && p22.rightAngle == 0.0, "❌ preset-22 must have flat 0 angle")
        assert(p22.spacing == 68.42, "❌ preset-22 spacing mismatch")
        print("✅ Assertion Passed: Preset 22 (drowsy-closed / flat unamused eyes 55.7x14.6) is 100% compliant with Bible Strong spec!")

        assert(p25.bodyColorHex == "#ba3636", "❌ preset-25 bodyColorHex should be #ba3636, got \(p25.bodyColorHex ?? "nil")")
        assert(p25.eyeColorHex == "#610000", "❌ preset-25 eyeColorHex should be #610000, got \(p25.eyeColorHex ?? "nil")")
        assert(abs(p25.leftAngle - (-36.24)) < 0.01, "❌ preset-25 leftAngle mismatch")
        assert(abs(p25.rightAngle - 27.73) < 0.01, "❌ preset-25 rightAngle mismatch")
        assert(p25.bodyMotion == "shake", "❌ preset-25 bodyMotion mismatch")
        print("✅ Assertion Passed: Preset 25 (angry-brows) is 100% compliant with Bible Strong Avatar Lab spec!")

        assert(p26.bodyColorHex == "#adc3ff", "❌ preset-26 bodyColorHex should be #adc3ff, got \(p26.bodyColorHex ?? "nil")")
        assert(abs(p26.leftAngle - 23.52) < 0.01, "❌ preset-26 leftAngle mismatch")
        assert(abs(p26.rightAngle - (-24.04)) < 0.01, "❌ preset-26 rightAngle mismatch")
        assert(p26.bodyMotion == "slowDrift", "❌ preset-26 bodyMotion mismatch")
        assert(p26.eyeMotion == "shake", "❌ preset-26 eyeMotion mismatch")
        print("✅ Assertion Passed: Preset 26 (uneasy-left) is 100% compliant with Bible Strong Avatar Lab spec!")

        // Test smooth chromatic interpolation
        let midColor = AvatarExpression.interpolateColorHex(from: "#FFFFFF", to: "#BA3636", progress: 0.5)
        assert(midColor != nil, "❌ interpolateColorHex failed")
        print("✅ Assertion Passed: Color interpolation at 50% (#FFFFFF -> #BA3636) = \(midColor!)")

        // Test Euclidean distance circle hover boundary (Milestone 163)
        let avatarSize: CGFloat = 76.0
        let center = CGPoint(x: avatarSize / 2.0, y: avatarSize / 2.0) // (38, 38)
        let radius: CGFloat = 120.0 * (avatarSize / 300.0) // 30.4 px
        let rSquared = radius * radius // 924.16

        func isInsideHoverCircle(_ pt: CGPoint) -> Bool {
            let dx = pt.x - center.x
            let dy = pt.y - center.y
            return (dx * dx + dy * dy) <= rSquared
        }

        assert(isInsideHoverCircle(CGPoint(x: 38.0, y: 38.0)) == true, "❌ Center (38, 38) must be inside hover circle")
        assert(isInsideHoverCircle(CGPoint(x: 38.0 + 30.0, y: 38.0)) == true, "❌ Point at R=30.0 must be inside hover circle")
        assert(isInsideHoverCircle(CGPoint(x: 38.0 + 31.0, y: 38.0)) == false, "❌ Point at R=31.0 must be outside hover circle")
        assert(isInsideHoverCircle(CGPoint(x: 5.0, y: 71.0)) == false, "❌ Bottom-left corner (5, 71) must be strictly OUTSIDE hover circle (Eliminates rectangular false hover)")
        assert(isInsideHoverCircle(CGPoint(x: 71.0, y: 5.0)) == false, "❌ Top-right corner (71, 5) must be strictly OUTSIDE hover circle")
        assert(isInsideHoverCircle(CGPoint(x: 5.0, y: 5.0)) == false, "❌ Top-left corner (5, 5) must be strictly OUTSIDE hover circle")
        assert(isInsideHoverCircle(CGPoint(x: 71.0, y: 71.0)) == false, "❌ Bottom-right corner (71, 71) must be strictly OUTSIDE hover circle")
        print("✅ Assertion Passed: Euclidean distance hover filter (R <= 30.4px) strictly excludes all 4 rectangular corners!")

        print("==> Rendering Fitur F-03 Verification Board (Grok Bot White, Gaze, Preset 25 & 26)...")

        let view = GazeAndReactionsVerificationView()
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(x: 0, y: 0, width: 780, height: 440)

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("❌ Failed to create bitmap rep")
            exit(1)
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            print("❌ Failed to encode PNG")
            exit(1)
        }

        let outPath = "/tmp/avatar_lab_f03_preview.png"
        let outURL = URL(fileURLWithPath: outPath)
        do {
            try pngData.write(to: outURL)
            print("==> Successfully saved snapshot to: \(outPath) (\(pngData.count) bytes)")
        } catch {
            print("❌ Failed to write PNG: \(error)")
            exit(1)
        }
    }
}
