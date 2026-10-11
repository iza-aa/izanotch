//
//  CompanionRosterStore.swift
//  izaNotch
//
//  Created for Izanotchy - Multi-Agent Desktop System
//

import SwiftUI
import Combine

@MainActor
public final class CompanionRosterStore: ObservableObject {
    public static let shared = CompanionRosterStore()
    
    private let rosterKey = "Izanotchy.CompanionRoster.Profiles"
    private let activeKey = "Izanotchy.CompanionRoster.ActiveID"
    private let railCollapsedKey = "Izanotchy.CompanionRoster.RailCollapsed"
    
    @Published public var allCompanions: [CompanionProfile] = [] {
        didSet {
            persist()
            CompanionManager.shared.syncSessionsFromRoster(allCompanions, activeId: activeCompanionId)
        }
    }
    
    @Published public var activeCompanionId: UUID {
        didSet {
            UserDefaults.standard.set(activeCompanionId.uuidString, forKey: activeKey)
            syncWithCompanionManager()
        }
    }
    
    @Published public var isRailCollapsed: Bool {
        didSet {
            UserDefaults.standard.set(isRailCollapsed, forKey: railCollapsedKey)
        }
    }
    
    @Published public var activePopoverCompanionId: UUID? = nil
    @Published public var isOverflowOpen: Bool = false
    @Published public var presentedRailCompanionIds: Set<UUID> = []
    @Published public var dismissedCompanionIds: Set<UUID> = []
    
    private init() {
        self.isRailCollapsed = UserDefaults.standard.bool(forKey: railCollapsedKey)
        
        let loadedCompanions: [CompanionProfile]
        if let savedData = UserDefaults.standard.data(forKey: rosterKey),
           let decoded = try? JSONDecoder().decode([CompanionProfile].self, from: savedData),
           !decoded.isEmpty {
            loadedCompanions = decoded
        } else {
            loadedCompanions = CompanionProfile.defaultStarters
        }
        var companions = loadedCompanions

        // User Request (Point 7): Prune all companions and chats except Futures Scout
        let scoutFound = companions.first(where: { $0.slug == "futures-scout" || $0.name.lowercased().contains("futures scout") })
        let scoutProfile: CompanionProfile
        if let existingScout = scoutFound {
            var s = existingScout
            s.messages = []
            s.lastMessage = ""
            s.status = .idle
            s.hasUnreadMessages = false
            if s.cloudColorHex.isEmpty { s.cloudColorHex = "#905AFD" }
            if s.ringColorHex.isEmpty { s.ringColorHex = "#E9D5FF" }
            scoutProfile = s
        } else {
            scoutProfile = CompanionProfile(
                id: UUID(uuidString: "905BEB7D-0477-44B4-BEA2-1D4202F258E6") ?? UUID(),
                slug: "futures-scout",
                name: "Futures Scout",
                role: "Senior Crypto & Macro Analyst",
                summary: "Analisis teknikal, chart TradingView, dan kalkulasi risiko pasar berjangka.",
                cloudColorHex: "#905AFD",
                ringColorHex: "#E9D5FF",
                status: .idle,
                lastMessage: "",
                activeSkills: ["tradingview", "market-analysis"],
                mdPath: "futures-scout.md",
                isPinnedToRail: true,
                templateId: "strobi"
            )
        }

        // Keep only Futures Scout and user-created characters; eliminate starter bots (Research Buddy, Shippy, Clicky)
        // Keep Futures Scout, Clicky (canonical native CUA companion without connected apps — TASK-046 Principle 1), and user companions
        var filteredCompanions = loadedCompanions.filter {
            $0.slug != "research-buddy" && $0.slug != "shippy"
        }
        if !filteredCompanions.contains(where: { $0.slug == "clicky" }) {
            var clicky = CompanionProfile.defaultClicky
            clicky.workflowAppNames = []
            filteredCompanions.append(clicky)
        }
        if !filteredCompanions.contains(where: { $0.slug == "futures-scout" || $0.name.lowercased().contains("futures scout") }) {
            filteredCompanions.insert(scoutProfile, at: 0)
        }

        // Clean up any residual initial greetings from companions so they open in clean welcome state
        filteredCompanions = filteredCompanions.map { comp in
            var c = comp
            if c.slug == "clicky" {
                c.workflowAppNames = []
            }
            if c.slug == "inbox-buddy" {
                c.messages = []
                c.lastMessage = ""
            }
            return c
        }

        self.allCompanions = filteredCompanions
        self.activeCompanionId = filteredCompanions.first?.id ?? scoutProfile.id
        self.presentedRailCompanionIds.removeAll()
        self.dismissedCompanionIds.removeAll()

        persist()
        syncWithCompanionManager()
        
        // Ensure isolated workspace hierarchy & persona spec files exist in ~/.izanotchy/companions/
        for comp in filteredCompanions {
            CompanionWorkspaceManager.shared.ensureWorkspaceHierarchy(for: comp.slug)
            CompanionWorkspaceManager.shared.saveProfileJSON(for: comp)
            let spec = CompanionWorkspaceManager.shared.companionBaseURL(for: comp.slug).appendingPathComponent("persona.md")
            if !FileManager.default.fileExists(atPath: spec.path) {
                _ = CompanionWorkspaceManager.shared.generateCompanionSpec(for: comp)
            }
        }

        // Prune orphan workspace directories on disk (Option 1 Clean Sandboxing)
        let activeSlugs = Set(filteredCompanions.map { $0.slug })
        CompanionWorkspaceManager.shared.pruneOrphanWorkspaces(activeSlugs: activeSlugs)
    }
    
    public var activeCompanion: CompanionProfile {
        allCompanions.first(where: { $0.id == activeCompanionId }) ?? allCompanions.first ?? CompanionProfile.defaultResearchBuddy
    }
    
    /// Returns the top 3 companions assigned to the rail
    public var railSlots: [CompanionProfile] {
        var slots: [CompanionProfile] = []
        // Slot 0 is always the active companion
        slots.append(activeCompanion)
        
        for c in allCompanions where c.id != activeCompanion.id {
            if slots.count < 3 {
                slots.append(c)
            }
        }
        return slots
    }
    
    /// Companions beyond the 3 slots (for the [...] overflow popover)
    public var overflowCompanions: [CompanionProfile] {
        let railIds = Set(railSlots.map(\.id))
        return allCompanions.filter { !railIds.contains($0.id) }
    }
    
    public func selectCompanion(id: UUID, syncManager: Bool = true) {
        guard let target = allCompanions.first(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            self.activeCompanionId = target.id
            self.dismissedCompanionIds.remove(id)
            if let idx = allCompanions.firstIndex(where: { $0.id == id }) {
                allCompanions[idx].lastActiveAt = Date()
                allCompanions[idx].hasUnreadMessages = false
            }
        }
        syncWithCompanionManager()
        if syncManager {
            CompanionManager.shared.selectSession(id: target.id, syncRoster: false)
        }
    }

    public func presentCompanionOnRail(id: UUID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            self.presentedRailCompanionIds.insert(id)
            self.dismissedCompanionIds.remove(id)
        }
    }

    public func markAsRead(id: UUID) {
        if let idx = allCompanions.firstIndex(where: { $0.id == id }) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                allCompanions[idx].hasUnreadMessages = false
            }
        }
        if let sIdx = CompanionManager.shared.sessions.firstIndex(where: { $0.id == id }) {
            CompanionManager.shared.sessions[sIdx].isUnread = false
        }
        persist()
    }

    public func markAsRead(name: String) {
        if let idx = allCompanions.firstIndex(where: { $0.name.lowercased() == name.lowercased() || name.lowercased().contains($0.name.lowercased()) || $0.name.lowercased().contains(name.lowercased()) }) {
            markAsRead(id: allCompanions[idx].id)
        }
    }

    public func appendMessage(_ message: HomeSpaceChatMessage, forCompanionId id: UUID) {
        if let idx = allCompanions.firstIndex(where: { $0.id == id }) {
            allCompanions[idx].messages.append(message)
            allCompanions[idx].lastMessage = message.text
            allCompanions[idx].lastActiveAt = Date()
            let isChatOpen = CompanionUIHostRegistry.shared?.isHomeSpaceVisible ?? HomeSpaceWindowManager.shared.isVisible
            if !message.isUser && (!isChatOpen || allCompanions[idx].id != activeCompanionId) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    allCompanions[idx].hasUnreadMessages = true
                    self.presentedRailCompanionIds.insert(id)
                    self.dismissedCompanionIds.remove(id)
                }
                ClickySoundEngine.shared.play(.receive)
            }
            persist()
        }
    }

    public func updateMessage(id: UUID, computerPayload: ComputerCardPayload?, text: String? = nil, forCompanionId companionId: UUID? = nil) {
        let targetId = companionId ?? activeCompanionId
        guard let idx = allCompanions.firstIndex(where: { $0.id == targetId }) else { return }
        if let mIdx = allCompanions[idx].messages.firstIndex(where: { $0.id == id }) {
            if let payload = computerPayload {
                allCompanions[idx].messages[mIdx].computerPayload = payload
            }
            if let newText = text {
                allCompanions[idx].messages[mIdx].text = newText
            }
            if let last = allCompanions[idx].messages.last, last.id == id {
                if let newText = text, !newText.isEmpty {
                    allCompanions[idx].lastMessage = newText
                } else if let payload = computerPayload {
                    allCompanions[idx].lastMessage = payload.cardTitle
                }
            }
            allCompanions[idx].lastActiveAt = Date()
            persist()
        }
    }

    public func appendMessage(_ message: HomeSpaceChatMessage, forSessionName name: String) {
        if let idx = allCompanions.firstIndex(where: { $0.name.lowercased() == name.lowercased() || name.lowercased().contains($0.name.lowercased()) || $0.name.lowercased().contains(name.lowercased()) }) {
            allCompanions[idx].messages.append(message)
            allCompanions[idx].lastMessage = message.text
            allCompanions[idx].lastActiveAt = Date()
            let isChatOpen = CompanionUIHostRegistry.shared?.isHomeSpaceVisible ?? HomeSpaceWindowManager.shared.isVisible
            let targetId = allCompanions[idx].id
            if !message.isUser && (!isChatOpen || targetId != activeCompanionId) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    allCompanions[idx].hasUnreadMessages = true
                    self.presentedRailCompanionIds.insert(targetId)
                    self.dismissedCompanionIds.remove(targetId)
                }
                ClickySoundEngine.shared.play(.receive)
            }
            persist()
        }
    }

    /// Pin / Unpin companion to rail (PRD §A4, MT-25)
    public func togglePin(id: UUID) {
        guard let idx = allCompanions.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            allCompanions[idx].isPinnedToRail.toggle()
            let pinned = allCompanions[idx].isPinnedToRail
            if pinned {
                presentedRailCompanionIds.insert(id)
                dismissedCompanionIds.remove(id)
            }
        }
        persist()
        syncWithCompanionManager()
        ClickyLogger.info("[ROSTER]", "Toggled pin for '\(allCompanions[idx].name)' -> \(allCompanions[idx].isPinnedToRail)")
    }

    /// Hide companion from rail/sidebar without deleting data (PRD §A4, MT-25)
    public func hideCompanion(id: UUID) {
        guard let idx = allCompanions.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            allCompanions[idx].isPinnedToRail = false
            dismissedCompanionIds.insert(id)
            presentedRailCompanionIds.remove(id)
        }
        persist()
        syncWithCompanionManager()
        ClickyLogger.info("[ROSTER]", "Hid companion '\(allCompanions[idx].name)' from rail.")
    }

    /// Duplicates a companion: copies profile, skills, and routines; DISCARDS history (PRD §A4, MT-25)
    @discardableResult
    public func duplicateCompanion(id: UUID) -> CompanionProfile? {
        guard let original = allCompanions.first(where: { $0.id == id }) else { return nil }
        let copySuffix = UUID().uuidString.prefix(4)
        let copyName = "\(original.name) (Copy)"
        let copySlug = "\(original.slug)-copy-\(copySuffix)"

        // Profile copy: fresh messages, clean memory (history TIDAK ikut)
        var copy = CompanionProfile(
            id: UUID(),
            slug: copySlug,
            name: copyName,
            role: original.role,
            summary: original.summary,
            cloudColorHex: original.cloudColorHex,
            ringColorHex: original.ringColorHex,
            status: .idle,
            lastMessage: "",
            activeSkills: original.activeSkills,
            mdPath: "\(copySlug).md",
            isPinnedToRail: true,
            messages: [],
            mood: original.mood,
            templateId: original.templateId,
            animationKey: original.animationKey,
            currentExpressionKey: original.currentExpressionKey,
            executionDomain: original.executionDomain,
            workflowAppNames: original.workflowAppNames,
            allowedSafariDomains: original.allowedSafariDomains,
            safariTabAccessMode: original.safariTabAccessMode
        )

        allCompanions.insert(copy, at: 0)
        CompanionWorkspaceManager.shared.ensureWorkspaceHierarchy(for: copySlug)
        CompanionWorkspaceManager.shared.saveProfileJSON(for: copy)
        persist()
        syncWithCompanionManager()
        selectCompanion(id: copy.id)

        ClickyLogger.info("[ROSTER]", "Duplicated companion '\(original.name)' -> '\(copyName)' (history excluded per PRD §A4).")
        return copy
    }

    public func deleteCompanion(id: UUID) {
        guard allCompanions.count > 1 else { return }
        let warningNotice = "Berkas pada direktori workspace komputer bot ini mungkin masih tersisa di disk."
        ClickyLogger.warning("[ROSTER]", "Peringatan Hapus: \(warningNotice)")
        if let target = allCompanions.first(where: { $0.id == id }) {
            CompanionWorkspaceManager.shared.deleteCompanionWorkspace(slug: target.slug)
        }
        allCompanions.removeAll(where: { $0.id == id })
        if activeCompanionId == id, let next = allCompanions.first {
            selectCompanion(id: next.id)
        } else {
            persist()
            CompanionManager.shared.syncSessionsFromRoster(allCompanions, activeId: activeCompanionId)
        }
        ClickyLogger.info("[ROSTER]", "Deleted companion: \(id). \(warningNotice)")
    }
    public func clearMessages(for id: UUID) {
        if let idx = allCompanions.firstIndex(where: { $0.id == id }) {
            allCompanions[idx].messages = []
            allCompanions[idx].lastMessage = ""
            persist()
            CompanionManager.shared.syncSessionsFromRoster(allCompanions, activeId: activeCompanionId)
            ClickyLogger.info("[ROSTER]", "Cleared messages for companion: \(id)")
        }
    }
    
    public func swapIntoActiveSlot(id: UUID) {
        selectCompanion(id: id)
    }
    
    public func addOrUpdateCompanion(_ profile: CompanionProfile) {
        if let idx = allCompanions.firstIndex(where: { $0.id == profile.id || $0.slug == profile.slug }) {
            allCompanions[idx] = profile
        } else {
            allCompanions.insert(profile, at: 0)
        }
        CompanionWorkspaceManager.shared.ensureWorkspaceHierarchy(for: profile.slug)
        CompanionWorkspaceManager.shared.saveProfileJSON(for: profile)
        selectCompanion(id: profile.id)
    }

    public func updateCompanion(
        id: UUID,
        name: String,
        role: String,
        cloudColorHex: String,
        ringColorHex: String,
        mood: AgentCloudFaceMood? = nil,
        summary: String? = nil,
        templateId: String? = nil,
        animationKey: String? = nil,
        currentExpressionKey: String? = nil,
        workflowAppNames: [String]? = nil,
        allowedSafariDomains: [String]? = nil,
        safariTabAccessMode: String? = nil
    ) {
        guard let idx = allCompanions.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            allCompanions[idx].name = name
            allCompanions[idx].role = role
            allCompanions[idx].cloudColorHex = cloudColorHex
            allCompanions[idx].ringColorHex = ringColorHex
            if let mood = mood {
                allCompanions[idx].mood = mood
            }
            if let summary = summary {
                allCompanions[idx].summary = summary
            }
            if let templateId = templateId {
                allCompanions[idx].templateId = templateId
            }
            if let animationKey = animationKey {
                allCompanions[idx].animationKey = animationKey
            }
            if let currentExpressionKey = currentExpressionKey {
                allCompanions[idx].currentExpressionKey = currentExpressionKey
            }
            if let apps = workflowAppNames {
                allCompanions[idx].workflowAppNames = apps
            }
            if let domains = allowedSafariDomains {
                allCompanions[idx].allowedSafariDomains = domains
            }
            if let mode = safariTabAccessMode {
                allCompanions[idx].safariTabAccessMode = mode
            }
        }
        persist()
        syncWithCompanionManager()
        CompanionWorkspaceManager.shared.ensureWorkspaceHierarchy(for: allCompanions[idx].slug)
        CompanionWorkspaceManager.shared.saveProfileJSON(for: allCompanions[idx])

        CompanionManager.shared.updateSessionColorsAndDetails(
            companionId: id,
            name: name,
            role: role,
            cloudColorHex: cloudColorHex,
            ringColorHex: ringColorHex,
            mood: mood,
            templateId: templateId,
            animationKey: animationKey,
            currentExpressionKey: currentExpressionKey,
            workflowAppNames: workflowAppNames,
            allowedSafariDomains: allowedSafariDomains,
            safariTabAccessMode: safariTabAccessMode
        )
    }

    public func updateCompanionStatus(id: UUID, status: CompanionStatus) {
        guard let idx = allCompanions.firstIndex(where: { $0.id == id }) else { return }
        let oldStatus = allCompanions[idx].status
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            allCompanions[idx].status = status
            if status == .done && oldStatus == .working {
                ClickySoundEngine.shared.play(.done)
            }
        }
        persist()
    }
    
    public func dismissCompanion(id: UUID) {
        guard let idx = allCompanions.firstIndex(where: { $0.id == id }) else { return }
        let companionName = allCompanions[idx].name
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            allCompanions[idx].hasUnreadMessages = false
            allCompanions[idx].status = .idle
            self.presentedRailCompanionIds.remove(id)
            self.dismissedCompanionIds.insert(id)
            if activePopoverCompanionId == id {
                activePopoverCompanionId = nil
            }
        }
        if let sIdx = CompanionManager.shared.sessions.firstIndex(where: {
            $0.name.lowercased() == companionName.lowercased() ||
            companionName.lowercased().contains($0.name.lowercased())
        }) {
            CompanionManager.shared.sessions[sIdx].isUnread = false
        }
        if CompanionManager.shared.activeBuddy.name.lowercased() == companionName.lowercased() || CompanionManager.shared.activeBuddy.id == id {
            CompanionManager.shared.stopCurrentTask()
            CompanionManager.shared.isTaskSessionPreApproved = false
        }
        persist()
    }

    public func restoreDefaultCompanions() {
        // Disabled by user directive: do not inject unwanted starter companions
    }
    
    public func toggleRailCollapse() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            isRailCollapsed.toggle()
        }
    }
    
    public func syncWithCompanionManager() {
        CompanionManager.shared.setActiveCompanion(activeCompanion)
        CompanionManager.shared.syncSessionsFromRoster(allCompanions, activeId: activeCompanionId)
    }
    
    private func persist() {
        if let encoded = try? JSONEncoder().encode(allCompanions) {
            UserDefaults.standard.set(encoded, forKey: rosterKey)
        }
    }
}
// MARK: - CompanionHandoffService (PRD §A7, MT-15: Bot-to-Bot Async Handoff)

public struct CompanionHandoffMessage: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let fromSlug: String
    public let toSlug: String
    public let stage: String
    public let contextSummary: String
    public let sharedArtifactPaths: [String]
    public let taskInstruction: String
    public let timestamp: Date
    public var status: String

    public init(
        id: UUID = UUID(),
        fromSlug: String,
        toSlug: String,
        stage: String,
        contextSummary: String,
        sharedArtifactPaths: [String] = [],
        taskInstruction: String,
        timestamp: Date = Date(),
        status: String = "accepted"
    ) {
        self.id = id
        self.fromSlug = fromSlug
        self.toSlug = toSlug
        self.stage = stage
        self.contextSummary = contextSummary
        self.sharedArtifactPaths = sharedArtifactPaths
        self.taskInstruction = taskInstruction
        self.timestamp = timestamp
        self.status = status
    }
}

@MainActor
public final class CompanionHandoffService: ObservableObject {
    public static let shared = CompanionHandoffService()

    @Published public private(set) var activeHandoffs: [CompanionHandoffMessage] = []

    private init() {}

    /// Dispatches an asynchronous handoff from one companion to another
    /// Enforces the Single Owner per Stage rule (PRD §A7).
    @discardableResult
    public func dispatchHandoff(
        from fromSlug: String,
        to toSlug: String,
        stage: String,
        contextSummary: String,
        sharedArtifactPaths: [String] = [],
        taskInstruction: String
    ) -> CompanionHandoffMessage {
        let handoff = CompanionHandoffMessage(
            fromSlug: fromSlug,
            toSlug: toSlug,
            stage: stage,
            contextSummary: contextSummary,
            sharedArtifactPaths: sharedArtifactPaths,
            taskInstruction: taskInstruction
        )

        activeHandoffs.append(handoff)

        // 1. Record dispatch message in sender companion chat
        let fromCompanion = CompanionRosterStore.shared.allCompanions.first(where: { $0.slug == fromSlug })
        let toCompanion = CompanionRosterStore.shared.allCompanions.first(where: { $0.slug == toSlug })
        let toName = toCompanion?.name ?? toSlug
        let fromName = fromCompanion?.name ?? fromSlug

        let dispatchText = "Handoff ke \(toName): \(taskInstruction) [Tahap: \(stage)]"
        let senderMsg = HomeSpaceChatMessage(isUser: false, text: dispatchText)
        if let fComp = fromCompanion {
            CompanionRosterStore.shared.appendMessage(senderMsg, forCompanionId: fComp.id)
        }

        // 2. Transfer ownership to recipient companion (Single Owner per Stage rule)
        let receiptText = "Menerima handoff dari \(fromName): \(taskInstruction)\nKonteks: \(contextSummary)"
        let recipientMsg = HomeSpaceChatMessage(isUser: false, text: receiptText)
        if let tComp = toCompanion {
            CompanionRosterStore.shared.appendMessage(recipientMsg, forCompanionId: tComp.id)
            // Record handoff in recipient's memory
            CompanionMemoryManager.shared.recordWorkSummary(
                slug: toSlug,
                runId: handoff.id.uuidString,
                prompt: taskInstruction,
                outcome: "Menerima handoff tahap '\(stage)' dari \(fromSlug)",
                sources: sharedArtifactPaths
            )
        }

        ClickyLogger.info("[HANDOFF]", "Dispatched bot-to-bot handoff from '\(fromSlug)' to '\(toSlug)': stage='\(stage)'")
        return handoff
    }
}
