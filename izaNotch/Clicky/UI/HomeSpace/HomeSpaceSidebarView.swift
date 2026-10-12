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
                GrokBotMarkView(
                    name: currentSession.name,
                    tintColorHex: currentSession.avatarColorHex,
                    size: 26,
                    isSelected: true
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
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isSidebarCollapsed.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.70))
                            Text("Teammates")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
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
                            GrokBotMarkView(
                                name: session.name,
                                tintColorHex: session.avatarColorHex,
                                size: 30,
                                isWorking: companion.isProcessingTask && isSelected,
                                isSelected: isSelected
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(session.name)
                                        .font(.system(size: 12.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                                        .foregroundColor(.white)

                                    Spacer(minLength: 4)

                                    if companion.isProcessingTask && isSelected {
                                        Text("Working")
                                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(hex: "#38BDF8"))
                                    } else {
                                        Text(session.timestampString)
                                            .font(.system(size: 10, weight: .regular))
                                            .foregroundColor(.white.opacity(0.40))
                                    }
                                }

                                Text(session.lastSnippet.isEmpty ? session.roleDescription : session.lastSnippet)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(.white.opacity(isSelected ? 0.75 : 0.45))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.02))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isSelected ? Color.white.opacity(0.14) : Color.clear, lineWidth: 0.8)
                                )
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

            // Sub-Section 1C: Bottom Account & Computer Status Dock (Grok Bot 1:1)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // User avatar initial circle
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 0.8))

                        Text(String(displayEmail.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayEmail)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: "#10B981"))
                                .frame(width: 5, height: 5)
                            Text("Agent Computer: Ready")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.50))
                        }
                    }

                    Spacer()

                    Button(action: {
                        SettingsWindowController.shared.showWindow()
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Grok Bot Settings (Cmd+,)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.20))
                    .overlay(
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.8),
                        alignment: .top
                    )
            )
        }
    }

}
