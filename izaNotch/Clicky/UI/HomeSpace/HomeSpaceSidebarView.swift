//
//  HomeSpaceSidebarView.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for HomeSpaceRootView.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

extension HomeSpaceRootView {
    // MARK: - Section 1: Sidebar View
    var sidebarView: some View {
        VStack(spacing: 0) {
            if isCharacterSettingsActive {
                settingsSidebarView
            } else {
                chatSidebarView
            }
        }
    }

    // MARK: - Section 1-Settings: Dedicated Character Settings Sidebar
    var settingsSidebarView: some View {
        VStack(spacing: 0) {
            // Top Left: Back to Chat Button (Replaces the 'iza' logo)
            HStack {
                Button(action: {
                    ClickySoundEngine.shared.play(.close)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isEditingCharacter = false
                        activeViewMode = .chats
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Back to Chat")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .help("Return to chat workspace")

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Vertical 2-Item Navigation List (Edit Character & Connected Apps)
            VStack(spacing: 5) {
                // Option 1: Edit Character
                let isEditSelected = activeViewMode == .editCharacter || (isEditingCharacter && activeViewMode != .connectedApps)
                Button(action: {
                    ClickySoundEngine.shared.play(.send)
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                        activeViewMode = .editCharacter
                        isEditingCharacter = true
                        startEditing(session: companion.activeBuddy)
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 13, weight: isEditSelected ? .bold : .medium))
                            .foregroundColor(isEditSelected ? Color(hex: "#38BDF8") : .white.opacity(0.60))
                            .frame(width: 18)

                        Text("Edit Character")
                            .font(.system(size: 12.5, weight: isEditSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isEditSelected ? .white : .white.opacity(0.70))

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isEditSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(isEditSelected ? Color.white.opacity(0.16) : Color.clear, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)

                // Option 2: Connected Apps
                let isAppsSelected = activeViewMode == .connectedApps
                Button(action: {
                    ClickySoundEngine.shared.play(.send)
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.85)) {
                        activeViewMode = .connectedApps
                        isEditingCharacter = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 13, weight: isAppsSelected ? .bold : .medium))
                            .foregroundColor(isAppsSelected ? Color(hex: "#38BDF8") : .white.opacity(0.60))
                            .frame(width: 18)

                        Text("Connected Apps")
                            .font(.system(size: 12.5, weight: isAppsSelected ? .bold : .medium, design: .rounded))
                            .foregroundColor(isAppsSelected ? .white : .white.opacity(0.70))

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isAppsSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.02))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(isAppsSelected ? Color.white.opacity(0.16) : Color.clear, lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)

            Spacer()

            // Active Companion Quick Info Card at Bottom of Settings Sidebar
            let currentSession = companion.activeBuddy
            HStack(spacing: 9) {
                CompanionProceduralAvatarView(
                    definition: currentSession.avatarDefinition,
                    expressionName: currentSession.currentExpressionKey ?? "happy",
                    autoBlink: true,
                    size: 26
                )
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(currentSession.name)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(currentSession.roleDescription)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.50))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                    )
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Section 1-Chat: Normal Chat Sidebar View
    var chatSidebarView: some View {
        VStack(spacing: 0) {
            // Sub-Section 1A: Top Controls & Search
            VStack(spacing: 12) {
                HStack {
                    // Iza White Logo Button (Frameless, NO rounded card background)
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isSidebarCollapsed.toggle()
                        }
                    }) {
                        Image("iza-logo-white")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 19)
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Sidebar")

                    Spacer()
                }
                .frame(height: 24)

                // Search Bar with '+' Button on Right
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))

                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)

                    Spacer(minLength: 0)

                    // Create New Buddy / Session Button ('+' in Foto 4)
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            interviewEngine.reset()
                            isCreatingNewBuddy = true
                            isCharacterSidebarOpen = false
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Create a new Clicky companion")
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Sub-Section 1B: Scrollable Buddy Sessions List (Foto 3 Sky-Blue Gel Style)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(filteredSessions) { session in
                        let isSelected = session.id == companion.activeSessionID
                        HStack(spacing: 9) {
                            // Avatar 3D Strobi (Zero Aura, Solid 3D Avatar Lab)
                            let activeExpression: String = {
                                if isSelected && animationEngine.isPlaying {
                                    return animationEngine.currentExpressionKey
                                }
                                if let animKey = session.animationKey, !animKey.isEmpty {
                                    return animKey
                                }
                                if let expr = session.currentExpressionKey, !expr.isEmpty {
                                    return expr
                                }
                                return isSelected ? "happy" : "neutral"
                            }()

                            CompanionProceduralAvatarView(
                                definition: session.avatarDefinition,
                                expressionName: activeExpression,
                                autoBlink: true,
                                size: 32
                            )
                            .frame(width: 34, height: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(session.name)
                                        .font(.system(size: 12.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(isSelected ? Color(hex: "#0F172A") : .white)

                                    Spacer(minLength: 4)

                                    Text(session.timestampString)
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundColor(isSelected ? Color(hex: "#0F172A").opacity(0.65) : .white.opacity(0.45))
                                }

                                Text(session.lastSnippet.isEmpty ? session.roleDescription : session.lastSnippet)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(isSelected ? Color(hex: "#1E293B") : .white.opacity(0.5))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            Group {
                                if isSelected {
                                    ZStack {
                                        // Sky-blue Gel Capsule (Foto 3 / Foto 5)
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "#C7E5FE"), Color(hex: "#8EC5FC")],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )

                                        // Specular top highlight
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.2)],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                                } else {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.clear)
                                }
                            }
                        )
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                companion.selectSession(id: session.id)
                                ClickySoundEngine.shared.play(.open)
                                startEditing(session: session)
                            }
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                companion.selectSession(id: session.id)
                                if isEditingCharacter {
                                    startEditing(session: session)
                                }
                            }
                        }
                        .contextMenu {
                            Button {
                                companion.selectSession(id: session.id)
                                ClickySoundEngine.shared.play(.open)
                                startEditing(session: session)
                            } label: {
                                Label("Edit Character", systemImage: "pencil")
                            }

                            Button {
                                ClickySoundEngine.shared.play(.open)
                                CompanionWorkspaceManager.shared.openWorkspaceInFinder(for: session.slug)
                            } label: {
                                Label("Open Workspace", systemImage: "folder")
                            }

                            if !session.messages.isEmpty {
                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        companion.clearMessages(for: session.id)
                                    }
                                } label: {
                                    Label("Clear Chat", systemImage: "arrow.counterclockwise")
                                }
                            }

                            if companion.sessions.count > 1 {
                                Divider()
                                Button(role: .destructive) {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        companion.deleteSession(id: session.id)
                                    }
                                } label: {
                                    Label("Delete Character", systemImage: "trash")
                                }
                            }
                        }
                        .help("Double-click or right-click to edit character")
                    }
                }
                .padding(.horizontal, 10)
            }

            // Sub-Section 1C: Bottom Account Dock (Foto 2 Pro Badge & Foto 5 Gel Quota Bar)
            // NO horizontal line Divider, NO Apps+, NO i, NO settings gear
            VStack(spacing: 8) {
                // Row 1: Apple Intelligence Profile (Clean, minimal, titanium)
                HStack(spacing: 8) {
                    // Apple Logo Smoked Titanium Circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#27272A"), Color(hex: "#18181B")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.30), Color.white.opacity(0.08)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.8
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 3)

                        Image(systemName: "apple.logo")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.white, Color(hex: "#CBD5E1")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    // Title - "Apple Intelligence"
                    Text("Apple Intelligence")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)

                    Spacer()
                }

                // Row 2: Smoked Titanium Capsule Bar (Neural Engine)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Dark glossy capsule track
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#1E2024"), Color(hex: "#141518")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.20), Color.white.opacity(0.06)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.8
                                    )
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)

                        // Subtle inner highlight
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.04), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // Status text (Neural Engine, platinum silver)
                        HStack {
                            Spacer()
                            Text("Neural Engine")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "#F1F5F9"))
                            Spacer()
                        }
                    }
                }
                .frame(height: 18)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

}
