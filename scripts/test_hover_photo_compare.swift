import SwiftUI
import AppKit

// Custom View to test the Photo Look:
struct PhotoHoverTestCard: View {
    let expr: AvatarExpression

    var body: some View {
        ZStack {
            // Dark card background
            Color(hex: "#101416")

            // Concentric Green Pulse Rings (1:1 Reference Photo, without small green circle)
            ZStack {
                // Outermost diffuse pulse wave 4
                Circle()
                    .stroke(Color(hex: "#0E4E3D").opacity(0.35), lineWidth: 3.5)
                    .frame(width: 124, height: 124)
                    .blur(radius: 2.0)

                // Wave 3
                Circle()
                    .stroke(Color(hex: "#126B54").opacity(0.55), lineWidth: 3.0)
                    .frame(width: 104, height: 104)
                    .blur(radius: 1.5)

                // Wave 2
                Circle()
                    .stroke(Color(hex: "#10B981").opacity(0.65), lineWidth: 2.5)
                    .frame(width: 86, height: 86)
                    .blur(radius: 1.0)

                // Inner core glow wave 1
                Circle()
                    .stroke(Color(hex: "#34D399").opacity(0.85), lineWidth: 2.0)
                    .frame(width: 72, height: 72)
                    .blur(radius: 0.8)

                // Ambient emerald radial backdrop
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#064E3B").opacity(0.7),
                        Color(hex: "#022C22").opacity(0.35),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 20,
                    endRadius: 65
                )
                .frame(width: 130, height: 130)
            }

            // Strobi Avatar View
            CompanionProceduralAvatarView(
                definition: CompanionAvatarDefinition(
                    colors: AvatarColors(bodyHex: "#FFFFFF", eyesHex: "#111316"),
                    expressions: ["test": expr]
                ),
                expressionName: "test",
                autoBlink: true,
                trackMouse: false,
                size: 76
            )
        }
        .frame(width: 140, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct ComparisonBoard: View {
    // Candidate 1A: Centered-right look (headX 18, headY 18, headZ -12, big round left eye 46x44)
    let expr1 = AvatarExpression(
        id: "cand-1a",
        headX: 18.0, headY: 18.0, headZ: -12.0,
        widthLeft: 46.0, widthRight: 32.0,
        heightLeft: 44.0, heightRight: 38.0,
        spacing: 58.0,
        positionYLeft: -14.0, positionYRight: -14.0,
        leftAngle: -8.0, rightAngle: 8.0
    )

    // Candidate 1B: Balanced angle (headX 20, headY 22, headZ -14, left eye 44x40)
    let expr2 = AvatarExpression(
        id: "cand-1b",
        headX: 20.0, headY: 22.0, headZ: -14.0,
        widthLeft: 44.0, widthRight: 30.0,
        heightLeft: 40.0, heightRight: 36.0,
        spacing: 56.0,
        positionYLeft: -16.0, positionYRight: -16.0,
        leftAngle: -6.0, rightAngle: 10.0
    )

    // Candidate 1C: Dynamic head turn (headX 22, headY 25, headZ -15, left eye 42x38)
    let expr3 = AvatarExpression(
        id: "cand-1c",
        headX: 22.0, headY: 25.0, headZ: -15.0,
        widthLeft: 42.0, widthRight: 28.0,
        heightLeft: 38.0, heightRight: 36.0,
        spacing: 54.0,
        positionYLeft: -16.0, positionYRight: -16.0,
        leftAngle: -10.0, rightAngle: 12.0
    )

    var body: some View {
        VStack(spacing: 20) {
            Text("Hover Photo Expression Precision Calibration vs Reference Photo")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 24) {
                // User Ref Image
                VStack(spacing: 8) {
                    if let img = NSImage(contentsOfFile: "/Users/heizaaa/.gemini/antigravity/brain/2cec968d-601f-43f7-9307-139a181f10d8/.user_uploaded/media_1790772686766.png") {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.green, lineWidth: 2)
                            )
                    }
                    Text("Reference Photo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }

                // Cand 1A
                VStack(spacing: 8) {
                    PhotoHoverTestCard(expr: expr1)
                    Text("Opsi 1A (Yaw 18°, Big Left Eye)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Cand 1B
                VStack(spacing: 8) {
                    PhotoHoverTestCard(expr: expr2)
                    Text("Opsi 1B (Yaw 22°, Gold Ratio)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Cand 1C
                VStack(spacing: 8) {
                    PhotoHoverTestCard(expr: expr3)
                    Text("Opsi 1C (Yaw 25°, Edge Drift)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(24)
        .background(Color(hex: "#0A0B0D"))
    }
}

@main
struct RenderRunner {
    static func main() {
        let view = ComparisonBoard()
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(x: 0, y: 0, width: 720, height: 260)

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("❌ Failed to create bitmap rep")
            exit(1)
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            print("❌ Failed to encode PNG")
            exit(1)
        }

        let outPath = "/tmp/hover_photo_compare_preview.png"
        try? pngData.write(to: URL(fileURLWithPath: outPath))
        print("✅ Comparison rendered to: \(outPath)")
    }
}
