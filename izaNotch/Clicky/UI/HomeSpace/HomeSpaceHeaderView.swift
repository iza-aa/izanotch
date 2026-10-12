//
//  HomeSpaceHeaderView.swift
//  izaNotch (Izanotchy)
//
//  Faithful 1:1 Grok Bot (x.ai/bot) Workspace Header Component.
//  Clean Teammate identification, live Agent Computer status pill, voice chat, and options.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

extension HomeSpaceRootView {
    // MARK: - Grok Bot Header Bar
    var grokBotHeaderBar: some View {
        HStack(spacing: 12) {
            // Left: Active Teammate Identification (Mark + Name + Role)
            HStack(spacing: 10) {
                GrokBotMarkView(
                    name: companion.activeBuddy.name,
                    tintColorHex: companion.activeBuddy.avatarColorHex,
                    size: 32,
                    isWorking: companion.isProcessingTask,
                    isSelected: true
                )

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(companion.activeBuddy.name)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(companion.activeBuddy.roleDescription.isEmpty ? "AI Teammate" : companion.activeBuddy.roleDescription)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right: Agent Computer Status Button + Voice + Options + Close
            HStack(spacing: 8) {
                // Agent Computer Status Pill Button (Grok Bot 1:1)
                Button(action: {
                    ClickySoundEngine.shared.play(.open)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        activeComputerModalPayload = ComputerCardPayload(
                            cardTitle: "Computer",
                            status: companion.isProcessingTask ? .working : .done,
                            instructionText: "Chromium Workspace terisolasi untuk \(companion.activeBuddy.name)",
                            snapshotImagePath: CompanionVMViewportController.shared.activeSnapshotPath,
                            targetAppName: "Chromium Workspace",
                            activeWorkflowApp: "Chromium Workspace",
                            queueSummary: "Agent Computer"
                        )
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "display")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(computerStatusColor)

                        Circle()
                            .fill(computerStatusColor)
                            .frame(width: 5.5, height: 5.5)

                        Text(computerStatusText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(computerStatusColor.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(computerStatusColor.opacity(0.32), lineWidth: 0.8)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Open Agent Computer viewport and controls")

                // Live Voice Chat Button
                Button(action: {
                    LiveVoiceChatManager.shared.toggleLiveVoiceChat(companionSlug: companion.activeBuddy.slug)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: LiveVoiceChatManager.shared.isCallActive ? "phone.down.fill" : "phone.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LiveVoiceChatManager.shared.isCallActive ? Color(hex: "#EF4444") : Color(hex: "#38BDF8"))
                        Text(LiveVoiceChatManager.shared.isCallActive ? "Akhiri Panggilan" : "Voice")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(LiveVoiceChatManager.shared.isCallActive ? Color(hex: "#EF4444").opacity(0.18) : Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(LiveVoiceChatManager.shared.isCallActive ? Color(hex: "#EF4444").opacity(0.4) : Color.white.opacity(0.10), lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)
                .help(LiveVoiceChatManager.shared.isCallActive ? "Akhiri sesi voice chat" : "Mulai live voice chat dengan \(companion.activeBuddy.name)")

                // Options Menu (...)
                Menu {
                    Button("Edit Bot Profile") {
                        startEditing(session: companion.activeBuddy)
                    }

                    Button("Share Bot Template") {
                        NotificationCenter.default.post(name: Notification.Name("HomeSpaceShareTemplate"), object: companion.activeBuddy)
                    }

                    Button("Duplicate Bot") {
                        CompanionRosterStore.shared.duplicateCompanion(id: companion.activeBuddy.id)
                    }

                    Button("Pin to Rail") {
                        CompanionRosterStore.shared.togglePin(id: companion.activeBuddy.id)
                    }

                    Divider()

                    Button("Delete Bot", role: .destructive) {
                        CompanionRosterStore.shared.deleteCompanion(id: companion.activeBuddy.id)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.65))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .menuStyle(.borderlessButton)
                .help("Bot settings and actions")

                // Close Button (✕)
                Button(action: {
                    ClickySoundEngine.shared.play(.close)
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Close back to notch")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var computerStatusColor: Color {
        if CompanionVMViewportController.shared.isTakeoverActive {
            return Color(hex: "#F59E0B") // Amber takeover
        }
        if companion.isProcessingTask {
            return Color(hex: "#38BDF8") // Blue working
        }
        return Color(hex: "#10B981") // Green ready
    }

    private var computerStatusText: String {
        if CompanionVMViewportController.shared.isTakeoverActive {
            return "Takeover Active"
        }
        if companion.isProcessingTask {
            return "Working"
        }
        return "Computer Ready"
    }
}
