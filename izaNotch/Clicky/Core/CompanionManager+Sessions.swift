//
//  CompanionManager+Sessions.swift
//  izaNotch (Izanotchy)
//
//  Decomposed extension for CompanionManager.
//

import AppKit
import AVFoundation
import Combine
import CoreGraphics
import Defaults
import Foundation
import SwiftUI

extension CompanionManager {
    public func syncSessionsFromRoster(_ profiles: [CompanionProfile], activeId: UUID? = nil) {
        guard !profiles.isEmpty else { return }

        var updatedSessions: [BuddySession] = []
        for profile in profiles {
            let lastSnippet = profile.messages.last?.text ?? (profile.lastMessage.isEmpty ? profile.role : profile.lastMessage)
            let session = BuddySession(
                id: profile.id,
                name: profile.name,
                roleDescription: profile.role,
                avatarColorHex: profile.cloudColorHex,
                ringColorHex: profile.ringColorHex,
                mood: profile.mood,
                timestampString: "Just now",
                lastSnippet: lastSnippet,
                messages: profile.messages,
                isUnread: profile.hasUnreadMessages,
                templateId: profile.templateId,
                animationKey: profile.animationKey,
                currentExpressionKey: profile.currentExpressionKey,
                workflowAppNames: profile.workflowAppNames,
                executionDomain: profile.executionDomain,
                allowedSafariDomains: profile.allowedSafariDomains,
                safariTabAccessMode: profile.safariTabAccessMode
            )
            updatedSessions.append(session)
        }
        self.sessions = updatedSessions

        let targetId = activeId ?? self.activeSessionID
        if let target = updatedSessions.first(where: { $0.id == targetId }) {
            self.activeSessionID = target.id
            self.chatMessages = target.messages
            if let targetProfile = profiles.first(where: { $0.id == target.id }) {
                self.activeCompanion = targetProfile
            }
        } else if !updatedSessions.contains(where: { $0.id == activeSessionID }), let first = updatedSessions.first {
            self.activeSessionID = first.id
            self.chatMessages = first.messages
            if let firstProfile = profiles.first(where: { $0.id == first.id }) {
                self.activeCompanion = firstProfile
            }
        }
        ClickyLogger.info("[ROSTER_SYNC]", "Synchronized \(updatedSessions.count) sessions from roster store. Active: \(activeSessionID)")
    }

    public func updateSessionColorsAndDetails(
        companionId: UUID? = nil,
        name: String,
        role: String,
        cloudColorHex: String,
        ringColorHex: String,
        mood: AgentCloudFaceMood? = nil,
        templateId: String? = nil,
        animationKey: String? = nil,
        currentExpressionKey: String? = nil,
        workflowAppNames: [String]? = nil,
        allowedSafariDomains: [String]? = nil,
        safariTabAccessMode: String? = nil
    ) {
        if let targetId = companionId, let idx = sessions.firstIndex(where: { $0.id == targetId }) {
            sessions[idx].name = name
            sessions[idx].roleDescription = role
            sessions[idx].avatarColorHex = cloudColorHex
            sessions[idx].ringColorHex = ringColorHex
            if let mood = mood {
                sessions[idx].mood = mood
            }
            if let templateId = templateId {
                sessions[idx].templateId = templateId
            }
            if let animationKey = animationKey {
                sessions[idx].animationKey = animationKey
            }
            if let currentExpressionKey = currentExpressionKey {
                sessions[idx].currentExpressionKey = currentExpressionKey
            }
            if let apps = workflowAppNames {
                sessions[idx].workflowAppNames = apps
            }
            if let domains = allowedSafariDomains {
                sessions[idx].allowedSafariDomains = domains
            }
            if let mode = safariTabAccessMode {
                sessions[idx].safariTabAccessMode = mode
            }
        } else if let idx = sessions.firstIndex(where: {
            $0.name.lowercased() == name.lowercased() ||
            name.lowercased().contains($0.name.lowercased()) ||
            $0.name.lowercased().contains(name.lowercased())
        }) {
            sessions[idx].name = name
            sessions[idx].roleDescription = role
            sessions[idx].avatarColorHex = cloudColorHex
            sessions[idx].ringColorHex = ringColorHex
            if let mood = mood {
                sessions[idx].mood = mood
            }
            if let templateId = templateId {
                sessions[idx].templateId = templateId
            }
            if let animationKey = animationKey {
                sessions[idx].animationKey = animationKey
            }
            if let currentExpressionKey = currentExpressionKey {
                sessions[idx].currentExpressionKey = currentExpressionKey
            }
        }
    }

    public func appendChatMessage(_ message: HomeSpaceChatMessage) {
        let cleanText = Self.stripTechnicalTags(from: message.text)
        guard !cleanText.isEmpty || message.computerPayload != nil || !message.attachments.isEmpty else { return }

        // Anti-duplicate guard: ignore identical user message submitted within 2.0s
        if message.isUser, let last = chatMessages.last, last.isUser && last.text == cleanText && abs(last.timestamp.timeIntervalSince(message.timestamp)) < 2.0 && message.attachments.isEmpty {
            return
        }

        if !message.isUser {
            disarmStreamingWatchdog()
            self.isHomeSpaceStreaming = false
            self.homeSpaceStreamingText = ""
        }
        let sanitizedMessage = HomeSpaceChatMessage(
            id: message.id,
            isUser: message.isUser,
            text: cleanText,
            timestamp: message.timestamp,
            computerPayload: message.computerPayload,
            egressResult: message.egressResult ?? message.computerPayload?.egressResult,
            attachments: message.attachments,
            voiceMemo: message.voiceMemo,
            liveVoiceChat: message.liveVoiceChat,
            senderCompanionSlug: message.senderCompanionSlug,
            replyToMessageId: message.replyToMessageId
        )
        chatMessages.append(sanitizedMessage)
        if let payload = sanitizedMessage.computerPayload {
            self.activeComputerPayload = payload
            self.isWorkspaceCollapsed = false
        }
        if let idx = sessions.firstIndex(where: { $0.id == activeSessionID }) {
            sessions[idx].messages.append(sanitizedMessage)
            sessions[idx].lastSnippet = cleanText.isEmpty ? (message.computerPayload?.cardTitle ?? "Computer") : cleanText
            sessions[idx].timestampString = "Just now"
            CompanionRosterStore.shared.appendMessage(sanitizedMessage, forCompanionId: sessions[idx].id)
        }
    }

    public func updateChatMessage(id: UUID, computerPayload: ComputerCardPayload?, text: String? = nil, egressResult: EgressResult? = nil) {
        if let payload = computerPayload {
            self.activeComputerPayload = payload
        }
        let effectiveEgress = egressResult ?? computerPayload?.egressResult
        if let idx = chatMessages.firstIndex(where: { $0.id == id }) {
            if let payload = computerPayload {
                chatMessages[idx].computerPayload = payload
            }
            if let eg = effectiveEgress {
                chatMessages[idx].egressResult = eg
            }
            if let newText = text {
                chatMessages[idx].text = newText
            }
        }
        if let sIdx = sessions.firstIndex(where: { $0.id == activeSessionID }) {
            if let mIdx = sessions[sIdx].messages.firstIndex(where: { $0.id == id }) {
                if let payload = computerPayload {
                    sessions[sIdx].messages[mIdx].computerPayload = payload
                }
                if let eg = effectiveEgress {
                    sessions[sIdx].messages[mIdx].egressResult = eg
                }
                if let newText = text {
                    sessions[sIdx].messages[mIdx].text = newText
                    sessions[sIdx].lastSnippet = newText
                }
            }
        }
        CompanionRosterStore.shared.updateMessage(id: id, computerPayload: computerPayload, text: text, forCompanionId: activeSessionID)
        objectWillChange.send()
    }
    public func selectCompanion(bySlug slug: String) {
        if let session = sessions.first(where: { $0.slug == slug || $0.name.lowercased().replacingOccurrences(of: " ", with: "-") == slug }) {
            selectSession(id: session.id)
            ClickyLogger.info("[ROSTER]", "Switched active companion to '\(session.name)' (slug=\(session.slug))")
        }
    }

    public func selectSession(id: UUID, syncRoster: Bool = true) {
        guard let session = sessions.first(where: { $0.id == id }) else { return }
        activeSessionID = id
        chatMessages = session.messages
        activeComputerPayload = session.messages.reversed().first(where: { $0.computerPayload != nil })?.computerPayload
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].isUnread = false
        }
        CompanionRosterStore.shared.markAsRead(name: session.name)
        if let matchingCompanion = CompanionRosterStore.shared.allCompanions.first(where: { $0.id == id }) {
            setActiveCompanion(matchingCompanion)
            if syncRoster && CompanionRosterStore.shared.activeCompanionId != id {
                CompanionRosterStore.shared.selectCompanion(id: id, syncManager: false)
            }
            // Domain-aware CUA daemon lifecycle (Milestone 199 / Opsi 2)
            if matchingCompanion.isSandboxedVM || matchingCompanion.executionDomain == .virtualSandbox {
                CuaDriverClient.shared.stopDaemon()
                ClickyLogger.info("[CUA_DRIVER]", "Switched to sandboxed companion '\(matchingCompanion.name)'; host CUA daemon stopped.")
            } else if matchingCompanion.executionDomain == .macHost {
                CuaDriverClient.shared.warmUp()
                ClickyLogger.info("[CUA_DRIVER]", "Switched to Mac host companion '\(matchingCompanion.name)'; host CUA daemon pre-warmed.")
            }
        }
        ClickyLogger.info("[HOMESPACE]", "Switched to session: \(session.name)")
    }

    public func selectSession(named name: String) {
        if let session = sessions.first(where: { $0.name.lowercased() == name.lowercased() || name.lowercased().contains($0.name.lowercased()) || $0.name.lowercased().contains(name.lowercased()) }) {
            selectSession(id: session.id)
        }
    }

    public func createNewBuddy(name: String = "New Clicky", role: String = "General Assistant", avatarColorHex: String = "#A7F3D0") {
        let newSession = BuddySession(
            name: name,
            roleDescription: role,
            avatarColorHex: avatarColorHex,
            timestampString: "Just now",
            lastSnippet: "Tell me what you want this Clicky to take on...",
            messages: []
        )
        sessions.insert(newSession, at: 0)
        selectSession(id: newSession.id)
    }

    public func deleteSession(id: UUID) {
        guard sessions.count > 1 else { return }
        CompanionRosterStore.shared.deleteCompanion(id: id)
    }

    public func clearMessages(for id: UUID) {
        if let idx = sessions.firstIndex(where: { $0.id == id }) {
            sessions[idx].messages = []
            sessions[idx].lastSnippet = ""
        }
        CompanionRosterStore.shared.clearMessages(for: id)
    }

    /// True when all three required permissions (accessibility, screen recording,
    /// microphone) are granted. Used by the panel to show a single "all good" state.
    var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasScreenRecordingPermission && hasMicrophonePermission && hasScreenContentPermission
    }

    public var currentCursorColor: Color {
        activeCompanion.cloudColor
    }

    public func setActiveCompanion(_ profile: CompanionProfile) {
        self.activeCompanion = profile
        ClickyLogger.info("[ROSTER]", "Active companion switched to \(profile.name) (\(profile.cloudColorHex))")
    }
}
