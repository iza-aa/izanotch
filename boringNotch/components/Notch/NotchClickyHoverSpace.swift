//
//  NotchClickyHoverSpace.swift
//  boringNotch (Izanotchy)
//
//  Dedicated Notch In-Notch Dynamic Island Spring Hover Card for Clicky.
//  Emerges directly out of the Clicky icon on hover in, and shrinks back
//  into the icon on hover off with genuine Apple spring physics.
//

import SwiftUI
import Defaults

struct NotchTooltipBubbleShape: Shape {
    var arrowX: CGFloat = 235 // Points right to center of the Clicky icon (width 250 - 15)
    var cornerRadius: CGFloat = 16
    var arrowHeight: CGFloat = 6
    var arrowWidth: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topY = rect.minY + arrowHeight
        let botY = rect.maxY
        let leftX = rect.minX
        let rightX = rect.maxX

        // Start at top-left after corner
        path.move(to: CGPoint(x: leftX + cornerRadius, y: topY))

        // Top edge to left base of arrow
        let arrowLeft = min(max(arrowX - arrowWidth / 2, leftX + cornerRadius), rightX - cornerRadius - arrowWidth)
        let arrowTip = arrowLeft + arrowWidth / 2
        let arrowRight = arrowLeft + arrowWidth

        path.addLine(to: CGPoint(x: arrowLeft, y: topY))
        // Arrow to tip pointing up
        path.addLine(to: CGPoint(x: arrowTip, y: rect.minY))
        // Arrow to right base
        path.addLine(to: CGPoint(x: arrowRight, y: topY))

        // Top edge to top-right corner
        path.addLine(to: CGPoint(x: rightX - cornerRadius, y: topY))
        path.addArc(center: CGPoint(x: rightX - cornerRadius, y: topY + cornerRadius), radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

        // Right edge to bottom-right corner
        path.addLine(to: CGPoint(x: rightX, y: botY - cornerRadius))
        path.addArc(center: CGPoint(x: rightX - cornerRadius, y: botY - cornerRadius), radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

        // Bottom edge to bottom-left corner
        path.addLine(to: CGPoint(x: leftX + cornerRadius, y: botY))
        path.addArc(center: CGPoint(x: leftX + cornerRadius, y: botY - cornerRadius), radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // Left edge to top-left corner
        path.addLine(to: CGPoint(x: leftX, y: topY + cornerRadius))
        path.addArc(center: CGPoint(x: leftX + cornerRadius, y: topY + cornerRadius), radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        path.closeSubpath()
        return path
    }
}

struct NotchClickyHoverSpace: View {
    @ObservedObject var clickyManager = CompanionManager.shared
    var onExpandToStudio: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Quick Context & Status
            Text(clickyManager.isClickyCursorEnabled ? "Watching your screen in real time. Ready to guide, point, and execute tasks." : "Cursor assistant is currently sleeping. Click Notch button to activate.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            // MARK: - Actions
            Button(action: {
                ClickySoundEngine.shared.play(.open)
                onExpandToStudio()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Hold ⌃⌥ to Talk")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(HeyClickyGelButtonStyle())
        }
        .padding(.top, 16)
        .padding([.horizontal, .bottom], 12)
        .frame(width: 250)
        .background(
            NotchTooltipBubbleShape()
                .fill(Color(red: 0.08, green: 0.09, blue: 0.10).opacity(0.96))
                .overlay(
                    NotchTooltipBubbleShape()
                        .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.55), radius: 14, x: 0, y: 7)
        )
    }
}
