//
//  ConditionalModifier.swift
//  boringNotch
//
//  Created by Richard Kunkli on 20/08/2024.
//

import SwiftUI

extension View {
    @ViewBuilder func conditionalModifier<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear,                   location: 0),
                            .init(color: .white.opacity(0.12),     location: 0.4),
                            .init(color: .white.opacity(0.22),     location: 0.5),
                            .init(color: .white.opacity(0.12),     location: 0.6),
                            .init(color: .clear,                   location: 1)
                        ],
                        startPoint: .init(x: phase, y: 0),
                        endPoint:   .init(x: phase + 1, y: 0)
                    )
                    .blendMode(.plusLighter)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}
