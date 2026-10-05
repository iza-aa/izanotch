//
//  NotchContextualSuggestionPill.swift
//  boringNotch (Izanotchy)
//
//  Dynamic Island contextual action pill hugging the closed MacBook Notch.
//  Triggered automatically when IntegrationSuggestionMonitor detects an active
//  workflow (GitHub PR, Linear, Notion, Figma, Code Editor).
//

import SwiftUI
import Defaults

struct NotchContextualSuggestionPill: View {
    @ObservedObject var suggestionMonitor = IntegrationSuggestionMonitor.shared
    @ObservedObject var companion = CompanionManager.shared
    @State private var isHovered = false

    var body: some View {
        if let suggestion = suggestionMonitor.activeSuggestion, Defaults[.proactiveNotchSuggestionsEnabled] {
            Button(action: {
                handleSuggestionTap(suggestion)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.overlayCursorBlue)
                        .symbolEffect(.pulse, options: .repeating)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(suggestion.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(suggestion.domain)
                            .font(.system(size: 8.5, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(DS.Colors.overlayCursorBlue.opacity(0.8))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .overlay(
                            Capsule()
                                .stroke(isHovered ? DS.Colors.overlayCursorBlue.opacity(0.8) : Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: isHovered ? DS.Colors.overlayCursorBlue.opacity(0.4) : Color.clear, radius: 6, x: 0, y: 1)
                )
                .scaleEffect(isHovered ? 1.04 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
        }
    }

    private func handleSuggestionTap(_ suggestion: ContextualSuggestion) {
        ClickyLogger.info("[SUGGESTION]", "User tapped suggestion: \"\(suggestion.title)\"")
        ClickySoundEngine.shared.play(.open)

        // Open HomeSpace with pre-filled prompt so user can inspect, edit, or execute immediately
        HomeSpaceWindowManager.shared.show(withPrompt: suggestion.prompt)
    }
}
