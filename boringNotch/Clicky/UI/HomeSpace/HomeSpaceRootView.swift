//
//  HomeSpaceRootView.swift
//  boringNotch (Izanotchy)
//
//  1:1 Implementation of HeyClicky v1.0.50 Studio (Foto 4):
//  - Section 1 (Sidebar ~235pt):
//      * Sub 1A: Top control (collapse icon) + Search with '+' button
//      * Sub 1B: Scrollable Buddy Sessions list (Research Buddy, Shippy, Clicky)
//      * Sub 1C: Bottom account dock (Apps + pill, user profile with real Google AI Pro quota ring & settings gear)
//  - Section 2 (Main Chat Workspace ~665pt):
//      * Sub 2A: Clean header bar (center assistant switcher pill, top right: expand ⤢ & close ✕; no redundant buttons)
//      * Sub 2B: Chat stream & artifact canvas (user bubble in blue, progress drawer, assistant response, artifact cards, Computer Use consent card)
//      * Sub 2C: Bottom floating dock (peeking cloud mascot ^ ^, Liquid-Gel voice pill, "Release to send", Type... pill)
//

import SwiftUI
import Defaults
import AppKit

// (NotchUnifiedHuggingShape extracted to Components/NotchUnifiedHuggingShape.swift)

struct HomeSpaceRootView: View {
    @ObservedObject var companion = CompanionManager.shared
    @ObservedObject var usageManager = AntigravityUsageManager.shared
    @ObservedObject var suggestionMonitor = IntegrationSuggestionMonitor.shared
    @ObservedObject var toolDispatcher = ClickyToolDispatcher.shared
    @Default(.selectedAIAssistant) var selectedAIAssistant: String

    @State var searchText: String = ""
    @State var inputText: String = ""
    @State var isTypingMode: Bool = false
    @State var isSidebarCollapsed: Bool = false
    @State var copiedMessageID: UUID?
    @State var isProgressExpanded: Bool = false
    @State var isCharacterSidebarOpen: Bool = false
    @State var isCreatingNewBuddy: Bool = false
    @State var activeComputerModalPayload: ComputerCardPayload? = nil
    @State var newBuddyPromptText: String = ""
    @ObservedObject var interviewEngine = CompanionInterviewEngine.shared

    // Character Editing State
    @State var isEditingCharacter: Bool = false
    @State var editName: String = ""
    @State var editRole: String = ""
    @State var editCloudColorHex: String = ""
    @State var editRingColorHex: String = ""
    @State var editMood: AgentCloudFaceMood = .happy
    @State var editAvatarLabExpression: String = "neutral"
    @State var editSelectedTemplateId: String = "strobi"
    @State var editStudioTab: StudioTab = .shapeAndColor
    @State var visibleMessageLimit: Int = 20
    @State var editWorkflowApps: [String] = ["Mail", "Safari"]
    @State var editSafariDomains: String = "google.com, github.com"
    @State var editSafariTabMode: String = "whitelist_only"
    enum HomeSpaceViewMode: String, CaseIterable, Identifiable, Hashable {
        case chats = "Chats"
        case editCharacter = "Character"
        case connectedApps = "Apps"
        var id: String { rawValue }
    }

    @State var activeViewMode: HomeSpaceViewMode = .chats
    @State var searchAppQuery: String = ""
    var isCharacterSettingsActive: Bool {
        isEditingCharacter || activeViewMode == .editCharacter || activeViewMode == .connectedApps
    }
    @ObservedObject var animationEngine = CompanionAnimationEngine.shared
    @ObservedObject var appsDiscovery = InstalledAppsDiscoveryService.shared

    enum StudioTab: String, CaseIterable, Identifiable {
        case shapeAndColor = "Shape & Color"
        case presets = "Presets (27)"
        case animations = "Animations (23)"
        var id: String { rawValue }
    }

    var currentEditDefinition: CompanionAvatarDefinition {
        let t = CompanionAvatarLabCatalog.allTemplates.first { $0.id == editSelectedTemplateId }
            ?? CompanionAvatarLabCatalog.allTemplates[0]
        return t.toAvatarDefinition(
            name: editName.isEmpty ? t.name : editName,
            cloudColorHex: editCloudColorHex.isEmpty ? t.defaultColors.bodyHex : editCloudColorHex,
            eyesHex: "#111316"
        )
    }

    var onClose: () -> Void

    // Dynamic Notch Metrics
    var notchHeight: CGFloat {
        if #available(macOS 12.0, *),
           let screen = NSScreen.main ?? NSScreen.screens.first,
           screen.safeAreaInsets.top > 0 {
            return screen.safeAreaInsets.top
        }
        return 32.0
    }

    var notchWidth: CGFloat {
        if #available(macOS 12.0, *),
           let screen = NSScreen.main ?? NSScreen.screens.first,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX {
            return right.minX - left.maxX
        }
        return 185.0
    }

    var notchLeft: CGFloat {
        450.0 - (notchWidth / 2.0)
    }

    var notchRight: CGFloat {
        450.0 + (notchWidth / 2.0)
    }

    var body: some View {
        let totalHeight: CGFloat = 580 + notchHeight
        let unifiedShape = NotchUnifiedHuggingShape(
            notchLeft: notchLeft,
            notchRight: notchRight,
            notchHeight: notchHeight,
            earRadius: 18,
            cornerRadius: 20
        )

        ZStack(alignment: .top) {
            Color.clear.frame(width: 900, height: totalHeight)

            // Top Notch Tab Tap Target: Clicking the physical notch area immediately closes HomeSpace
            Color.clear
                .frame(width: notchWidth + 40, height: max(32, notchHeight))
                .contentShape(Rectangle())
                .onTapGesture {
                    ClickySoundEngine.shared.play(.close)
                    onClose()
                }
                .zIndex(100)

            // Main Content Window (580pt height, sits at y: notchHeight flush below notch)
            HStack(spacing: 0) {
                // MARK: - Section 1: Sidebar (Session Manager / Multi-Buddy)
                if !isSidebarCollapsed && !isCreatingNewBuddy {
                    sidebarView
                        .frame(width: 235)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    // Vertical Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                }

                // MARK: - Section 2: Active Chat Workspace
                chatWorkspaceView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 900, height: 580)
            .offset(y: notchHeight)

            // MARK: - Section 4: Semi-Fullscreen Computer Modal (F-08: 1:1 Foto Baru)
            if let modalPayload = activeComputerModalPayload {
                HomeSpaceInteractiveComputerModalView(payload: modalPayload, onDismiss: {
                    ClickySoundEngine.shared.play(.close)
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        activeComputerModalPayload = nil
                    }
                })
                .frame(width: 900, height: 580)
                .offset(y: notchHeight)
                .zIndex(500)
            }
        }
        .frame(width: 900, height: totalHeight)
        .background(
            ZStack {
                // Solid dark slate base
                Color(hex: "#141517")

                // Smooth black gradient at top merging directly into the notch
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black.opacity(0.85), location: 0.08),
                        .init(color: .black.opacity(0.35), location: 0.20),
                        .init(color: Color.clear, location: 0.38)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(unifiedShape)
        .overlay(
            unifiedShape
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isSidebarCollapsed || isCreatingNewBuddy)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceToggleCharacterSidebar"))) { _ in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                if isEditingCharacter {
                    isEditingCharacter = false
                } else {
                    isCharacterSidebarOpen.toggle()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceToggleSidebar"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSidebarCollapsed.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceOpenNewBuddy"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                interviewEngine.reset()
                isCreatingNewBuddy = true
                isEditingCharacter = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceCloseNewBuddy"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isCreatingNewBuddy = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceEditCompanion"))) { notif in
            if let targetId = notif.object as? UUID {
                companion.selectSession(id: targetId)
            }
            startEditing(session: companion.activeBuddy)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceOpenConnectedApps"))) { _ in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                activeViewMode = .connectedApps
                isEditingCharacter = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceOpenComputerModal"))) { notif in
            let payload = (notif.userInfo?["payload"] as? ComputerCardPayload)
                ?? companion.chatMessages.reversed().first(where: { $0.computerPayload != nil })?.computerPayload
                ?? ComputerCardPayload(
                    cardTitle: "Computer",
                    status: .done,
                    instructionText: "Tolong kirimkan email ke rezkyhaikal2@gmail.com",
                    snapshotImagePath: CompanionWindowStreamService.shared.activeSnapshotPath,
                    targetAppName: "Mail",
                    activeWorkflowApp: "Mail",
                    queueSummary: "Delivered to rezkyhaikal2@gmail.com"
                )
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                activeComputerModalPayload = payload
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceCloseComputerModal"))) { _ in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                activeComputerModalPayload = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceSubmitPrompt"))) { notif in
            if let prompt = notif.object as? String {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    isEditingCharacter = false
                    isCharacterSidebarOpen = false
                }
                submitPrompt(prompt)
            }
        }
    }


    // MARK: - Computed Properties & Helpers

    var filteredSessions: [BuddySession] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return companion.sessions
        }
        return companion.sessions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.roleDescription.localizedCaseInsensitiveContains(searchText) ||
            $0.lastSnippet.localizedCaseInsensitiveContains(searchText)
        }
    }

    var displayEmail: String {
        let email = usageManager.activeAccount.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty {
            return email
        }
        let userName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return userName.isEmpty ? NSUserName() : userName
    }

    var displayPlan: String {
        let plan = usageManager.activeAccount.plan.trimmingCharacters(in: .whitespacesAndNewlines)
        return plan.isEmpty ? "Google AI Pro" : plan
    }

    var dynamicWelcomeTitle: String {
        let nameLower = companion.activeBuddy.name.lowercased()
        let roleLower = companion.activeBuddy.roleDescription.lowercased()

        if nameLower.contains("futures") || roleLower.contains("analyst") || roleLower.contains("trade") || roleLower.contains("macro") {
            return "What would you like to analyze?"
        } else if nameLower.contains("research") || roleLower.contains("research") {
            return "What would you like to research?"
        } else if nameLower.contains("shippy") || roleLower.contains("builder") || roleLower.contains("dev") || roleLower.contains("code") {
            return "What would you like to build?"
        } else if roleLower.contains("design") || roleLower.contains("creative") || roleLower.contains("art") {
            return "What would you like to create?"
        } else if roleLower.contains("write") || roleLower.contains("writer") || roleLower.contains("copy") {
            return "What would you like to write?"
        } else if nameLower.contains("inbox") || roleLower.contains("email") || roleLower.contains("mail") || roleLower.contains("inbox") {
            return "What would you like to handle?"
        } else if nameLower.contains("clicky") {
            return "What would you like to explore?"
        } else {
            return "How can \(companion.activeBuddy.name) help?"
        }
    }

    var dynamicWelcomeSubtitle: String {
        let nameLower = companion.activeBuddy.name.lowercased()
        let roleLower = companion.activeBuddy.roleDescription.lowercased()

        if nameLower.contains("futures") || roleLower.contains("analyst") || roleLower.contains("trade") {
            return "Ask anything about crypto futures, technical analysis, or market trends."
        } else if nameLower.contains("research") || roleLower.contains("research") {
            return "Ask anything about competitor intel, market insights, or document summaries."
        } else if nameLower.contains("shippy") || roleLower.contains("builder") || roleLower.contains("dev") || roleLower.contains("code") {
            return "Ask anything about code, web applications, debugging, or Mac automation."
        } else if nameLower.contains("inbox") || roleLower.contains("email") || roleLower.contains("mail") || roleLower.contains("inbox") {
            return "Ask anything about sorting your inbox, drafting replies, or email summaries."
        } else if nameLower.contains("clicky") {
            return "Ask anything about your screen, spatial navigation, or desktop tasks."
        } else if !companion.activeBuddy.roleDescription.isEmpty {
            return "Specialized in \(companion.activeBuddy.roleDescription). Ready to assist with your active tasks."
        } else {
            return "Ask anything or assign a task to get started."
        }
    }

    func submitPrompt(_ prompt: String) {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // F-07 Quick Verification Trigger (1:1 Foto 1)
        if clean.lowercased() == "/computer" || clean.lowercased() == "computer" || clean.lowercased() == "test computer" {
            ClickySoundEngine.shared.play(.send)
            inputText = ""
            isTypingMode = false

            let userMsg = HomeSpaceChatMessage(isUser: true, text: clean)
            companion.appendChatMessage(userMsg)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let payload = ComputerCardPayload(
                    cardTitle: "Computer",
                    status: .done,
                    instructionText: "Sign in to Salesforce so I can see the accounts you own.",
                    snapshotImagePath: nil,
                    targetAppName: "Salesforce",
                    queueSummary: "36 drafts queued"
                )
                let assistantMsg = HomeSpaceChatMessage(
                    isUser: false,
                    text: "",
                    computerPayload: payload
                )
                companion.appendChatMessage(assistantMsg)
                ClickySoundEngine.shared.play(.done)
            }
            return
        }

        // Autonomous Task Decomposition Stage (AFM On-Device Reasoner)
        // Replaces all rigid hardcoded app keyword matching (isEmailAction, isSafariAction)
        ClickySoundEngine.shared.play(.send)
        let userMsg = HomeSpaceChatMessage(isUser: true, text: clean)
        companion.appendChatMessage(userMsg)
        inputText = ""
        isTypingMode = false

        Task { @MainActor in
            let plan = await AFMLunaCoordinationBridge.shared.deconstructTaskGoalWithAFM(
                userPrompt: clean,
                companionSlug: companion.activeBuddy.slug,
                connectedApps: companion.activeBuddy.workflowAppNames
            )

            if plan.requiresCUA && !plan.isConversational {
                let targetApp = (plan.targetAppName.isEmpty || plan.targetAppName.lowercased() == "none") ? (companion.activeBuddy.workflowAppNames.first ?? "Workspace") : plan.targetAppName
                
                let initialQueue = plan.plannedSubGoals.map {
                    ComputerCardQueueItem(name: $0, statusBadge: "Planned", isChecked: false)
                }

                var workingPayload = ComputerCardPayload(
                    cardTitle: "Computer",
                    status: .working,
                    instructionText: clean,
                    snapshotImagePath: CompanionWindowStreamService.shared.activeSnapshotPath,
                    targetAppName: targetApp,
                    activeWorkflowApp: targetApp,
                    queueSummary: "\(plan.plannedSubGoals.count) steps planned by AFM",
                    queueItems: initialQueue.isEmpty ? [
                        ComputerCardQueueItem(name: "Inspect \(targetApp) UI", statusBadge: "Starting", isChecked: false),
                        ComputerCardQueueItem(name: "Execute sub-goals", statusBadge: "Pending", isChecked: false)
                    ] : initialQueue
                )

                let assistantMsg = HomeSpaceChatMessage(
                    isUser: false,
                    text: "",
                    computerPayload: workingPayload
                )
                companion.appendChatMessage(assistantMsg)
                let assistantMsgId = assistantMsg.id
                HomeSpaceWindowManager.shared.ensureOrderFront()

                // In-Chat First: Keep action directly inside chat feed (Zero Auto-Maximize)
                do {
                    HomeSpaceWindowManager.shared.ensureOrderFront()
                    let finalPayload = try await CompanionVMAgentLoop.shared.executeAutonomousTask(
                        prompt: clean,
                        slug: companion.activeBuddy.slug,
                        appName: targetApp,
                        taskPlan: plan,
                        onProgress: { progressPayload in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                var updated = progressPayload
                                updated.updatedAt = Date()
                                companion.updateChatMessage(id: assistantMsgId, computerPayload: updated)
                            }
                            if self.activeComputerModalPayload != nil {
                                self.activeComputerModalPayload = progressPayload
                            }
                            HomeSpaceWindowManager.shared.ensureOrderFront()
                        }
                    )
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        var updated = finalPayload
                        updated.updatedAt = Date()
                        let resolvedText: String
                        if let r = finalPayload.responseToUser?.trimmingCharacters(in: .whitespacesAndNewlines), !r.isEmpty {
                            resolvedText = r
                        } else if let s = finalPayload.deliverableSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                            resolvedText = s
                        } else if !finalPayload.instructionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            resolvedText = finalPayload.instructionText
                        } else {
                            resolvedText = "Pemeriksaan pada \(targetApp) telah selesai dilakukan."
                        }
                        companion.updateChatMessage(
                            id: assistantMsgId,
                            computerPayload: updated,
                            text: resolvedText
                        )
                    }
                    if self.activeComputerModalPayload != nil {
                        self.activeComputerModalPayload = finalPayload
                    }
                    ClickySoundEngine.shared.play(.done)
                    HomeSpaceWindowManager.shared.ensureOrderFront()
                } catch {
                    let failedPayload = ComputerCardPayload(
                        cardTitle: "Computer",
                        status: .failed,
                        instructionText: "Task error: \(error.localizedDescription)",
                        snapshotImagePath: nil,
                        targetAppName: targetApp,
                        activeWorkflowApp: targetApp,
                        queueSummary: "Execution failed"
                    )
                    var updated = failedPayload
                    updated.updatedAt = Date()
                    companion.updateChatMessage(id: assistantMsgId, computerPayload: updated, text: "Task error: \(error.localizedDescription)")
                    if self.activeComputerModalPayload != nil {
                        self.activeComputerModalPayload = failedPayload
                    }
                    HomeSpaceWindowManager.shared.ensureOrderFront()
                }
            } else {
                companion.askViaText(prompt: clean)
                HomeSpaceWindowManager.shared.ensureOrderFront()
            }
        }
    }

}
