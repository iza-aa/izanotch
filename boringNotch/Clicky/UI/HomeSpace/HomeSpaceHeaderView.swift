//
//  HomeSpaceHeaderView.swift
//  boringNotch (Izanotchy)
//
//  Decomposed extension for HomeSpaceRootView.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

extension HomeSpaceRootView {
    // MARK: - Header Center Switcher (1:1 Foto 2 & Foto 3)
    // Sits in 1 row inside the card header, frameless (no rounded pill card behind it)
    var headerCenterSwitcher: some View {
        Button(action: {
            ClickySoundEngine.shared.play(.open)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                isCharacterSidebarOpen.toggle()
            }
        }) {
            HStack(spacing: 7) {
                // Standalone Mascot 3D Strobi (Zero backing circle, clean and frameless)
                let switcherExpression = animationEngine.isPlaying ? animationEngine.currentExpressionKey : (companion.activeBuddy.currentExpressionKey ?? "happy")
                CompanionProceduralAvatarView(
                    definition: companion.activeBuddy.avatarDefinition,
                    expressionName: switcherExpression,
                    autoBlink: false,
                    size: 20
                )

                Text(companion.activeBuddy.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("View & edit character details")
    }

    // MARK: - Character Inspector Sidebar (1:1 Foto 1, Section 3 Slide-Over Drawer)
    var characterInspectorSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isCharacterSidebarOpen = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Close character inspector")

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    // Large Character Avatar with Circular Theme Backing
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: companion.activeBuddy.avatarColorHex.isEmpty ? "#38BDF8" : companion.activeBuddy.avatarColorHex))
                                .frame(width: 80, height: 80)
                                .blur(radius: 18)
                                .opacity(0.6)

                            CompanionProceduralAvatarView(
                                definition: companion.activeBuddy.avatarDefinition,
                                expressionName: "happy",
                                autoBlink: true,
                                size: 76
                            )
                        }
                        .frame(width: 96, height: 96)
                        .padding(.top, 4)

                        // 'Edit character' Button (Foto 1)
                        Button(action: {
                            ClickySoundEngine.shared.play(.open)
                            startEditing(session: companion.activeBuddy)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Edit character")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#0F172A"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }

                    // Name, Role & Bio
                    VStack(spacing: 4) {
                        Text(companion.activeBuddy.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text(companion.activeBuddy.roleDescription)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        Text("Digs into companies, markets, and competitors and hands you a tidy report.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                    }

                    // Section: ROUTINES (Foto 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROUTINES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No routines yet. Ask this Clicky to do something \"every morning\", \"every few hours\", or \"every Monday\" and it will run here on repeat.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .lineSpacing(2.5)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                                )
                        )
                    }

                    // Section: ARTIFACTS (Foto 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ARTIFACTS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))

                        // Sample Document Artifact Card (Foto 1)
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#FEF3C7"))
                                .frame(height: 70)
                                .overlay(
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color(hex: "#D97706"))
                                )

                            Text("spacex_c...pshot.pdf")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text("PDF • Open")
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(10)
                        .frame(width: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                                )
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Section: PERSONA SPEC & MEMORY (.md)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PERSONA SPEC & RULES (.md)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))

                        Button(action: {
                            ClickySoundEngine.shared.play(.open)
                            let targetSlug = companion.activeBuddy.name.lowercased().replacingOccurrences(of: " ", with: "-")
                            let workspace = CompanionWorkspaceManager.shared.workspaceURL(for: targetSlug)
                            let specFile = workspace.appendingPathComponent("\(targetSlug).md")
                            if !FileManager.default.fileExists(atPath: specFile.path) {
                                if let profile = CompanionRosterStore.shared.allCompanions.first(where: { $0.id == companion.activeSessionID }) {
                                    _ = CompanionWorkspaceManager.shared.generateCompanionSpec(for: profile)
                                } else {
                                    let dummyProfile = CompanionProfile(
                                        slug: targetSlug,
                                        name: companion.activeBuddy.name,
                                        role: companion.activeBuddy.roleDescription,
                                        summary: companion.activeBuddy.roleDescription,
                                        cloudColorHex: companion.activeBuddy.avatarColorHex,
                                        ringColorHex: companion.activeBuddy.ringColorHex
                                    )
                                    _ = CompanionWorkspaceManager.shared.generateCompanionSpec(for: dummyProfile)
                                }
                            }
                            NSWorkspace.shared.open(specFile)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: companion.activeBuddy.avatarColorHex))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(companion.activeBuddy.name.lowercased().replacingOccurrences(of: " ", with: "-")).md")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)

                                    Text("Open local file in default editor")
                                        .font(.system(size: 9.5, weight: .regular))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Open markdown persona specification file")
                    }

                    if companion.sessions.count > 1 {
                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.vertical, 4)

                        Button(action: {
                            ClickySoundEngine.shared.play(.close)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                isCharacterSidebarOpen = false
                                companion.deleteSession(id: companion.activeSessionID)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Delete character")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundColor(Color.red.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.red.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.red.opacity(0.25), lineWidth: 0.8)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 270)
        .background(Color(hex: "#161719"))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1),
            alignment: .leading
        )
    }

    var currentPresetDisplayName: String {
        if let p = CompanionAvatarLabCatalog.allPresets.first(where: { $0.semanticKey == editAvatarLabExpression || $0.id == editAvatarLabExpression }) {
            return "\(p.badgeNumber)  \(p.displayName)"
        }
        return "00  Neutral Upward"
    }

    var currentAnimationDisplayName: String {
        if let s = animationEngine.currentSequence {
            return s.displayName
        }
        return "Select Sequence (23 available)..."
    }

    var editingSessionSlug: String {
        let sanitized = editName.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        if !sanitized.isEmpty {
            return sanitized
        }
        return companion.activeBuddy.slug
    }

}
