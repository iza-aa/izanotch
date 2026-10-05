//
//  NotchShape.swift
//  boringNotch
//
// Created by Kai Azim on 2023-08-24.
// Original source: https://github.com/MrKai77/DynamicNotchKit
// Modified by Alexander on 2025-05-18.

import SwiftUI

struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(
        topCornerRadius: CGFloat? = nil,
        bottomCornerRadius: CGFloat? = nil
    ) {
        self.topCornerRadius = topCornerRadius ?? 6
        self.bottomCornerRadius = bottomCornerRadius ?? 14
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            .init(
                topCornerRadius,
                bottomCornerRadius
            )
        }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.minY + topCornerRadius
            ),
            control: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.maxY - bottomCornerRadius
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + topCornerRadius + bottomCornerRadius,
                y: rect.maxY
            ),
            control: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX - topCornerRadius - bottomCornerRadius,
                y: rect.maxY
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.maxY - bottomCornerRadius
            ),
            control: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.maxY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.minY + topCornerRadius
            )
        )

        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY
            ),
            control: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.minY
            )
        )

        path.addLine(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        return path
    }
}

// MARK: - Notch Open Glow Perimeter Shape (Open U-shape hugging perimeter, diving straight into top bezel)

struct NotchOpenGlowPerimeterShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
    var topBezelExtension: CGFloat = 24.0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get {
            .init(
                topCornerRadius,
                bottomCornerRadius
            )
        }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 1. Start inside the top screen bezel above the left ear
        path.move(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY - topBezelExtension
            )
        )

        // 2. Extend vertically down out of the bezel into the left ear top
        path.addLine(
            to: CGPoint(
                x: rect.minX,
                y: rect.minY
            )
        )

        // 3. Smooth concave fillet curving into the left card edge
        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.minY + topCornerRadius
            ),
            control: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.minY
            )
        )

        // 4. Down left vertical edge
        path.addLine(
            to: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.maxY - bottomCornerRadius
            )
        )

        // 5. Bottom-left rounded corner
        path.addQuadCurve(
            to: CGPoint(
                x: rect.minX + topCornerRadius + bottomCornerRadius,
                y: rect.maxY
            ),
            control: CGPoint(
                x: rect.minX + topCornerRadius,
                y: rect.maxY
            )
        )

        // 6. Bottom edge line
        path.addLine(
            to: CGPoint(
                x: rect.maxX - topCornerRadius - bottomCornerRadius,
                y: rect.maxY
            )
        )

        // 7. Bottom-right rounded corner
        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.maxY - bottomCornerRadius
            ),
            control: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.maxY
            )
        )

        // 8. Up right vertical edge
        path.addLine(
            to: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.minY + topCornerRadius
            )
        )

        // 9. Smooth concave fillet out to the right ear
        path.addQuadCurve(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY
            ),
            control: CGPoint(
                x: rect.maxX - topCornerRadius,
                y: rect.minY
            )
        )

        // 10. Extend vertically straight UP into the top screen bezel above the right ear
        path.addLine(
            to: CGPoint(
                x: rect.maxX,
                y: rect.minY - topBezelExtension
            )
        )

        // Path is intentionally open at the top: ZERO top horizontal line!
        return path
    }
}

// MARK: - Notch Perimeter Breathing Glow View (Follows exact Notch perimeter outline with zero top bar & zero outer blur)

struct NotchPerimeterBreathingGlowView: View {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    @State private var isBreathing: Bool = false
    
    init(topCornerRadius: CGFloat = 19, bottomCornerRadius: CGFloat = 24) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }
    
    init(notchShape: NotchShape) {
        self.topCornerRadius = notchShape.topCornerRadius
        self.bottomCornerRadius = notchShape.bottomCornerRadius
    }
    
    // Pure Gemini Blue Spectrum
    private let geminiBlues = [
        Color(red: 0.15, green: 0.55, blue: 1.00), // Vibrant Gemini Blue
        Color(red: 0.35, green: 0.75, blue: 1.00), // Electric Azure
        Color(red: 0.10, green: 0.42, blue: 0.98), // Deep Royal Blue
        Color(red: 0.05, green: 0.30, blue: 0.88), // Deep Navy Blue
        Color(red: 0.15, green: 0.55, blue: 1.00)  // Loop
    ]
    
    var body: some View {
        let openShape = NotchOpenGlowPerimeterShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius,
            topBezelExtension: 24.0
        )
        
        ZStack {
            // 1. Subtle tight neon aura (Tight glow with zero wide messy shadow on wallpaper)
            openShape
                .stroke(
                    LinearGradient(
                        colors: geminiBlues,
                        startPoint: isBreathing ? .topLeading : .topTrailing,
                        endPoint: isBreathing ? .bottomTrailing : .bottomLeading
                    ),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
                )
                .blur(radius: 1.0)
                .opacity(isBreathing ? 0.80 : 0.45)
            
            // 2. Crisp core neon beam (Razor-sharp, brilliant neon line hugging perimeter)
            openShape
                .stroke(
                    LinearGradient(
                        colors: geminiBlues,
                        startPoint: isBreathing ? .topLeading : .topTrailing,
                        endPoint: isBreathing ? .bottomTrailing : .bottomLeading
                    ),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )
                .opacity(isBreathing ? 1.00 : 0.75)
        }
        // Zero .offset(y: 2.5) so vertical extensions penetrate up into bezel seamlessly
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.8)
                .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
    }
}

#Preview {
    NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
        .frame(width: 200, height: 32)
        .padding(10)
}
