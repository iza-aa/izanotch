import SwiftUI
import Combine
import AppKit

public struct NotchRootView: View {
    @ObservedObject public var stateController: NotchStateController
    @ObservedObject public var cardStore: CardDataStore = .shared
    public var hoverMonitor: NotchHoverMonitor?
    public var audioLevels: [CGFloat]
    public var hasPhysicalNotch: Bool
    public var hardwareNotchWidth: CGFloat
    public var hardwareNotchHeight: CGFloat
    public var onAIModelSelected: (@MainActor (String) -> Void)?
    public var onSubmitPrompt: (@MainActor (String) -> Void)?
    public var onReplyClarification: (@MainActor (String) -> Void)?
    public var onToggleMic: (@MainActor () -> Void)?
    public var onStopMic: (@MainActor () -> Void)?
    public var onAddSchedule: (@MainActor (String) -> Void)?
    @State private var statusRotationIndex = 0
    private let statusRotationTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    public init(
        stateController: NotchStateController,
        cardStore: CardDataStore = .shared,
        hoverMonitor: NotchHoverMonitor? = nil,
        audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7],
        hasPhysicalNotch: Bool = true,
        hardwareNotchWidth: CGFloat = 160,
        hardwareNotchHeight: CGFloat = NotchGeometryCalculator.defaultNotchHeight,
        onAIModelSelected: (@MainActor (String) -> Void)? = nil,
        onSubmitPrompt: (@MainActor (String) -> Void)? = nil,
        onReplyClarification: (@MainActor (String) -> Void)? = nil,
        onToggleMic: (@MainActor () -> Void)? = nil,
        onStopMic: (@MainActor () -> Void)? = nil,
        onAddSchedule: (@MainActor (String) -> Void)? = nil
    ) {
        self.stateController = stateController
        self.cardStore = cardStore
        self.hoverMonitor = hoverMonitor
        self.audioLevels = audioLevels
        self.hasPhysicalNotch = hasPhysicalNotch
        self.hardwareNotchWidth = hardwareNotchWidth
        self.hardwareNotchHeight = hardwareNotchHeight
        self.onAIModelSelected = onAIModelSelected
        self.onSubmitPrompt = onSubmitPrompt
        self.onReplyClarification = onReplyClarification
        self.onToggleMic = onToggleMic
        self.onStopMic = onStopMic
        self.onAddSchedule = onAddSchedule
    }

    private var contentTopPadding: CGFloat {
        NotchGeometryCalculator.contentTopInset(
            hasPhysicalNotch: hasPhysicalNotch,
            physicalNotchHeight: hardwareNotchHeight
        )
    }

    public var body: some View {
        Group {
            if stateController.currentState == .hidden {
                Color.clear.frame(width: 0, height: 0)
            } else if stateController.currentState == .expanded {
                // EXPANDED: Left AI Model Dock + Center Main Tray + Right Feature Tabs Dock
                HStack(alignment: .top, spacing: -14) {
                    // 1. LEFT FLOATING SIDE DOCK: AI Model Switcher (Antigravity, Codex, Claude Code)
                    VStack(spacing: 7) {
                        floatingSideButton(id: "Antigravity", icon: "sparkles", color: .cyan, name: "Antigravity 2.0")
                        floatingSideButton(id: "Codex", icon: "cpu.fill", color: .green, name: "Codex ChatGPT")
                        floatingSideButton(id: "Claude Code", icon: "terminal.fill", color: .orange, name: "Claude Code")
                    }
                    .padding(4)
                    .background(
                        Capsule()
                            .fill(Color.black)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                    )
                    .padding(.top, contentTopPadding)
                    .zIndex(2)

                    // 2. MAIN TRAY. The black surface is connected to the
                    // physical camera notch and uses both menu-bar wings.
                    ZStack {
                        NotchShape(
                            topCornerRadius: 19,
                            bottomCornerRadius: 24
                        )
                        .fill(Color.black)

                        expandedContent
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 3. RIGHT FLOATING SIDE DOCK: Feature Tabs Switcher (AI Chat, Notes, Schedule, Music, Clipboard)
                    VStack(spacing: 7) {
                        ForEach(NotchFeatureTab.allCases) { tab in
                            floatingTabButton(tab: tab)
                        }
                    }
                    .padding(4)
                    .background(
                        Capsule()
                            .fill(Color.black)
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                            )
                    )
                    .padding(.top, contentTopPadding)
                    .zIndex(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onHover { isHovered in
                    if isHovered {
                        hoverMonitor?.mouseEntered()
                    } else {
                        hoverMonitor?.mouseExited()
                    }
                }
            } else {
                // COLLAPSED / LIVE ACTIVITY / VOICE ACTIVE
                ZStack {
                    statusBarBackground

                    Group {
                        switch stateController.currentState {
                        case .hidden, .expanded:
                            EmptyView()

                        case .collapsed:
                            collapsedContent

                        case .voiceActive:
                            voiceActiveContent

                        case .liveActivity(let title, let countdown):
                            liveActivityContent(title: title, countdown: countdown)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .onHover { isHovered in
                    if isHovered {
                        hoverMonitor?.mouseEntered()
                    } else {
                        hoverMonitor?.mouseExited()
                    }
                }
            }
        }
        .onReceive(statusRotationTimer) { _ in
            let count = stateController.compactProviderStatuses.count
            if count <= 1 {
                statusRotationIndex = 0
            } else {
                statusRotationIndex = (statusRotationIndex + 1) % count
            }
        }
    }

    private func floatingSideButton(id: String, icon: String, color: Color, name: String) -> some View {
        let isSelected = stateController.activeAIModel == id
        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                stateController.selectAIModel(id)
                onAIModelSelected?(id)
            }
        }) {
            ZStack {
                Circle()
                    .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)

                if isSelected {
                    Circle()
                        .strokeBorder(color.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                }

                providerIconView(
                    providerID: id,
                    systemIcon: icon,
                    size: 11.5,
                    tint: isSelected ? color : .white.opacity(0.65)
                )
            }
        }
        .buttonStyle(.plain)
        .help(name)
    }

    // MARK: - Standby status bar

    /// A single connected black surface wraps the physical camera notch and
    /// uses the menu-bar wings on both sides for status content.
    @ViewBuilder
    private var statusBarBackground: some View {
        if hasPhysicalNotch {
            NotchShape(
                topCornerRadius: 6,
                bottomCornerRadius: 14
            )
            .fill(Color.black)
        } else {
            Capsule()
                .fill(Color.black.opacity(0.96))
        }
    }

    // MARK: - Collapsed standby

    private var collapsedContent: some View {
        Button(action: { stateController.transition(to: .expanded) }) {
            connectedStatusRow(
                left: {
                    Text("Notch Docks")
                },
                right: {
                    compactProviderStatusContent
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Live Activity

    /// Compact activity content that lives inside the standby notch frame.
    /// It intentionally has no model icon, status dot, vertical expansion, or
    /// Dynamic-Island-style spacer.
    private func liveActivityContent(title: String, countdown _: String) -> some View {
        Button(action: { stateController.openLiveActivity() }) {
            connectedStatusRow(
                left: {
                    Text("Notch Docks")
                },
                right: {
                    compactProviderStatusContent
                }
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func connectedStatusRow<LeftContent: View, RightContent: View>(
        @ViewBuilder left: () -> LeftContent,
        @ViewBuilder right: () -> RightContent
    ) -> some View {
        HStack(spacing: 0) {
            left()
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if hasPhysicalNotch {
                Color.clear
                    .frame(
                        width: hardwareNotchWidth
                            + (2 * NotchGeometryCalculator.statusCameraClearance)
                    )
            }

            right()
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Voice Active

    private var voiceActiveContent: some View {
        VStack {
            Spacer(minLength: hasPhysicalNotch ? 34 : 4)
            HStack(spacing: 12) {
                AudioWaveformView(levels: audioLevels)

                Text(stateController.commandPrompt.isEmpty ? "Listening..." : stateController.commandPrompt)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Button(action: { onStopMic?() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }


    private func cleanTitle(_ text: String) -> String {
        // Strip out any accidental unicode emoji characters
        text.unicodeScalars.filter { !$0.properties.isEmojiPresentation && $0.value > 127 ? false : true }.map(String.init).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var compactProviderStatusContent: some View {
        let statuses = stateController.compactProviderStatuses
        let index = min(statusRotationIndex, max(0, statuses.count - 1))
        let provider = statuses.isEmpty
            ? ProviderStatus(id: stateController.activeAIModel, status: "Ready", isActive: false)
            : statuses[index]

        return HStack(spacing: 5) {
            providerIconView(
                providerID: provider.id,
                systemIcon: provider.iconName,
                size: 13,
                tint: .white
            )
            Text(provider.status)
        }
    }

    @ViewBuilder
    private func providerIconView(
        providerID: String,
        systemIcon: String,
        size: CGFloat,
        tint: Color
    ) -> some View {
        let resourceName = ProviderStatus(
            id: providerID,
            status: "Ready",
            isActive: false
        ).iconResourceName

        if let resourceName,
           let iconURL = Bundle.module.url(forResource: resourceName, withExtension: "png"),
           let iconImage = NSImage(contentsOf: iconURL) {
            Image(nsImage: iconImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: systemIcon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: size, height: size)
        }
    }

    private func floatingTabButton(tab: NotchFeatureTab) -> some View {
        let isSelected = stateController.activeTab == tab
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                stateController.selectTab(tab)
            }
        }) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.24) : Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)

                if isSelected {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                }

                Image(systemName: tab.iconName)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.65))
            }
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
    }

    // MARK: - Expanded: Feature Panels (Full vertical space)

    private var expandedContent: some View {
        Group {
            switch stateController.activeTab {
            case .aiChat:
                AIChatPanelView(
                    stateController: stateController,
                    onSubmitPrompt: onSubmitPrompt,
                    onReplyClarification: onReplyClarification,
                    onToggleMic: onToggleMic
                )

            case .notes:
                NotesPanelView(cardStore: cardStore)

            case .schedule:
                SchedulePanelView(
                    cardStore: cardStore,
                    onAddSchedule: onAddSchedule
                )

            case .music:
                MusicLyricsPanelView()

            case .clipboard:
                ClipboardPanelView(cardStore: cardStore)
            }
        }
        .padding(.top, contentTopPadding)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }

    // MARK: - Helpers

    private var isExpanded: Bool {
        stateController.currentState == .expanded
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).width
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        NotchGeometryCalculator.dimensions(for: state, hasPhysicalNotch: hasPhysicalNotch).height
    }
}
