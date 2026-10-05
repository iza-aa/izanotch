//
//  HomeSpaceOnboardingAppearanceView.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for HomeSpaceRootView.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

extension HomeSpaceRootView {
    // MARK: - Step 3: Character Appearance Studio & Launch
    var newBuddyCharacterCustomizationView: some View {
        VStack(spacing: 0) {
            // Header: < Back to Spec + Customize Appearance
            HStack {
                Button(action: {
                    interviewEngine.backToSpecReview()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Spec")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                Text("Customize Character")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.leading, 6)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // 1. Live Mascot Preview with Signature HeyClicky Rings
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: interviewEngine.customCloudColorHex.isEmpty ? "#38BDF8" : interviewEngine.customCloudColorHex))
                                .frame(width: 96, height: 96)
                                .blur(radius: 20)
                                .opacity(0.6)

                            let template = CompanionAvatarLabCatalog.allTemplates.first { $0.id == interviewEngine.selectedTemplateId } ?? CompanionAvatarLabCatalog.allTemplates[0]
                            CompanionProceduralAvatarView(
                                definition: template.toAvatarDefinition(
                                    name: interviewEngine.synthesizedName.isEmpty ? "New Companion" : interviewEngine.synthesizedName,
                                    cloudColorHex: interviewEngine.customCloudColorHex.isEmpty ? "#38BDF8" : interviewEngine.customCloudColorHex,
                                    eyesHex: "#111316"
                                ),
                                expressionName: interviewEngine.selectedAvatarLabExpression,
                                autoBlink: true,
                                size: 84
                            )
                        }
                        .frame(width: 110, height: 104)
                        .padding(.top, 4)

                        VStack(spacing: 2) {
                            Text(interviewEngine.synthesizedName)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(interviewEngine.synthesizedRole)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .padding(.vertical, 4)

                    // 2. Section: CHARACTER (11 Shapes) - Shape First
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("1. CHARACTER")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(0.6)
                            Spacer()
                            let curT = CompanionAvatarLabCatalog.allTemplates.first { $0.id == interviewEngine.selectedTemplateId }
                            Text(curT?.name ?? "Strobi")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: interviewEngine.customCloudColorHex.isEmpty ? "#38BDF8" : interviewEngine.customCloudColorHex))
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(CompanionAvatarLabCatalog.allTemplates) { t in
                                    let isSelected = interviewEngine.selectedTemplateId == t.id
                                    Button(action: {
                                        ClickySoundEngine.shared.play(.send)
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                            interviewEngine.selectedTemplateId = t.id
                                            if interviewEngine.customCloudColorHex.isEmpty {
                                                interviewEngine.customCloudColorHex = t.defaultColors.bodyHex
                                            }
                                        }
                                    }) {
                                        VStack(spacing: 5) {
                                            ZStack {
                                                Circle()
                                                    .fill(isSelected ? Color(hex: interviewEngine.customCloudColorHex.isEmpty ? "#38BDF8" : interviewEngine.customCloudColorHex).opacity(0.25) : Color.white.opacity(0.04))
                                                    .frame(width: 44, height: 44)

                                                CompanionProceduralAvatarView(
                                                    definition: t.toAvatarDefinition(cloudColorHex: isSelected ? interviewEngine.customCloudColorHex : nil),
                                                    expressionName: "neutral",
                                                    autoBlink: false,
                                                    size: 34
                                                )
                                            }
                                            .overlay(
                                                Circle()
                                                    .stroke(isSelected ? Color(hex: interviewEngine.customCloudColorHex.isEmpty ? "#38BDF8" : interviewEngine.customCloudColorHex) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.8 : 0.8)
                                            )

                                            Text(t.name)
                                                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                                                .lineLimit(1)
                                        }
                                        .frame(width: 62)
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 0.8))
                    )

                    // 3. Curated Color Themes (12 presets) - Color Second
                    VStack(alignment: .leading, spacing: 10) {
                        Text("2. HARMONIOUS COLOR THEMES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                            ForEach(CompanionColorTheme.allThemes) { theme in
                                ThemeSwatchButton(
                                    theme: theme,
                                    isSelected: interviewEngine.customCloudColorHex.caseInsensitiveCompare(theme.cloudColorHex) == .orderedSame,
                                    onSelect: {
                                        ClickySoundEngine.shared.play(.send)
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                            interviewEngine.selectedTheme = theme
                                            interviewEngine.customCloudColorHex = theme.cloudColorHex
                                            interviewEngine.customRingColorHex = theme.ringColorHex
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 0.8))
                    )

                    // 4. Avatar Expression Picker (Avatar Lab Presets)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("3. INITIAL EXPRESSION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(0.6)

                            Spacer()

                            Text(CompanionAvatarLabCatalog.preset(byId: interviewEngine.selectedAvatarLabExpression)?.displayName ?? interviewEngine.selectedAvatarLabExpression)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: interviewEngine.customCloudColorHex.isEmpty ? "#38BDF8" : interviewEngine.customCloudColorHex))
                        }

                        let popularPresets = [
                            CompanionAvatarLabCatalog.allPresets[0], // upward-side-glance
                            CompanionAvatarLabCatalog.allPresets[8], // curious-left
                            CompanionAvatarLabCatalog.allPresets[11], // joyful-wide
                            CompanionAvatarLabCatalog.allPresets[17], // playful-right
                            CompanionAvatarLabCatalog.allPresets[25], // angry-brows
                            CompanionAvatarLabCatalog.allPresets[26]  // uneasy-left
                        ]

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(popularPresets) { preset in
                                let isSelected = interviewEngine.selectedAvatarLabExpression == preset.semanticKey
                                Button(action: {
                                    ClickySoundEngine.shared.play(.send)
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                        interviewEngine.selectedAvatarLabExpression = preset.semanticKey
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Text(preset.badgeNumber)
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                                            )

                                        Text(preset.displayName)
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(isSelected ? Color(hex: interviewEngine.customCloudColorHex.isEmpty ? "#38BDF8" : interviewEngine.customCloudColorHex).opacity(0.28) : Color.white.opacity(0.04))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(isSelected ? Color(hex: interviewEngine.customCloudColorHex.isEmpty ? "#38BDF8" : interviewEngine.customCloudColorHex).opacity(0.6) : Color.white.opacity(0.08), lineWidth: 0.8)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 0.8))
                    )

                    // 4. Save & Launch Button
                    Button(action: {
                        _ = interviewEngine.finalizeAndLaunch()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isCreatingNewBuddy = false
                            newBuddyPromptText = ""
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                            Text("Save & Launch Companion")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#0F172A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#FDE047"), Color(hex: "#F59E0B")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: Color(hex: "#F59E0B").opacity(0.4), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }

    func animationRowView(_ anim: AvatarLabAnimation) -> some View {
        let isCurrent = animationEngine.currentSequence?.id == anim.id
        let isPlaying = isCurrent && animationEngine.isPlaying

        return HStack(spacing: 8) {
            Image(systemName: anim.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isPlaying ? Color(hex: "#10B981") : .white.opacity(0.6))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(anim.displayName)
                    .font(.system(size: 11, weight: isPlaying ? .bold : .medium, design: .rounded))
                    .foregroundColor(isPlaying ? .white : .white.opacity(0.85))

                Text("\(anim.steps.count) steps • \(String(format: "%.1f", Double(anim.totalDurationMs) / 1000.0))s")
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Button(action: {
                ClickySoundEngine.shared.play(.send)
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    animationEngine.toggle(sequence: anim) { step in
                        editAvatarLabExpression = step.semanticKey
                    }
                }
            }) {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isPlaying ? Color(hex: "#10B981") : .white.opacity(0.75))
                    .padding(6)
                    .background(
                        Circle().fill(isPlaying ? Color(hex: "#10B981").opacity(0.2) : Color.white.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isPlaying ? Color(hex: "#10B981").opacity(0.12) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isPlaying ? Color(hex: "#10B981").opacity(0.4) : Color.white.opacity(0.06), lineWidth: 0.8)
                )
        )
    }

    func avatarLabPresetDisplayName(_ id: String) -> String {
        switch id {
        case "neutral": return "Preset 01 (Neutral)"
        case "happy": return "Preset 04 (Happy)"
        case "preset-25": return "Preset 25 (Angry Brows)"
        case "preset-26": return "Preset 26 (Uneasy Sad)"
        case "preset-22": return "Preset 22 (Drowsy Flat)"
        case "surprised": return "Preset 07 (Surprised)"
        default: return id.capitalized
        }
    }

    func startEditing(session: BuddySession) {
        editName = session.name
        editRole = session.roleDescription
        editCloudColorHex = session.avatarColorHex
        editRingColorHex = session.ringColorHex.isEmpty ? "#BAE6FD" : session.ringColorHex
        editMood = session.mood
        editAvatarLabExpression = session.currentExpressionKey ?? "neutral"
        editSelectedTemplateId = session.templateId
        editWorkflowApps = session.workflowAppNames.isEmpty ? ["Mail", "Safari"] : session.workflowAppNames
        editSafariDomains = session.allowedSafariDomains.isEmpty ? "google.com, github.com" : session.allowedSafariDomains.joined(separator: ", ")
        editSafariTabMode = session.safariTabAccessMode.isEmpty ? "whitelist_only" : session.safariTabAccessMode
        if let animKey = session.animationKey, let anim = CompanionAvatarLabCatalog.animation(byKey: animKey) {
            animationEngine.play(sequence: anim) { step in
                editAvatarLabExpression = step.semanticKey
            }
        } else {
            animationEngine.stop()
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            isCharacterSidebarOpen = false
            isEditingCharacter = true
        }
    }

    func saveCharacterEdits() {
        guard !editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let targetId = companion.activeSessionID

        // Map Avatar Lab expression to AgentCloudFaceMood for complete backward-compat
        let mappedMood: AgentCloudFaceMood
        switch editAvatarLabExpression {
        case "happy": mappedMood = .happy
        case "surprised": mappedMood = .surprised
        case "preset-25", "preset-26", "preset-22": mappedMood = .thinking
        default: mappedMood = .focused
        }

        let chosenAnimationKey = animationEngine.isPlaying ? animationEngine.currentSequence?.semanticKey : nil
        let domainList = editSafariDomains.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        CompanionRosterStore.shared.updateCompanion(
            id: targetId,
            name: editName,
            role: editRole,
            cloudColorHex: editCloudColorHex,
            ringColorHex: editRingColorHex,
            mood: mappedMood,
            templateId: editSelectedTemplateId,
            animationKey: chosenAnimationKey,
            currentExpressionKey: editAvatarLabExpression,
            workflowAppNames: editWorkflowApps,
            allowedSafariDomains: domainList,
            safariTabAccessMode: editSafariTabMode
        )
        companion.updateSessionColorsAndDetails(
            companionId: targetId,
            name: editName,
            role: editRole,
            cloudColorHex: editCloudColorHex,
            ringColorHex: editRingColorHex,
            mood: mappedMood,
            templateId: editSelectedTemplateId,
            animationKey: chosenAnimationKey,
            currentExpressionKey: editAvatarLabExpression,
            workflowAppNames: editWorkflowApps,
            allowedSafariDomains: domainList,
            safariTabAccessMode: editSafariTabMode
        )
        if let updatedProfile = CompanionRosterStore.shared.allCompanions.first(where: { $0.id == targetId }) {
            _ = CompanionWorkspaceManager.shared.generateCompanionSpec(for: updatedProfile)
        }
        ClickySoundEngine.shared.play(.done)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            isEditingCharacter = false
            activeViewMode = .chats
        }
    }

    func isThemeSelected(_ theme: CompanionColorTheme) -> Bool {
        theme.cloudColorHex.caseInsensitiveCompare(editCloudColorHex) == .orderedSame &&
        theme.ringColorHex.caseInsensitiveCompare(editRingColorHex) == .orderedSame
    }
}

// (ThemeSwatchButton, FollowUpPillButton, and MarkdownFormattedMessageView extracted to Components/)
