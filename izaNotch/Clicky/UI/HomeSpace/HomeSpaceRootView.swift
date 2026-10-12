//
//  HomeSpaceRootView.swift
//  izaNotch (Izanotchy)
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
    @State var stagedAttachments: [ChatAttachment] = []
    @State var attachmentErrorMessage: String? = nil
    @State var isSearchPaletteOpen: Bool = false
    // Character Editing State
    @State var isEditingCharacter: Bool = false
    @State var editName: String = ""
    @State var editRole: String = ""
    @State var editDescription: String = ""
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

            if isSearchPaletteOpen {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isSearchPaletteOpen = false
                        }
                    }
                    .zIndex(190)

                HomeSpaceSearchPaletteView(
                    isOpen: $isSearchPaletteOpen,
                    onSelectCompanion: { id in
                        companion.selectSession(id: id)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isSearchPaletteOpen = false
                        }
                    }
                )
                .padding(.top, notchHeight + 35)
                .zIndex(200)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if let computerPayload = activeComputerModalPayload {
                HomeSpaceInteractiveComputerModalView(
                    payload: computerPayload,
                    onDismiss: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            activeComputerModalPayload = nil
                        }
                    }
                )
                .offset(y: notchHeight)
                .zIndex(250)
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
                    status: companion.isProcessingTask ? .working : .done,
                    instructionText: "Chromium Workspace untuk \(companion.activeBuddy.name)",
                    snapshotImagePath: CompanionVMViewportController.shared.activeSnapshotPath,
                    targetAppName: "Chromium Workspace",
                    activeWorkflowApp: "Chromium Workspace",
                    queueSummary: "Agent Computer"
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceReviseArtifact"))) { notif in
            if let artifactPath = notif.object as? String {
                let name = URL(fileURLWithPath: artifactPath).lastPathComponent
                inputText = "Revisi artifact \(name): "
                isTypingMode = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("HomeSpaceToggleSearchPalette"))) { _ in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isSearchPaletteOpen.toggle()
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
        "Message \(companion.activeBuddy.name)"
    }

    var dynamicWelcomeSubtitle: String {
        companion.activeBuddy.roleDescription.isEmpty ? "AI Teammate ready to complete work across your tools and apps." : companion.activeBuddy.roleDescription
    }

    func submitPrompt(_ prompt: String) {
        let currentAttachments = stagedAttachments
        stagedAttachments = []
        inputText = ""
        isTypingMode = false
        companion.submitPrompt(prompt, attachments: currentAttachments)
    }

    func openAttachmentPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.title = "Pilih Berkas Lampiran"
        panel.message = "Pilih hingga 6 berkas (maks 25MB, video 200MB)"
        if panel.runModal() == .OK {
            for url in panel.urls {
                let res = AttachmentValidator.validate(url: url, currentCount: stagedAttachments.count)
                if let att = res.attachment {
                    stagedAttachments.append(att)
                } else if let err = res.error {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        attachmentErrorMessage = err
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        if attachmentErrorMessage == err {
                            attachmentErrorMessage = nil
                        }
                    }
                    break
                }
            }
        }
    }

    func removeStagedAttachment(id: UUID) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            stagedAttachments.removeAll(where: { $0.id == id })
        }
    }
}
