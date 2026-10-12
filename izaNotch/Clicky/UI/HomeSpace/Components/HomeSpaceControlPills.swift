//
//  HomeSpaceControlPills.swift
//  izaNotch (Izanotchy)
//
//  Interactive UI pills and swatch controls for HomeSpace.
//  Includes 3D Theme Swatch Button and Follow-Up Suggestion Pills.
//

import SwiftUI

public struct ThemeSwatchButton: View {
    public let theme: CompanionColorTheme
    public let isSelected: Bool
    public let onSelect: () -> Void

    public init(theme: CompanionColorTheme, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.theme = theme
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            ZStack {
                // Ambient glow on active selection
                if isSelected {
                    Circle()
                        .fill(theme.cloudColor)
                        .frame(width: 44, height: 44)
                        .blur(radius: 6)
                        .opacity(0.65)
                }

                // 3D Sphere Swatch (Glossy surface mimicking Strobi sphere)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.35),
                                theme.cloudColor,
                                theme.cloudColor.opacity(0.75)
                            ]),
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.25), lineWidth: isSelected ? 2.2 : 0.8)
                    )
                    .shadow(color: isSelected ? theme.cloudColor.opacity(0.8) : Color.black.opacity(0.3), radius: isSelected ? 5 : 2, x: 0, y: 1.5)

                // Mini Avatar Lab Capsule Pill Eyes
                HStack(spacing: 4.5) {
                    Capsule()
                        .fill(Color(hex: "#111316"))
                        .frame(width: 3.2, height: 7.5)
                    Capsule()
                        .fill(Color(hex: "#111316"))
                        .frame(width: 3.2, height: 7.5)
                }
                .offset(y: -1)
            }
            .frame(width: 44, height: 44)
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .help(theme.name)
    }
}

public struct FollowUpPillButton: View {
    public let text: String
    public let action: () -> Void

    public init(text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.09))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
                )
        }
        .buttonStyle(.plain)
    }
}
