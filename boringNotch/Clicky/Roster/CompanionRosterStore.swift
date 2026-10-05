//
//  CompanionRosterStore.swift
//  boringNotch
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
        var filteredCompanions = loadedCompanions.filter {
            $0.slug != "research-buddy" && $0.slug != "shippy" && $0.slug != "clicky"
        }
        if !filteredCompanions.contains(where: { $0.slug == "futures-scout" || $0.name.lowercased().contains("futures scout") }) {
            filteredCompanions.insert(scoutProfile, at: 0)
        }

        // Clean up any residual initial greetings from companions so they open in clean welcome state
        filteredCompanions = filteredCompanions.map { comp in
            var c = comp
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
            let isChatOpen = HomeSpaceWindowManager.shared.isVisible
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
            let isChatOpen = HomeSpaceWindowManager.shared.isVisible
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

    public func deleteCompanion(id: UUID) {
        guard allCompanions.count > 1 else { return }
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
        ClickyLogger.info("[ROSTER]", "Deleted companion: \(id)")
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
