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
    @ObservedObject private var toolDispatcher = ClickyToolDispatcher.shared
    @Default(.selectedAIAssistant) var selectedAIAssistant: String

    @State private var searchText: String = ""
    @State private var inputText: String = ""
    @State private var isTypingMode: Bool = false
    @State private var isSidebarCollapsed: Bool = false
    @State private var copiedMessageID: UUID?
    @State private var isProgressExpanded: Bool = false
    @State private var isCharacterSidebarOpen: Bool = false
    @State private var isCreatingNewBuddy: Bool = false
    @State private var activeComputerModalPayload: ComputerCardPayload? = nil
    @State private var newBuddyPromptText: String = ""
    @ObservedObject private var interviewEngine = CompanionInterviewEngine.shared

    // Character Editing State
    @State private var isEditingCharacter: Bool = false
    @State private var editName: String = ""
    @State private var editRole: String = ""
    @State private var editCloudColorHex: String = ""
    @State private var editRingColorHex: String = ""
    @State private var editMood: AgentCloudFaceMood = .happy
    @State private var editAvatarLabExpression: String = "neutral"
    @State private var editSelectedTemplateId: String = "strobi"
    @State private var editStudioTab: StudioTab = .shapeAndColor
    @State private var visibleMessageLimit: Int = 20
    @State private var editWorkflowApps: [String] = ["Mail", "Safari"]
    @State private var editSafariDomains: String = "google.com, github.com"
    @State private var editSafariTabMode: String = "whitelist_only"
    enum HomeSpaceViewMode: String, CaseIterable, Identifiable, Hashable {
        case chats = "Chats"
        case editCharacter = "Character"
        case connectedApps = "Apps"
        var id: String { rawValue }
    }

    @State private var activeViewMode: HomeSpaceViewMode = .chats
    @State private var searchAppQuery: String = ""
    private var isCharacterSettingsActive: Bool {
        isEditingCharacter || activeViewMode == .editCharacter || activeViewMode == .connectedApps
    }
    @ObservedObject private var animationEngine = CompanionAnimationEngine.shared
    @ObservedObject private var appsDiscovery = InstalledAppsDiscoveryService.shared

    enum StudioTab: String, CaseIterable, Identifiable {
        case shapeAndColor = "Shape & Color"
        case presets = "Presets (27)"
        case animations = "Animations (23)"
        var id: String { rawValue }
    }

    private var currentEditDefinition: CompanionAvatarDefinition {
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
    private var notchHeight: CGFloat {
        if #available(macOS 12.0, *),
           let screen = NSScreen.main ?? NSScreen.screens.first,
           screen.safeAreaInsets.top > 0 {
            return screen.safeAreaInsets.top
        }
        return 32.0
    }

    private var notchWidth: CGFloat {
        if #available(macOS 12.0, *),
           let screen = NSScreen.main ?? NSScreen.screens.first,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX {
            return right.minX - left.maxX
        }
        return 185.0
    }

    private var notchLeft: CGFloat {
        450.0 - (notchWidth / 2.0)
    }

    private var notchRight: CGFloat {
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

    // MARK: - Section 1: Sidebar View
    private var sidebarView: some View {
        VStack(spacing: 0) {
            if isCharacterSettingsActive {
                settingsSidebarView
            } else {
                chatSidebarView
            }
        }
    }

    // MARK: - Section 1-Settings: Dedicated Character Settings Sidebar
    private var settingsSidebarView: some View {
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
    private var chatSidebarView: some View {
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

    // MARK: - Section 2: Active Chat Workspace View
    private var chatWorkspaceView: some View {
        ZStack(alignment: .trailing) {
            if isCreatingNewBuddy {
                newBuddyCreationView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if activeViewMode == .connectedApps {
                connectedAppsWorkspaceView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else if activeViewMode == .editCharacter || isEditingCharacter {
                editCharacterFullWorkspaceView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                VStack(spacing: 0) {
                    // Sub-Section 2A: Clean Header Bar (Clean, NO iza logo, NO capsule card)
                    HStack {
                        Spacer()

                        // Top-Right Action Buttons (Close Only — Expand Eliminated)
                        Button(action: {
                            ClickySoundEngine.shared.play(.close)
                            onClose()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .help("Close back to notch")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 6)

                    if companion.activeBuddy.messages.isEmpty && !companion.isResponding {
                        // Sub-Section 2B: Clean Modern Centered Welcome State (Zero badge, zero chips, vertically & horizontally centered)
                        VStack(spacing: 0) {
                            Spacer()

                            VStack(spacing: 10) {
                                Text(dynamicWelcomeTitle)
                                    .font(.system(size: 21, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)

                                Text(dynamicWelcomeSubtitle)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.white.opacity(0.55))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 36)

                                // Real suggestions based on passive active app inspector
                                if let suggestion = suggestionMonitor.activeSuggestion, !suggestion.prompt.isEmpty {
                                    FollowUpPillButton(text: suggestion.prompt) {
                                        submitPrompt(suggestion.prompt)
                                    }
                                    .padding(.top, 12)
                                }
                            }
                            .frame(maxWidth: .infinity)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Sub-Section 2B: Real Chat Stream & Functional Transcript
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 14) {
                                    let allMessages = companion.activeBuddy.messages
                                    let olderCount = max(0, allMessages.count - visibleMessageLimit)
                                    let displayedMessages = Array(allMessages.suffix(visibleMessageLimit))
                                    let latestComputerMessageId = displayedMessages.last(where: { $0.computerPayload != nil })?.id

                                    if olderCount > 0 {
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                visibleMessageLimit += 25
                                            }
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.up.circle.fill")
                                                    .font(.system(size: 11))
                                                Text("Load older messages (\(olderCount) more)")
                                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                            }
                                            .foregroundColor(Color(hex: "#38BDF8"))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(Color.white.opacity(0.06))
                                                    .overlay(
                                                        Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                                    )
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                    }

                                    // Real Messages Stream
                                    ForEach(displayedMessages) { message in
                                        if message.isUser {
                                            HStack {
                                                Spacer()
                                                Text(message.text)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(Color(hex: "#0C1D38"))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [Color(hex: "#C7E5FE"), Color(hex: "#93C5FD")],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                )
                                                .frame(maxWidth: 420, alignment: .trailing)
                                            }
                                            .id(message.id)
                                        } else {
                                            VStack(alignment: .leading, spacing: 10) {
                                                if let payload = message.computerPayload {
                                                    if message.id == latestComputerMessageId {
                                                        // SINGLE ACTIVE COMPUTER CARD: Placed inline directly with this turn!
                                                        HomeSpaceComputerCardView(
                                                            payload: payload,
                                                            onTakeoverClicked: {
                                                                ClickySoundEngine.shared.play(.open)
                                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                                    activeComputerModalPayload = payload
                                                                }
                                                            },
                                                            onOpenWindowClicked: {
                                                                if let app = payload.targetAppName ?? payload.activeWorkflowApp {
                                                                    CompanionWindowStreamService.shared.launchOrFocusWorkflowApp(appName: app)
                                                                }
                                                            },
                                                            onCardTapped: {
                                                                ClickySoundEngine.shared.play(.open)
                                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                                    activeComputerModalPayload = payload
                                                                }
                                                            },
                                                            isCollapsible: true,
                                                            isCollapsed: $companion.isWorkspaceCollapsed
                                                        )
                                                        .id("active-workspace-\(message.id)")
                                                    } else {
                                                        // PAST TURN: "meninggalkan stepnya yg sudah selesai tadi"
                                                        let pastItems = (payload.queueItems?.isEmpty == false ? payload.queueItems : nil)
                                                            ?? [ComputerCardQueueItem(name: payload.deliverableSummary ?? payload.queueSummary ?? payload.instructionText, statusBadge: "Done", isChecked: true)]

                                                        HomeSpaceComputerStepsView(
                                                            queueItems: pastItems,
                                                            status: payload.status,
                                                            isPastTurn: true,
                                                            targetAppName: payload.targetAppName ?? payload.activeWorkflowApp,
                                                            summary: payload.deliverableSummary ?? payload.queueSummary ?? payload.instructionText,
                                                            onTapped: {
                                                                ClickySoundEngine.shared.play(.open)
                                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                                    activeComputerModalPayload = payload
                                                                }
                                                            }
                                                        )
                                                        .id("past-steps-\(message.id)")
                                                    }
                                                }

                                                if !message.text.isEmpty {
                                                    MarkdownFormattedMessageView(text: message.text)
                                                }

                                                HStack(spacing: 8) {
                                                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                                                        .font(.system(size: 10, weight: .regular))
                                                        .foregroundColor(.white.opacity(0.4))

                                                    Button(action: {
                                                        NSPasteboard.general.clearContents()
                                                        NSPasteboard.general.setString(message.text, forType: .string)
                                                        copiedMessageID = message.id
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                            if copiedMessageID == message.id { copiedMessageID = nil }
                                                        }
                                                    }) {
                                                        Image(systemName: copiedMessageID == message.id ? "checkmark" : "doc.on.doc")
                                                            .font(.system(size: 9.5))
                                                            .foregroundColor(.white.opacity(0.4))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.vertical, 4)
                                            .id(message.id)
                                        }
                                    }

                                    // Live Streaming Response Chunk (Clean State Separation)
                                    if companion.isHomeSpaceStreaming && !companion.homeSpaceStreamingText.isEmpty && companion.pendingComputerUseRequest == nil {
                                        VStack(alignment: .leading, spacing: 6) {
                                            MarkdownFormattedMessageView(text: companion.homeSpaceStreamingText)

                                            HStack(spacing: 6) {
                                                if let activeTool = toolDispatcher.currentExecutingToolName {
                                                    ProgressView()
                                                        .scaleEffect(0.55)
                                                        .frame(width: 12, height: 12)
                                                    Text("⚙️ Tool: \(activeTool)")
                                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(Color(hex: "#38BDF8"))
                                                } else {
                                                    HStack(spacing: 4) {
                                                        Circle().fill(Color(hex: "#60A5FA")).frame(width: 4, height: 4)
                                                        Circle().fill(Color(hex: "#60A5FA").opacity(0.6)).frame(width: 4, height: 4)
                                                        Circle().fill(Color(hex: "#60A5FA").opacity(0.3)).frame(width: 4, height: 4)
                                                        Text("\(companion.activeBuddy.name) is responding...")
                                                            .font(.system(size: 10, weight: .medium))
                                                            .foregroundColor(Color(hex: "#60A5FA"))
                                                    }
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)
                                    }

                                    if let request = companion.pendingComputerUseRequest {
                                        ComputerUseConsentCardView(
                                            request: request,
                                            onAllowOnce: {
                                                companion.approveComputerUseOnce()
                                            },
                                            onAlwaysAllow: {
                                                companion.alwaysAllowComputerUse()
                                            },
                                            onNotNow: {
                                                companion.rejectComputerUse()
                                            },
                                            onClose: {
                                                companion.rejectComputerUse()
                                            }
                                        )
                                        .id("pendingComputerUseConsentCard")
                                        .padding(.top, 8)
                                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                                    } else if let action = companion.proposedComputerUseAction {
                                        ComputerUseConsentCardView(
                                            action: action,
                                            onApprove: { companion.approveComputerUseAction() },
                                            onReject: { companion.rejectComputerUseAction() }
                                        )
                                        .id("pendingComputerUseConsentCard")
                                        .padding(.top, 8)
                                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .padding(.bottom, 28)
                            }
                        .onAppear {
                            // Immediate Instant Bottom Pinning (Zero downward scroll animation)
                            if companion.pendingComputerUseRequest != nil || companion.proposedComputerUseAction != nil {
                                proxy.scrollTo("pendingComputerUseConsentCard", anchor: .bottom)
                            } else if let lastID = companion.activeBuddy.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                        .onChange(of: companion.activeSessionID) { _, _ in
                            visibleMessageLimit = 20
                            DispatchQueue.main.async {
                                if let lastID = companion.activeBuddy.messages.last?.id {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: companion.pendingComputerUseRequest != nil) { _, hasPending in
                            if hasPending {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    withAnimation { proxy.scrollTo("pendingComputerUseConsentCard", anchor: .bottom) }
                                }
                            }
                        }
                        .onChange(of: companion.activeBuddy.messages.count) { _, _ in
                            if let lastID = companion.activeBuddy.messages.last?.id {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(lastID, anchor: .bottom) }
                            }
                        }
                    }
                }

                // Sub-Section 2C: Floating Action Dock (1:1 Foto 1 & Foto 5, Centered compact width, zero color patch)
                    HStack {
                        Spacer()

                        VStack(spacing: 4) {
                            if let activeTool = toolDispatcher.currentExecutingToolName {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.55)
                                        .frame(width: 12, height: 12)
                                    Text("⚙️ Tool: \(activeTool)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Color(hex: "#38BDF8"))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3.5)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#0369A1").opacity(0.18))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "#38BDF8").opacity(0.35), lineWidth: 0.8)
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            HStack(spacing: 10) {
                                // Blue Circular Mic Button (Foto 1 - Clean Minimal)
                                Button(action: {
                                    if companion.buddyDictationManager.isRecordingFromMicrophoneButton {
                                        ClickySoundEngine.shared.play(.close)
                                        companion.buddyDictationManager.stopPersistentDictationFromMicrophoneButton()
                                    } else {
                                        ClickySoundEngine.shared.play(.open)
                                        Task {
                                            await companion.buddyDictationManager.startPersistentDictationFromMicrophoneButton(
                                                currentDraftText: inputText,
                                                updateDraftText: { transcribed in
                                                    inputText = transcribed
                                                },
                                                submitDraftText: { finalTranscript in
                                                    submitPrompt(finalTranscript)
                                                }
                                            )
                                        }
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: companion.buddyDictationManager.isRecordingFromMicrophoneButton ?
                                                        [Color(hex: "#FCA5A5"), Color(hex: "#EF4444")] :
                                                        [Color(hex: "#C7E5FE"), Color(hex: "#72B5FD")],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(width: 38, height: 38)
                                            .overlay(
                                                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1)
                                            )
                                            .shadow(
                                                color: companion.buddyDictationManager.isRecordingFromMicrophoneButton ?
                                                    Color.red.opacity(0.5) : Color(hex: "#60A5FA").opacity(0.4),
                                                radius: 5, y: 2
                                            )

                                        Image(systemName: companion.buddyDictationManager.isRecordingFromMicrophoneButton ? "stop.fill" : "mic.fill")
                                            .font(.system(size: companion.buddyDictationManager.isRecordingFromMicrophoneButton ? 11 : 13, weight: .bold))
                                            .foregroundColor(companion.buddyDictationManager.isRecordingFromMicrophoneButton ? .white : Color(hex: "#0F172A"))
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(companion.buddyDictationManager.isRecordingFromMicrophoneButton ? "Click to stop recording" : "Click to dictate voice or hold Control + Option")

                                // Input Pill (Foto 1)
                                HStack(spacing: 8) {
                                    Button(action: {
                                        ClickySoundEngine.shared.play(.open)
                                    }) {
                                        Image(systemName: "paperclip")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.55))
                                            .padding(6)
                                            .background(Circle().fill(Color.white.opacity(0.06)))
                                    }
                                    .buttonStyle(.plain)

                                    TextField("Message \(companion.activeBuddy.name)...", text: $inputText)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(.white)
                                        .onSubmit {
                                            submitPrompt(inputText)
                                        }

                                    Spacer(minLength: 4)

                                    if companion.isProcessingTask {
                                        Button(action: {
                                            companion.stopCurrentTask()
                                            CompanionRosterStore.shared.updateCompanionStatus(id: companion.activeBuddy.id, status: .idle)
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .frame(width: 28, height: 28)
                                                    .shadow(color: Color(hex: "#EF4444").opacity(0.4), radius: 4, x: 0, y: 1)

                                                Image(systemName: "stop.fill")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Button(action: {
                                            submitPrompt(inputText)
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.12) : Color(hex: "#72B5FD"))
                                                    .frame(width: 28, height: 28)

                                                Image(systemName: "arrow.up")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .white.opacity(0.4) : Color(hex: "#0F172A"))
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.45))
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [Color(hex: "#93C5FD").opacity(0.8), Color.white.opacity(0.15)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1.2
                                                )
                                        )
                                )
                            }

                            // Microtext below input (Foto 1)
                            HStack {
                                Text("Return to send • Shift Return for a new line")
                                    .font(.system(size: 9.5, weight: .regular))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.leading, 50)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: 580) // Compact locked width!

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
            }

            // Section 3: Character Inspector Sidebar (1:1 Foto 1, Slide-Over Overlay)
            if isCharacterSidebarOpen && !isCreatingNewBuddy && !isEditingCharacter {
                characterInspectorSidebar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

        }
    }

    // MARK: - Computed Properties & Helpers

    private var filteredSessions: [BuddySession] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return companion.sessions
        }
        return companion.sessions.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.roleDescription.localizedCaseInsensitiveContains(searchText) ||
            $0.lastSnippet.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var displayEmail: String {
        let email = usageManager.activeAccount.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty {
            return email
        }
        let userName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        return userName.isEmpty ? NSUserName() : userName
    }

    private var displayPlan: String {
        let plan = usageManager.activeAccount.plan.trimmingCharacters(in: .whitespacesAndNewlines)
        return plan.isEmpty ? "Google AI Pro" : plan
    }

    private var dynamicWelcomeTitle: String {
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

    private var dynamicWelcomeSubtitle: String {
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

    private func submitPrompt(_ prompt: String) {
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

    // MARK: - Header Center Switcher (1:1 Foto 2 & Foto 3)
    // Sits in 1 row inside the card header, frameless (no rounded pill card behind it)
    private var headerCenterSwitcher: some View {
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
    private var characterInspectorSidebar: some View {
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

    private var currentPresetDisplayName: String {
        if let p = CompanionAvatarLabCatalog.allPresets.first(where: { $0.semanticKey == editAvatarLabExpression || $0.id == editAvatarLabExpression }) {
            return "\(p.badgeNumber)  \(p.displayName)"
        }
        return "00  Neutral Upward"
    }

    private var currentAnimationDisplayName: String {
        if let s = animationEngine.currentSequence {
            return s.displayName
        }
        return "Select Sequence (23 available)..."
    }

    private var editingSessionSlug: String {
        let sanitized = editName.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        if !sanitized.isEmpty {
            return sanitized
        }
        return companion.activeBuddy.slug
    }

    // MARK: - Full Workspace Edit Character View (Option 1: Centered Studio Canvas)
    private var editCharacterFullWorkspaceView: some View {
        VStack(spacing: 0) {
            // Header Bar: Symmetrical Absolute Centered Title via ZStack
            ZStack {
                // Absolute Center Title (100% aligned with Avatar and Form center)
                Text("Edit Character")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Top-Right Close Button (Close Only — Back to Chat is in Sidebar)
                HStack {
                    Spacer()

                    Button(action: {
                        ClickySoundEngine.shared.play(.close)
                        onClose()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .help("Close back to notch")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Top-Pinned Workspace Content
            VStack(alignment: .leading, spacing: 18) {
                // 1. Live Hero Avatar Preview & Name/Role (Clean Minimalist Form)
                HStack(spacing: 16) {
                    CompanionProceduralAvatarView(
                        definition: currentEditDefinition,
                        expressionName: animationEngine.isPlaying ? animationEngine.currentExpressionKey : editAvatarLabExpression,
                        autoBlink: true,
                        size: 72
                    )
                    .frame(width: 76, height: 76)

                    VStack(alignment: .leading, spacing: 6) {
                        // Name & Role Inputs (Zero redundant buttons, zero extra pills)
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NAME")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))

                                TextField("Companion Name", text: $editName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("ROLE")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(.white.opacity(0.45))

                                TextField("Role", text: $editRole)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // 2. Character Shapes: "CHARACTER" (Clean Icons, Zero Cards, Zero Text)
                VStack(alignment: .leading, spacing: 8) {
                    Text("CHARACTER")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.6)

                    HStack(spacing: 12) {
                        ForEach(CompanionAvatarLabCatalog.allTemplates) { template in
                            let isSelected = editSelectedTemplateId == template.id
                            Button(action: {
                                ClickySoundEngine.shared.play(.send)
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    let oldT = CompanionAvatarLabCatalog.allTemplates.first(where: { $0.id == editSelectedTemplateId })
                                    let isNameOldOrEmpty = (oldT != nil && editName.lowercased() == oldT!.name.lowercased()) || editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    editSelectedTemplateId = template.id
                                    if isNameOldOrEmpty {
                                        editName = template.name
                                    }
                                    if editCloudColorHex.isEmpty {
                                        editCloudColorHex = template.defaultColors.bodyHex
                                    }
                                }
                            }) {
                                ZStack {
                                    if isSelected {
                                        Circle()
                                            .stroke(Color(hex: editCloudColorHex.isEmpty ? "#FF233B" : editCloudColorHex), lineWidth: 2)
                                            .frame(width: 40, height: 40)
                                    }

                                    CompanionProceduralAvatarView(
                                        definition: template.toAvatarDefinition(cloudColorHex: isSelected ? editCloudColorHex : nil),
                                        expressionName: "neutral",
                                        autoBlink: false,
                                        size: 28
                                    )
                                    .frame(width: 32, height: 32)
                                }
                                .frame(width: 42, height: 42)
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help(template.name)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)

                // 3. Option 2: 3-Column Top-Label Controls (COLOR | EXPRESSION | ANIMATION)
                HStack(alignment: .top, spacing: 18) {
                    // COLUMN 1: COLOR (Custom Swatch + Proportioned Hex Field + 4 Swatches)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("COLOR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        HStack(spacing: 6) {
                            // Circular Swatch with ColorPicker overlay
                            Circle()
                                .fill(Color(hex: editCloudColorHex.isEmpty ? "#FF233B" : editCloudColorHex))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                .overlay(
                                    ColorPicker("", selection: Binding(
                                        get: {
                                            Color(hex: editCloudColorHex.isEmpty ? "#FF233B" : editCloudColorHex)
                                        },
                                        set: { newColor in
                                            if let nsColor = NSColor(newColor).usingColorSpace(.sRGB) {
                                                let r = Int(round(nsColor.redComponent * 255.0))
                                                let g = Int(round(nsColor.greenComponent * 255.0))
                                                let b = Int(round(nsColor.blueComponent * 255.0))
                                                editCloudColorHex = String(format: "#%02X%02X%02X", r, g, b)
                                            }
                                        }
                                    ), supportsOpacity: false)
                                    .labelsHidden()
                                    .opacity(0.015)
                                )

                            // Hex text input field
                            HStack(spacing: 2) {
                                Text("#")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))

                                TextField("HEX", text: Binding(
                                    get: {
                                        editCloudColorHex.replacingOccurrences(of: "#", with: "").uppercased()
                                    },
                                    set: { newText in
                                        let cleaned = newText.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                        if cleaned.count <= 6 {
                                            editCloudColorHex = "#" + cleaned
                                        }
                                    }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 48)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )

                            // Quick Swatches (Gold, Cyan, Purple, Red)
                            HStack(spacing: 4) {
                                ForEach(["#FF9800", "#03BDA7", "#905AFD", "#FF233B"], id: \.self) { hex in
                                    Button(action: {
                                        ClickySoundEngine.shared.play(.send)
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            editCloudColorHex = hex
                                        }
                                    }) {
                                        Circle()
                                            .fill(Color(hex: hex))
                                            .frame(width: 12, height: 12)
                                            .overlay(
                                                Circle()
                                                    .stroke(editCloudColorHex.uppercased() == hex ? Color.white : Color.clear, lineWidth: 1.2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(width: 170, alignment: .leading)

                    // COLUMN 2: EXPRESSION (1 Chevron on Right)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("EXPRESSION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        Menu {
                            ForEach(CompanionAvatarLabCatalog.allPresets) { preset in
                                Button(action: {
                                    animationEngine.stop()
                                    ClickySoundEngine.shared.play(.send)
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                        editAvatarLabExpression = preset.semanticKey
                                    }
                                }) {
                                    HStack {
                                        Text("\(preset.badgeNumber)  \(preset.displayName)")
                                        if editAvatarLabExpression == preset.semanticKey {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(currentPresetDisplayName)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // COLUMN 3: ANIMATION (1 Chevron on Right + Live Play/Stop)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ANIMATION")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        HStack(spacing: 6) {
                            Menu {
                                ForEach(CompanionAvatarLabCatalog.allAnimations) { anim in
                                    Button(action: {
                                        ClickySoundEngine.shared.play(.send)
                                        animationEngine.play(sequence: anim) { stepExpr in
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                editAvatarLabExpression = stepExpr.semanticKey
                                            }
                                        }
                                    }) {
                                        HStack {
                                            Text("\(anim.displayName) (\(anim.category.rawValue))")
                                            if animationEngine.currentSequence?.id == anim.id {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(currentAnimationDisplayName)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                if animationEngine.isPlaying {
                                    animationEngine.stop()
                                } else if let s = animationEngine.currentSequence {
                                    animationEngine.play(sequence: s) { stepExpr in
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            editAvatarLabExpression = stepExpr.semanticKey
                                        }
                                    }
                                } else if let firstAnim = CompanionAvatarLabCatalog.allAnimations.first {
                                    animationEngine.play(sequence: firstAnim) { stepExpr in
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            editAvatarLabExpression = stepExpr.semanticKey
                                        }
                                    }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: animationEngine.isPlaying ? "stop.fill" : "play.fill")
                                        .font(.system(size: 8, weight: .bold))
                                    Text(animationEngine.isPlaying ? "Stop" : "Play")
                                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(animationEngine.isPlaying ? Color(hex: "#FF233B") : Color(hex: "#03BDA7"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)

                // 4. Companion Workspace & Storage Sandbox (Feature F-05)
                VStack(alignment: .leading, spacing: 7) {
                    Text("WORKSPACE & SANDBOX")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.6)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                Text("~/.izanotchy/companions/\(editingSessionSlug)/workspace")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                            }

                            Text("Isolated sandbox for deliverables, snapshots, memory & browser sessions")
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        Spacer()

                        Button(action: {
                            ClickySoundEngine.shared.play(.open)
                            CompanionWorkspaceManager.shared.openWorkspaceInFinder(for: editingSessionSlug)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.forward.square")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Open in Finder")
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Open companion workspace folder in Finder")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                    )
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: 640)

            // Pushes Action Buttons firmly to the bottom
            Spacer()

            // 4. Action Buttons (Save & Cancel) Pinned to Bottom
            HStack(spacing: 12) {
                Button(action: {
                    ClickySoundEngine.shared.play(.close)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isEditingCharacter = false
                        activeViewMode = .chats
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                Button(action: {
                    saveCharacterEdits()
                }) {
                    Text("Save Character")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private func modeIcon(for mode: HomeSpaceViewMode) -> String {
        switch mode {
        case .chats: return "bubble.left.and.bubble.right.fill"
        case .editCharacter: return "person.crop.circle"
        case .connectedApps: return "square.grid.2x2"
        }
    }

    private func toggleCompanionAppPermission(session: BuddySession, appName: String, enabled: Bool) {
        var currentApps = session.workflowAppNames
        if enabled {
            if !currentApps.contains(where: { $0.caseInsensitiveCompare(appName) == .orderedSame }) {
                currentApps.append(appName)
            }
        } else {
            if currentApps.count > 1 {
                currentApps.removeAll { $0.caseInsensitiveCompare(appName) == .orderedSame }
            }
        }

        CompanionRosterStore.shared.updateCompanion(
            id: session.id,
            name: session.name,
            role: session.roleDescription,
            cloudColorHex: session.avatarColorHex,
            ringColorHex: session.ringColorHex,
            mood: session.mood,
            templateId: session.templateId,
            animationKey: session.animationKey,
            currentExpressionKey: session.currentExpressionKey,
            workflowAppNames: currentApps,
            allowedSafariDomains: session.allowedSafariDomains,
            safariTabAccessMode: session.safariTabAccessMode
        )
        companion.updateSessionColorsAndDetails(
            companionId: session.id,
            name: session.name,
            role: session.roleDescription,
            cloudColorHex: session.avatarColorHex,
            ringColorHex: session.ringColorHex,
            mood: session.mood,
            templateId: session.templateId,
            animationKey: session.animationKey,
            currentExpressionKey: session.currentExpressionKey,
            workflowAppNames: currentApps,
            allowedSafariDomains: session.allowedSafariDomains,
            safariTabAccessMode: session.safariTabAccessMode
        )
        if let updatedProfile = CompanionRosterStore.shared.allCompanions.first(where: { $0.id == session.id }) {
            _ = CompanionWorkspaceManager.shared.generateCompanionSpec(for: updatedProfile)
        }
        ClickySoundEngine.shared.play(.send)
    }

    // MARK: - Dedicated Connected Apps Workspace View (F-14)
    private var connectedAppsWorkspaceView: some View {
        let currentSession = companion.activeBuddy
        let allowedApps = currentSession.workflowAppNames
        let displayedApps = appsDiscovery.filteredApps(query: searchAppQuery)

        return VStack(spacing: 0) {
            // Header Bar: Centered Title and Trailing Close Button (✕)
            ZStack {
                Text("Connected Applications")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack {
                    Spacer()

                    // Top-Right Close Button (Close Only — Back to Chat is in Sidebar)
                    Button(action: {
                        ClickySoundEngine.shared.play(.close)
                        onClose()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .help("Close back to notch")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Mac Apps Search Bar & Rescan Button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))

                    TextField("Search installed Mac apps...", text: $searchAppQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)

                    if !searchAppQuery.isEmpty {
                        Button(action: { searchAppQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )
                )

                // Reload Installed Apps Button
                Button(action: {
                    ClickySoundEngine.shared.play(.send)
                    appsDiscovery.scanInstalledApplications(forceReload: true)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Rescan installed macOS applications")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Scrollable List of Installed macOS Apps
            if displayedApps.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No applications found")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(displayedApps) { app in
                            let isAllowed = allowedApps.contains(where: {
                                $0.caseInsensitiveCompare(app.name) == .orderedSame ||
                                (app.bundleId != nil && $0.caseInsensitiveCompare(app.bundleId!) == .orderedSame)
                            })

                            HStack(spacing: 12) {
                                // Real Native 3D System App Icon
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)

                                // App Name (Clean, Bold White)
                                Text(app.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                // Native Toggle Switch
                                Toggle("", isOn: Binding(
                                    get: { isAllowed },
                                    set: { newValue in
                                        toggleCompanionAppPermission(session: currentSession, appName: app.name, enabled: newValue)
                                    }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#38BDF8")))
                                .labelsHidden()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isAllowed ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isAllowed ? Color(hex: "#38BDF8").opacity(0.25) : Color.white.opacity(0.04), lineWidth: 0.8)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func editPromptFileName(for name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(cleaned).md"
    }

    private func animationStepSummary(_ anim: AvatarLabAnimation) -> String {
        let stepChain = anim.steps.map { $0.semanticKey }.joined(separator: " → ")
        return "\(anim.steps.count) steps • \(stepChain)"
    }
}

// MARK: - Edit Studio Helper Subviews
private struct EditStudioPresetTile: View {
    let preset: AvatarLabPreset
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Text(preset.badgeNumber)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .white : Color(hex: "#38BDF8"))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isSelected ? Color(hex: "#38BDF8") : Color.white.opacity(0.08))
                    )

                Text(preset.displayName)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if isSelected {
                    Circle()
                        .fill(Color(hex: "#10B981"))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color(hex: "#38BDF8").opacity(0.18) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color(hex: "#38BDF8").opacity(0.6) : Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EditStudioAnimationRow: View {
    let anim: AvatarLabAnimation
    let isPlaying: Bool
    let summary: String
    let onTogglePlay: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(anim.displayName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(anim.category.rawValue)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }

                Text(summary)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onTogglePlay) {
                HStack(spacing: 4) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text(isPlaying ? "Stop" : "Play")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(isPlaying ? Color.white : Color(hex: "#0F172A"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isPlaying ? Color(hex: "#EF4444") : Color(hex: "#38BDF8"))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isPlaying ? Color(hex: "#38BDF8").opacity(0.12) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isPlaying ? Color(hex: "#38BDF8").opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
                )
        )
    }
}

extension HomeSpaceRootView {

    // MARK: - New Clicky Companion Onboarding View (Option A: 3-Step Native Stepper)
    private var newBuddyCreationView: some View {
        Group {
            switch interviewEngine.stage {
            case .interviewing:
                newBuddyInterviewView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            case .reviewingSpec:
                newBuddySpecReviewView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            case .customizingCharacter:
                newBuddyCharacterCustomizationView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            }
        }
    }

    // MARK: - Step 1: Interactive Interview with Glowing Cloud (1:1 Foto 4)
    private var newBuddyInterviewView: some View {
        VStack(spacing: 0) {
            // Header: < Back + New Clicky + Skip to Spec
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        isCreatingNewBuddy = false
                        newBuddyPromptText = ""
                        interviewEngine.reset()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
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

                Text("New Clicky")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.leading, 6)

                Spacer()

                if interviewEngine.userTurnCount >= 1 {
                    Button(action: {
                        interviewEngine.proceedToCharacterCustomization()
                    }) {
                        HStack(spacing: 4) {
                            Text("Skip to Spec")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            // Center Area: Glowing Mascot + Thought Bubble (Foto 4)
            VStack(spacing: 24) {
                Spacer()

                HStack(alignment: .bottom, spacing: 14) {
                    // Golden Yellow Glowing Mascot (Avatar Lab 3D Strobi)
                    CompanionProceduralAvatarView(
                        definition: CompanionAvatarDefinition(
                            name: "Interview Companion",
                            colors: AvatarColors(
                                bodyHex: "#FDE047",
                                eyesHex: "#111316"
                            )
                        ),
                        expressionName: interviewEngine.isThinking ? "curious-left" : "happy",
                        autoBlink: true,
                        size: 72
                    )
                    .shadow(color: Color(hex: "#FACC15").opacity(interviewEngine.isThinking ? 0.75 : 0.5), radius: interviewEngine.isThinking ? 20 : 14)
                    .scaleEffect(interviewEngine.isThinking ? 1.04 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: interviewEngine.isThinking)

                    // Speech Bubble (Foto 4)
                    VStack(alignment: .leading, spacing: 6) {
                        if interviewEngine.isThinking {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(Color(hex: "#3D2B1F"))
                            }
                            Text("Formulating the next helpful question for your Clicky...")
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(Color(hex: "#574030"))
                                .lineSpacing(2)
                        } else {
                            Text(interviewEngine.currentBubbleTitle)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(Color(hex: "#3D2B1F"))

                            Text(interviewEngine.currentBubbleBody)
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundColor(Color(hex: "#574030"))
                                .lineSpacing(2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FED7AA"), Color(hex: "#FDBA74")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, y: 3)
                    )
                    .overlay(
                        // Tiny thought dots at the bottom-left of the bubble
                        HStack(spacing: 3) {
                            Circle().fill(Color(hex: "#FDBA74")).frame(width: 4, height: 4)
                            Circle().fill(Color(hex: "#FDBA74")).frame(width: 6, height: 6)
                        }
                        .offset(x: -8, y: 12),
                        alignment: .bottomLeading
                    )
                    .frame(maxWidth: 360, alignment: .leading)
                }

                Spacer()

                // Bottom Controls (Foto 4)
                VStack(spacing: 10) {
                    // Large Voice Button: "Hold Control + Option to answer"
                    Button(action: {
                        if companion.buddyDictationManager.isRecordingFromMicrophoneButton {
                            companion.buddyDictationManager.stopPersistentDictationFromMicrophoneButton()
                        } else {
                            Task {
                                await companion.buddyDictationManager.startPersistentDictationFromMicrophoneButton(
                                    currentDraftText: newBuddyPromptText,
                                    updateDraftText: { transcribed in
                                        newBuddyPromptText = transcribed
                                    },
                                    submitDraftText: { finalTranscript in
                                        interviewEngine.submitUserAnswer(finalTranscript)
                                        newBuddyPromptText = ""
                                    }
                                )
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: companion.buddyDictationManager.isRecordingFromMicrophoneButton ? "stop.fill" : "mic.fill")
                                .font(.system(size: 13, weight: .bold))

                            Text(companion.buddyDictationManager.isRecordingFromMicrophoneButton ? "Recording... Click to finish" : "Hold Control + Option to answer")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "#0F172A"))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: companion.buddyDictationManager.isRecordingFromMicrophoneButton ?
                                            [Color(hex: "#FCA5A5"), Color(hex: "#EF4444")] :
                                            [Color(hex: "#C7E5FE"), Color(hex: "#8EC5FC")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1.2))
                        )
                        .shadow(color: Color(hex: "#60A5FA").opacity(0.4), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)

                    // Secondary Input: "or type your answer" (Foto 4)
                    HStack(spacing: 6) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.45))

                        TextField("or type your answer", text: $newBuddyPromptText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .onSubmit {
                                let trimmed = newBuddyPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    interviewEngine.submitUserAnswer(trimmed)
                                    newBuddyPromptText = ""
                                }
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.35))
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                    )
                    .frame(maxWidth: 320)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Step 2: Spec Review & Persona Markdown Editor
    private var newBuddySpecReviewView: some View {
        VStack(spacing: 0) {
            // Header: < Back to Interview + Review Spec
            HStack {
                Button(action: {
                    interviewEngine.backToInterview()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Interview")
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

                Text("Review Companion Spec")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.leading, 6)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 6)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Identity Card: Name & Role
                    VStack(alignment: .leading, spacing: 12) {
                        Text("COMPANION IDENTITY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(0.6)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Name")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("Buddy Name", text: $interviewEngine.synthesizedName)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                Text("Role")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                TextField("Role Title", text: $interviewEngine.synthesizedRole)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
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

                    // Markdown Spec Editor Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PERSONA SPEC & RULES (.md)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.45))
                                .tracking(0.6)

                            Spacer()

                            Text("Markdown Editable")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(Color(hex: "#38BDF8"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: "#38BDF8").opacity(0.12)))
                        }

                        Text("Edit the persona, instructions, memory rules, and skills that define how this companion thinks and acts.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.white.opacity(0.6))
                            .lineSpacing(1.5)

                        TextEditor(text: $interviewEngine.synthesizedSpecMarkdown)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(hex: "#E2E8F0"))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 180, maxHeight: 220)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.black.opacity(0.45))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                    )
                            )
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.07), lineWidth: 0.8))
                    )

                    // Navigation to Character Studio
                    Button(action: {
                        interviewEngine.proceedToCharacterCustomization()
                    }) {
                        HStack(spacing: 8) {
                            Text("Continue to Character Design")
                                .font(.system(size: 12.5, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#0F172A"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Step 3: Character Appearance Studio & Launch
    private var newBuddyCharacterCustomizationView: some View {
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

    private func animationRowView(_ anim: AvatarLabAnimation) -> some View {
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

    private func avatarLabPresetDisplayName(_ id: String) -> String {
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

    private func startEditing(session: BuddySession) {
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

    private func saveCharacterEdits() {
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

    private func isThemeSelected(_ theme: CompanionColorTheme) -> Bool {
        theme.cloudColorHex.caseInsensitiveCompare(editCloudColorHex) == .orderedSame &&
        theme.ringColorHex.caseInsensitiveCompare(editRingColorHex) == .orderedSame
    }
}

// (ThemeSwatchButton, FollowUpPillButton, and MarkdownFormattedMessageView extracted to Components/)
