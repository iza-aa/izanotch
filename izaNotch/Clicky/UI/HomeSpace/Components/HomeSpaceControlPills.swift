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

// MARK: - GrokBotMarkView (1:1 Grok Bot x.ai/bot Vector Squircle Mark)
public struct GrokBotMarkView: View {
    public let name: String
    public let tintColorHex: String
    public let size: CGFloat
    public var isWorking: Bool
    public var isSelected: Bool

    @State private var pulse: Bool = false

    private var effectiveTint: Color {
        let cleanHex = tintColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.isEmpty || cleanHex == "#38BDF8" {
            let defaultTints = ["#E11D48", "#D946EF", "#8B5CF6", "#06B6D4", "#10B981", "#F59E0B"]
            let idx = abs(name.hashValue) % defaultTints.count
            return Color(hex: defaultTints[idx])
        }
        return Color(hex: cleanHex)
    }

    private var initials: String {
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let first = parts[0].prefix(1)
            let second = parts[1].prefix(1)
            return "\(first)\(second)".uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }

    public init(
        name: String,
        tintColorHex: String = "",
        size: CGFloat = 32,
        isWorking: Bool = false,
        isSelected: Bool = false
    ) {
        self.name = name
        self.tintColorHex = tintColorHex
        self.size = size
        self.isWorking = isWorking
        self.isSelected = isSelected
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            effectiveTint.opacity(0.24),
                            effectiveTint.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .stroke(
                            effectiveTint.opacity(isSelected ? 0.85 : 0.40),
                            lineWidth: isSelected ? 1.5 : 1.0
                        )
                )

            Text(initials.isEmpty ? "B" : initials)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundColor(effectiveTint)

            if isWorking {
                Circle()
                    .fill(Color(hex: "#38BDF8"))
                    .frame(width: max(7, size * 0.24), height: max(7, size * 0.24))
                    .overlay(Circle().stroke(Color(hex: "#141517"), lineWidth: 1.5))
                    .scaleEffect(pulse ? 1.25 : 0.85)
                    .opacity(pulse ? 1.0 : 0.6)
                    .offset(x: size * 0.36, y: size * 0.36)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
            }
        }
        .frame(width: size, height: size)
    }
}
