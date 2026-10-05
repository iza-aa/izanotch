//
//  CompanionManager.swift
//  leanring-buddy
//
//  Central state manager for the companion voice mode. Owns the push-to-talk
//  pipeline (dictation manager + global shortcut monitor + overlay) and
//  exposes observable voice state for the panel UI.
//

import AVFoundation
import Combine
import Defaults
import Foundation
import ScreenCaptureKit
import Speech
import SwiftUI
import Vision

enum CompanionVoiceState {
    case idle
    case listening
    case processing
    case responding
}

/// Metadata about the user's active frontmost application window
struct ActiveWorkSurface {
    let appName: String
    let windowTitle: String
    let frame: CGRect
    let ownerPID: pid_t?

    /// The center coordinates of the macOS traffic light close button (red circle)
    var trafficLightCloseCenter: CGPoint {
        // macOS standard traffic light close button is inset ~18pt from left and ~17pt from top of window frame
        CGPoint(x: frame.origin.x + 18, y: frame.origin.y + 17)
    }

    /// The center coordinates of the macOS traffic light minimize button (yellow circle)
    var trafficLightMinimizeCenter: CGPoint {
        CGPoint(x: frame.origin.x + 38, y: frame.origin.y + 17)
    }

    /// The center coordinates of the macOS traffic light zoom/fullscreen button (green circle)
    var trafficLightZoomCenter: CGPoint {
        CGPoint(x: frame.origin.x + 58, y: frame.origin.y + 17)
    }

    /// The center coordinates of the window's title bar header
    var titleBarCenter: CGPoint {
        CGPoint(x: frame.midX, y: frame.origin.y + 17)
    }

    /// The center of the window
    var windowCenter: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

/// Represents a resolved UI location of a macOS Dock item
struct DockItemLocation {
    let name: String
    let bundleIdentifier: String?
    let screenPoint: CGPoint
    let size: CGSize
    let screenBounds: CGRect
}

@MainActor
enum MacOSDockManager {
    /// Retrieves all visible items in the macOS Dock dynamically
    static func getAllDockItems() -> [DockItemLocation] {
        let axItems = queryDockItemsViaAccessibility()
        if !axItems.isEmpty {
            return axItems
        }
        return queryDockItemsViaPreferencesFallback()
    }

    /// Finds a specific Dock item by app name (fuzzy case-insensitive match)
    static func getDockItem(named query: String) -> DockItemLocation? {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanQuery.isEmpty else { return nil }

        let all = getAllDockItems()
        // 1. Exact match
        if let exact = all.first(where: { $0.name.lowercased() == cleanQuery }) {
            return exact
        }
        // 2. Query contains item name or item name contains query
        if let match = all.first(where: {
            let itemLower = $0.name.lowercased()
            return cleanQuery.contains(itemLower) || itemLower.contains(cleanQuery)
        }) {
            return match
        }
        // 3. Bundle identifier match
        if let match = all.first(where: {
            if let bundle = $0.bundleIdentifier?.lowercased() {
                return bundle.contains(cleanQuery) || cleanQuery.contains(bundle)
            }
            return false
        }) {
            return match
        }
        return nil
    }

    private static func queryDockItemsViaAccessibility() -> [DockItemLocation] {
        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            return []
        }

        let appElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        var listValue: AnyObject?
        let err = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &listValue)
        guard err == .success, let children = listValue as? [AXUIElement] else {
            return []
        }

        var results: [DockItemLocation] = []
        for child in children {
            var subValue: AnyObject?
            if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subValue) == .success,
               let items = subValue as? [AXUIElement] {
                for item in items {
                    var titleVal: AnyObject?
                    var posVal: AnyObject?
                    var sizeVal: AnyObject?
                    _ = AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleVal)
                    _ = AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &posVal)
                    _ = AXUIElementCopyAttributeValue(item, kAXSizeAttribute as CFString, &sizeVal)

                    var pos = CGPoint.zero
                    var size = CGSize.zero
                    if let p = posVal as! AXValue? { AXValueGetValue(p, .cgPoint, &pos) }
                    if let s = sizeVal as! AXValue? { AXValueGetValue(s, .cgSize, &size) }

                    let title = (titleVal as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !title.isEmpty && size.width > 0 && size.height > 0 {
                        // Hotfix #12 (docktrace3 22 Sep, BUKTI FINAL): semua ikon
                        // (badge/tidak) pos.y=907 IDENTIK -> teori badge RUNTUH.
                        // AX Dock = CG top-left (dari atas): center (257,942) cocok
                        // 100% dengan visual crop (942/982 dari atas). Tapi Overlay
                        // render seolah AppKit (dari bawah) -> mendarat di atas.
                        // Konversi BENAR: AppKit = (x, primaryH - y) = (257,40) ->
                        // SwiftUI y = 982-40 = 942 = Dock bawah. BENAR.
                        let primaryH = NSScreen.screens.first?.frame.height ?? 982
                        let centerCG = CGPoint(x: pos.x + size.width / 2.0, y: pos.y + size.height / 2.0)
                        let center = CGPoint(x: centerCG.x, y: primaryH - centerCG.y)
                        results.append(DockItemLocation(
                            name: title,
                            bundleIdentifier: nil,
                            screenPoint: center,
                            size: size,
                            screenBounds: CGRect(origin: pos, size: size)
                        ))
                    }
                }
            }
        }
        return results
    }

    private static func queryDockItemsViaPreferencesFallback() -> [DockItemLocation] {
        guard let screen = NSScreen.main else { return [] }
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let dockHeight = visibleFrame.origin.y > 0 ? visibleFrame.origin.y : 76.0
        let dockCenterY = screenFrame.height - (dockHeight / 2.0)

        guard let dict = UserDefaults(suiteName: "com.apple.dock")?.dictionaryRepresentation(),
              let persistentApps = dict["persistent-apps"] as? [[String: Any]] else {
            return []
        }

        var appNames: [(name: String, bundle: String?)] = []
        appNames.append((name: "Finder", bundle: "com.apple.finder"))

        for item in persistentApps {
            if let tileData = item["tile-data"] as? [String: Any],
               let label = tileData["file-label"] as? String {
                let bundle = tileData["bundle-identifier"] as? String
                appNames.append((name: label, bundle: bundle))
            }
        }

        let tilesize = CGFloat(dict["tilesize"] as? Int ?? 50)
        let spacing: CGFloat = max(6.0, tilesize * 0.18)
        let totalItemsWidth = CGFloat(appNames.count) * tilesize + CGFloat(appNames.count - 1) * spacing
        let startX = (screenFrame.width - totalItemsWidth) / 2.0

        var results: [DockItemLocation] = []
        for (index, app) in appNames.enumerated() {
            let itemX = startX + CGFloat(index) * (tilesize + spacing)
            let itemCenter = CGPoint(x: itemX + tilesize / 2.0, y: dockCenterY)
            let itemRect = CGRect(x: itemX, y: dockCenterY - tilesize / 2.0, width: tilesize, height: tilesize)
            results.append(DockItemLocation(
                name: app.name,
                bundleIdentifier: app.bundle,
                screenPoint: itemCenter,
                size: CGSize(width: tilesize, height: tilesize),
                screenBounds: itemRect
            ))
        }

        return results
    }
}

@MainActor
enum ActiveWorkSurfaceManager {
    /// Discovers the active application window on screen (excluding boringNotch itself, cua-driver, and system overlays)
    static func getActiveWorkSurface(targetAppName: String? = nil, queryHint: String? = nil) -> ActiveWorkSurface? {
        let ignoredOwners: Set<String> = [
            "Window Server", "Dock", "boringNotch", "cua-driver", "Siri",
            "Notification Center", "Control Center", "SystemUIServer", "Spotlight", "TextInputMenuAgent"
        ]

        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }

        // Pass 0: Explicit app match from targetAppName or queryHint
        let hint = (queryHint ?? "").lowercased()
        var explicitAppName: String? = targetAppName
        if explicitAppName == nil && !hint.isEmpty {
            for app in runningApps {
                let name = app.localizedName ?? ""
                if !name.isEmpty && hint.contains(name.lowercased()) {
                    explicitAppName = name
                    break
                }
            }
        }

        if let target = explicitAppName {
            for w in windowList {
                let layer = w[kCGWindowLayer as String] as? Int ?? -1
                let owner = w[kCGWindowOwnerName as String] as? String ?? ""
                let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t
                let title = w[kCGWindowName as String] as? String ?? ""
                guard layer == 0, !ignoredOwners.contains(where: { owner.localizedCaseInsensitiveContains($0) }) else { continue }

                if owner.localizedCaseInsensitiveContains(target) {
                    if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
                       let x = boundsDict["X"] as? Double,
                       let y = boundsDict["Y"] as? Double,
                       let width = boundsDict["Width"] as? Double,
                       let height = boundsDict["Height"] as? Double {
                        let rect = CGRect(x: x, y: y, width: width, height: height)
                        if rect.width > 200 && rect.height > 100 {
                            return ActiveWorkSurface(
                                appName: owner,
                                windowTitle: title,
                                frame: rect,
                                ownerPID: ownerPID
                            )
                        }
                    }
                }
            }
        }

        // Pass 1: Frontmost application window (if not boringNotch or ignored)
        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontAppName = frontApp?.localizedName ?? ""
        let frontPID = frontApp?.processIdentifier
        if let frontPID = frontPID, !ignoredOwners.contains(where: { frontAppName.localizedCaseInsensitiveContains($0) }) {
            for w in windowList {
                let layer = w[kCGWindowLayer as String] as? Int ?? -1
                let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t
                let owner = w[kCGWindowOwnerName as String] as? String ?? ""
                let title = w[kCGWindowName as String] as? String ?? ""
                guard layer == 0, ownerPID == frontPID else { continue }

                if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
                   let x = boundsDict["X"] as? Double,
                   let y = boundsDict["Y"] as? Double,
                   let width = boundsDict["Width"] as? Double,
                   let height = boundsDict["Height"] as? Double {
                    let rect = CGRect(x: x, y: y, width: width, height: height)
                    if rect.width > 200 && rect.height > 100 {
                        return ActiveWorkSurface(
                            appName: owner.isEmpty ? frontAppName : owner,
                            windowTitle: title,
                            frame: rect,
                            ownerPID: ownerPID
                        )
                    }
                }
            }
        }

        // Pass 2: Window directly under mouse cursor
        let mouseCocoa = NSEvent.mouseLocation
        let screenH = NSScreen.screens.first?.frame.height ?? 982
        let mouseCG = CGPoint(x: mouseCocoa.x, y: screenH - mouseCocoa.y)
        for w in windowList {
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t
            let title = w[kCGWindowName as String] as? String ?? ""
            guard layer == 0, !ignoredOwners.contains(where: { owner.localizedCaseInsensitiveContains($0) }) else { continue }

            if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
               let x = boundsDict["X"] as? Double,
               let y = boundsDict["Y"] as? Double,
               let width = boundsDict["Width"] as? Double,
               let height = boundsDict["Height"] as? Double {
                let rect = CGRect(x: x, y: y, width: width, height: height)
                if rect.contains(mouseCG) && rect.width > 300 && rect.height > 200 && !owner.localizedCaseInsensitiveContains("iPhone Mirroring") {
                    return ActiveWorkSurface(
                        appName: owner,
                        windowTitle: title,
                        frame: rect,
                        ownerPID: ownerPID
                    )
                }
            }
        }

        // Pass 3: Topmost regular desktop window in z-order (deprioritizing iPhone Mirroring / accessory)
        var fallbackAccessory: ActiveWorkSurface? = nil
        for w in windowList {
            let layer = w[kCGWindowLayer as String] as? Int ?? -1
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let ownerPID = w[kCGWindowOwnerPID as String] as? pid_t
            let title = w[kCGWindowName as String] as? String ?? ""
            guard layer == 0, !ignoredOwners.contains(where: { owner.localizedCaseInsensitiveContains($0) }) else { continue }

            if let boundsDict = w[kCGWindowBounds as String] as? [String: Any],
               let x = boundsDict["X"] as? Double,
               let y = boundsDict["Y"] as? Double,
               let width = boundsDict["Width"] as? Double,
               let height = boundsDict["Height"] as? Double {
                let rect = CGRect(x: x, y: y, width: width, height: height)
                if rect.width > 200 && rect.height > 100 {
                    let surface = ActiveWorkSurface(
                        appName: owner,
                        windowTitle: title,
                        frame: rect,
                        ownerPID: ownerPID
                    )
                    if owner.localizedCaseInsensitiveContains("iPhone Mirroring") {
                        if fallbackAccessory == nil {
                            fallbackAccessory = surface
                        }
                    } else {
                        return surface
                    }
                }
            }
        }

        return fallbackAccessory
    }
}

@MainActor
final class CompanionManager: ObservableObject {
    static let shared = CompanionManager()

    func enableCursor() {
        setClickyCursorEnabled(true)
    }

    func disableCursor() {
        setClickyCursorEnabled(false)
    }

    func toggleHomeSpace() {
        if let host = CompanionUIHostRegistry.shared {
            host.toggleHomeSpace()
        } else {
            HomeSpaceWindowManager.shared.toggle()
        }
    }

    func openHomeSpace() {
        if let host = CompanionUIHostRegistry.shared {
            host.showHomeSpace()
        } else {
            HomeSpaceWindowManager.shared.show()
        }
    }

    func toggleHUD() {}

    @Published var proposedComputerUseAction: ComputerUseProposedAction? = nil
    @Published public var pendingComputerUseRequest: ComputerUseRequest? = nil

    @Published private(set) var voiceState: CompanionVoiceState = .idle
    @Published private(set) var lastTranscript: String?
    @Published private(set) var currentAudioPowerLevel: CGFloat = 0
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var hasScreenRecordingPermission = false
    @Published private(set) var hasMicrophonePermission = false
    @Published private(set) var hasSpeechRecognitionPermission = false
    @Published private(set) var hasScreenContentPermission = false

    /// Screen location (global AppKit coords) of a detected UI element the
    /// buddy should fly to and point at. Parsed from Claude's response;
    /// observed by BlueCursorView to trigger the flight animation.
    @Published var detectedElementScreenLocation: CGPoint?
    /// The display frame (global AppKit coords) of the screen the detected
    /// element is on, so BlueCursorView knows which screen overlay should animate.
    @Published var detectedElementDisplayFrame: CGRect?
    /// Custom speech bubble text for the pointing animation. When set,
    /// BlueCursorView uses this instead of a random pointer phrase.
    @Published var detectedElementBubbleText: String?
    /// Target halo radius in points (parsed from [TARGET:x,y,r:label])
    @Published var detectedElementTargetRadius: CGFloat = 35.0
    /// Short element label for the pointing bubble
    @Published var detectedElementLabel: String?
    /// Whether streaming has already triggered flight for the active turn
    private var hasTriggeredStreamingFlight: Bool = false
    /// Hotfix #3: expression yang dipakai flight streaming (UNVERIFIED) —
    /// diverifikasi vs expression final di fallback; dibersihkan tiap turn baru.
    private var flownTargetExpression: String? = nil
    /// Buffer of raw incoming streaming chunks to parse early tags
    private var accumulatedRawStreamingText: String = ""
    /// Current frontmost active application work surface
    private var currentActiveWorkSurface: ActiveWorkSurface?
    /// Watchdog work item to ensure detectedElementScreenLocation never traps cursor
    private var flightWatchdogWorkItem: DispatchWorkItem?
    /// Plan sinkron-teks S3: estimasi durasi TTS terakhir (dtk) untuk hold bubble.
    private var lastTTSDurationEstimate: TimeInterval = 0
    /// Plan sinkron-teks S3: kapan flight terakhir selesai (untuk hold bubble).
    private var lastFlightEndEstimate: Date? = nil

    // MARK: - Onboarding Video State (shared across all screen overlays)

    @Published var onboardingVideoPlayer: AVPlayer?
    @Published var showOnboardingVideo: Bool = false
    @Published var onboardingVideoOpacity: Double = 0.0
    private var onboardingVideoEndObserver: NSObjectProtocol?
    private var onboardingDemoTimeObserver: Any?

    // MARK: - Onboarding Prompt Bubble

    /// Text streamed character-by-character on the cursor after the onboarding video ends.
    @Published var onboardingPromptText: String = ""
    @Published var onboardingPromptOpacity: Double = 0.0
    @Published var showOnboardingPrompt: Bool = false

    // MARK: - Onboarding Music

    private var onboardingMusicPlayer: AVAudioPlayer?
    private var onboardingMusicFadeTimer: Timer?

    let buddyDictationManager = BuddyDictationManager()
    let globalPushToTalkShortcutMonitor = GlobalPushToTalkShortcutMonitor()
    let overlayWindowManager = OverlayWindowManager.shared

    // MARK: - Streaming Response Bubble State

    /// The text currently being streamed from the AI response.
    @Published var streamingResponseText: String = ""
    /// Whether the response bubble is currently active.
    @Published var isShowingStreamingResponse: Bool = false
    /// Opacity of the response bubble for smooth transitions.
    @Published var streamingResponseOpacity: Double = 0.0
    /// Work item to auto-hide the response bubble after reading delay.
    private var responseBubbleHideWorkItem: DispatchWorkItem?

    public var isResponding: Bool {
        voiceState == .responding || isShowingStreamingResponse
    }

    public var currentStreamingResponse: String {
        streamingResponseText
    }

    /// Google Gemini AI client that communicates with the local Antigravity Gemini bridge by default
    lazy var geminiClient: GeminiBridgeClient = {
        let bridgePort = Defaults[.antigravityBridgePort] > 0 ? Defaults[.antigravityBridgePort] : 8080
        return GeminiBridgeClient(proxyURL: "http://127.0.0.1:\(bridgePort)/v1/messages", model: selectedModel)
    }()

    var claudeAPI: GeminiBridgeClient {
        geminiClient
    }

    private lazy var elevenLabsTTSClient: ElevenLabsTTSClient = {
        return ElevenLabsTTSClient(proxyURL: "https://your-worker-name.your-subdomain.workers.dev/tts")
    }()

    /// Conversation history so Claude remembers prior exchanges within a session.
    /// Each entry is the user's transcript, the stripped spoken text, and the raw response
    /// (preserving [POINT:x,y:label] tags) so subsequent turns can imitate the tag format.
    private var conversationHistory: [(userTranscript: String, assistantResponse: String, rawResponseWithTags: String, groundingHit: Bool)] = []

    /// Published transcript for Home Space chat view
    @Published public var chatMessages: [HomeSpaceChatMessage] = []

    /// Dedicated live streaming state for Home Space chat view
    @Published public var homeSpaceStreamingText: String = ""
    @Published public var isHomeSpaceStreaming: Bool = false
    private var streamingWatchdogWorkItem: DispatchWorkItem?

    private func armStreamingWatchdog(timeout: TimeInterval = 6.0) {
        streamingWatchdogWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.isHomeSpaceStreaming {
                ClickyLogger.warning("[STREAM_WATCHDOG]", "Streaming chunk timeout (\(timeout)s) reached without clean handover. Forcing safe teardown.")
                let fallbackText = self.homeSpaceStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isHomeSpaceStreaming = false
                self.homeSpaceStreamingText = ""
                if !fallbackText.isEmpty {
                    self.appendChatMessage(HomeSpaceChatMessage(isUser: false, text: fallbackText))
                }
                self.voiceState = .idle
                CompanionRosterStore.shared.updateCompanionStatus(id: self.activeBuddy.id, status: .idle)
            }
        }
        streamingWatchdogWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    private func disarmStreamingWatchdog() {
        streamingWatchdogWorkItem?.cancel()
        streamingWatchdogWorkItem = nil
    }

    /// Current autonomous task goal being executed across multi-step iterations
    public var ongoingTaskGoal: String? = nil
    /// Session-level pre-approval granted by user via "Allow once" or "Always allow" for ongoing task
    @Published public var isTaskSessionPreApproved: Bool = false

    // ReAct loop consent-gate state — stores pending loop state while awaiting user approval
    internal var pendingReActMessages: [[String: Any]] = []
    private var pendingReActSystemPrompt: String = ""
    private var pendingReActNativeTools: [[String: Any]] = []
    private var pendingReActScreenCaptures: [CompanionScreenCapture] = []
    private var pendingReActOriginalTranscript: String = ""

    public var isProcessingTask: Bool {
        voiceState == .processing || isHomeSpaceStreaming || isTaskSessionPreApproved
    }

    public var isSiriAI: Bool {
        Defaults[.selectedAIAssistant] == "Siri AI" || Defaults[.selectedAIAssistant] == "Siri AI (AFM)"
    }

    private static let initialSessions: [BuddySession] = [
        BuddySession(
            name: "Research Buddy",
            roleDescription: "Competitor & web research specialist",
            avatarColorHex: "#4ADE80",
            ringColorHex: "#FBCFE8",
            timestampString: "Just now",
            lastSnippet: "Ready to research your active screen & documents.",
            messages: []
        ),
        BuddySession(
            name: "Shippy",
            roleDescription: "Single-screen workspace & code deployer",
            avatarColorHex: "#818CF8",
            ringColorHex: "#FEF08A",
            timestampString: "Just now",
            lastSnippet: "Ready to assist with Xcode and workspaces.",
            messages: []
        ),
        BuddySession(
            name: "Clicky Screen Assistant",
            roleDescription: "Screen navigation & Computer Use executor",
            avatarColorHex: "#38BDF8",
            ringColorHex: "#BAE6FD",
            timestampString: "Just now",
            lastSnippet: "Ready to guide, point, and execute tasks.",
            messages: []
        )
    ]

    /// Multi-Buddy Sessions list (Synchronized 1:1 with CompanionRosterStore)
    @Published public var sessions: [BuddySession] = initialSessions
    @Published public var activeSessionID: UUID = initialSessions[0].id

    /// Single Anchored Computer Workspace Payload (xAI Grok Bot Paradigm)
    @Published public var activeComputerPayload: ComputerCardPayload? = nil
    @Published public var isWorkspaceCollapsed: Bool = false

    public var activeBuddy: BuddySession {
        sessions.first(where: { $0.id == activeSessionID }) ?? (sessions.first ?? Self.initialSessions[0])
    }

    /// Synchronizes sessions directly from CompanionRosterStore
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
        guard !cleanText.isEmpty || message.computerPayload != nil else { return }
        
        // Anti-duplicate guard: ignore identical user message submitted within 2.0s
        if message.isUser, let last = chatMessages.last, last.isUser && last.text == cleanText && abs(last.timestamp.timeIntervalSince(message.timestamp)) < 2.0 {
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
            computerPayload: message.computerPayload
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

    public func updateChatMessage(id: UUID, computerPayload: ComputerCardPayload?, text: String? = nil) {
        if let payload = computerPayload {
            self.activeComputerPayload = payload
        }
        if let idx = chatMessages.firstIndex(where: { $0.id == id }) {
            if let payload = computerPayload {
                chatMessages[idx].computerPayload = payload
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
                if let newText = text {
                    sessions[sIdx].messages[mIdx].text = newText
                    sessions[sIdx].lastSnippet = newText
                }
            }
        }
        CompanionRosterStore.shared.updateMessage(id: id, computerPayload: computerPayload, text: text, forCompanionId: activeSessionID)
        objectWillChange.send()
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

    /// The currently running AI response task, if any. Cancelled when the user
    /// speaks again so a new response can begin immediately.
    private var currentResponseTask: Task<Void, Never>?

    private var shortcutTransitionCancellable: AnyCancellable?
    private var voiceStateCancellable: AnyCancellable?
    private var audioPowerCancellable: AnyCancellable?
    private var accessibilityCheckTimer: Timer?
    private var pendingKeyboardShortcutStartTask: Task<Void, Never>?
    /// Scheduled hide for transient cursor mode — cancelled if the user
    /// speaks again before the delay elapses.
    private var transientHideTask: Task<Void, Never>?

    /// True when all three required permissions (accessibility, screen recording,
    /// microphone) are granted. Used by the panel to show a single "all good" state.
    var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasScreenRecordingPermission && hasMicrophonePermission && hasScreenContentPermission
    }

    /// Whether the blue cursor overlay is currently visible on screen.
    /// Used by the panel to show accurate status text ("Active" vs "Ready").
    @Published private(set) var isOverlayVisible: Bool = false

    /// The active companion profile driving personality, skills, and dynamic cursor color
    @Published public var activeCompanion: CompanionProfile = CompanionProfile.defaultResearchBuddy

    public var currentCursorColor: Color {
        activeCompanion.cloudColor
    }

    public func setActiveCompanion(_ profile: CompanionProfile) {
        self.activeCompanion = profile
        ClickyLogger.info("[ROSTER]", "Active companion switched to \(profile.name) (\(profile.cloudColorHex))")
    }

    /// The AI model used for voice responses. Defaults to Google Gemini 3.8 Flash.
    @Published var selectedModel: String = Defaults[.selectedAIModel]

    func setSelectedModel(_ model: String) {
        selectedModel = model
        Defaults[.selectedAIModel] = model
        claudeAPI.model = model
    }

    /// User preference for whether the Clicky cursor should be shown.
    /// When toggled off, the overlay is hidden and push-to-talk is disabled.
    /// Persisted to UserDefaults so the choice survives app restarts.
    @Published var isClickyCursorEnabled: Bool = Defaults[.cursorAssistantEnabled] {
        didSet {
            Defaults[.cursorAssistantEnabled] = isClickyCursorEnabled
            UserDefaults.standard.set(isClickyCursorEnabled, forKey: "isClickyCursorEnabled")
            transientHideTask?.cancel()
            transientHideTask = nil

            ClickyLogger.info("[TOGGLE]", "isClickyCursorEnabled changed to \(isClickyCursorEnabled)")

            if isClickyCursorEnabled {
                overlayWindowManager.hasShownOverlayBefore = true
                overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                isOverlayVisible = true
            } else {
                overlayWindowManager.hideOverlay()
                isOverlayVisible = false
            }
        }
    }

    func setClickyCursorEnabled(_ enabled: Bool) {
        isClickyCursorEnabled = enabled
    }

    /// Whether the user has completed onboarding at least once. Persisted
    /// to UserDefaults so the Start button only appears on first launch.
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }

    /// Whether the user has submitted their email during onboarding.
    @Published var hasSubmittedEmail: Bool = UserDefaults.standard.bool(forKey: "hasSubmittedEmail")

    /// Submits the user's email to FormSpark and identifies them in PostHog.
    func submitEmail(_ email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }

        hasSubmittedEmail = true
        UserDefaults.standard.set(true, forKey: "hasSubmittedEmail")

        // Submit to FormSpark
        Task {
            var request = URLRequest(url: URL(string: "https://submit-form.com/RWbGJxmIs")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": trimmedEmail])
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    func start() {
        CompanionReportPresenterRegistry.shared = self
        refreshAllPermissions()
        ClickyLogger.info("[START]", "Clicky start — AX: \(hasAccessibilityPermission), Screen: \(hasScreenRecordingPermission), Mic: \(hasMicrophonePermission), Enabled: \(isClickyCursorEnabled)")
        print("🔑 Clicky start — accessibility: \(hasAccessibilityPermission), screen: \(hasScreenRecordingPermission), mic: \(hasMicrophonePermission), screenContent: \(hasScreenContentPermission), onboarded: \(hasCompletedOnboarding)")
        startPermissionPolling()
        bindVoiceStateObservation()
        bindAudioPowerLevel()
        bindShortcutTransitions()
        // Eagerly touch the Claude API so its TLS warmup handshake completes
        // well before the onboarding demo fires at ~40s into the video.
        _ = claudeAPI
        // Pre-warm Clicky sound engine buffers
        _ = ClickySoundEngine.shared

        // Synchronize sessions from Roster Store on startup
        syncSessionsFromRoster(CompanionRosterStore.shared.allCompanions, activeId: CompanionRosterStore.shared.activeCompanionId)

        // Domain-gated CUA Driver lifecycle (Milestone 199 / Opsi 2)
        // If active companion is a sandboxed VM or has connected apps, ensure host CUA daemon is STOPPED.
        // Host CUA daemon only runs when an assistant explicitly controlling the Mac host is active.
        if activeBuddy.isSandboxedVM || activeBuddy.executionDomain == .virtualSandbox {
            CuaDriverClient.shared.stopDaemon()
            ClickyLogger.info("[CUA_DRIVER]", "Active companion '\(activeBuddy.name)' is sandboxed VM; host CUA daemon stopped.")
        } else {
            CuaDriverClient.shared.warmUp()
            Task.detached(priority: .utility) {
                _ = try? await CuaDriverClient.shared.getAllNativeTools()
            }
        }
        SiriAIEngine.shared.warmUp()

        // If the user already completed onboarding AND all permissions are
        // still granted, show the cursor overlay immediately. If permissions
        // were revoked (e.g. signing change), don't show the cursor — the
        // panel will show the permissions UI instead.
        if isClickyCursorEnabled {
            overlayWindowManager.hasShownOverlayBefore = true
            overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
            isOverlayVisible = true
        } else {
            overlayWindowManager.hideOverlay()
            isOverlayVisible = false
        }
    }

    /// Called by BlueCursorView after the buddy finishes its pointing
    /// animation and returns to cursor-following mode.
    /// Triggers the onboarding sequence — dismisses the panel and restarts
    /// the overlay so the welcome animation and intro video play.
    func triggerOnboarding() {
        // Post notification so the panel manager can dismiss the panel
        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)

        // Mark onboarding as completed so the Start button won't appear
        // again on future launches — the cursor will auto-show instead
        hasCompletedOnboarding = true

        ClickyAnalytics.trackOnboardingStarted()

        // Play Besaid theme at 60% volume, fade out after 1m 30s
        startOnboardingMusic()

        // Show the overlay for the first time — isFirstAppearance triggers
        // the welcome animation and onboarding video
        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        isOverlayVisible = true
    }

    /// Replays the onboarding experience from the "Watch Onboarding Again"
    /// footer link. Same flow as triggerOnboarding but the cursor overlay
    /// is already visible so we just restart the welcome animation and video.
    func replayOnboarding() {
        NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)
        ClickyAnalytics.trackOnboardingReplayed()
        startOnboardingMusic()
        // Tear down any existing overlays and recreate with isFirstAppearance = true
        overlayWindowManager.hasShownOverlayBefore = false
        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
        isOverlayVisible = true
    }

    private func stopOnboardingMusic() {
        onboardingMusicFadeTimer?.invalidate()
        onboardingMusicFadeTimer = nil
        onboardingMusicPlayer?.stop()
        onboardingMusicPlayer = nil
    }

    private func startOnboardingMusic() {
        stopOnboardingMusic()
        guard let musicURL = Bundle.main.url(forResource: "ff", withExtension: "mp3") else {
            print("⚠️ Clicky: ff.mp3 not found in bundle")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: musicURL)
            player.volume = 0.3
            player.play()
            self.onboardingMusicPlayer = player

            // After 1m 30s, fade the music out over 3s
            onboardingMusicFadeTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: false) { [weak self] _ in
                self?.fadeOutOnboardingMusic()
            }
        } catch {
            print("⚠️ Clicky: Failed to play onboarding music: \(error)")
        }
    }

    private func fadeOutOnboardingMusic() {
        guard let player = onboardingMusicPlayer else { return }

        let fadeSteps = 30
        let fadeDuration: Double = 3.0
        let stepInterval = fadeDuration / Double(fadeSteps)
        let volumeDecrement = player.volume / Float(fadeSteps)
        var stepsRemaining = fadeSteps

        onboardingMusicFadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            stepsRemaining -= 1
            player.volume -= volumeDecrement

            if stepsRemaining <= 0 {
                timer.invalidate()
                player.stop()
                self?.onboardingMusicPlayer = nil
                self?.onboardingMusicFadeTimer = nil
            }
        }
    }

    func clearDetectedElementLocation() {
        flightWatchdogWorkItem?.cancel()
        flightWatchdogWorkItem = nil
        flownTargetExpression = nil
        grounderEarlyExpression = nil
        detectedElementScreenLocation = nil
        detectedElementDisplayFrame = nil
        detectedElementBubbleText = nil
        detectedElementLabel = nil
        detectedElementTargetRadius = 35.0
        hasTriggeredStreamingFlight = false
        accumulatedRawStreamingText = ""
    }

    /// Handles Escape key press (kVK_Escape) to cancel all active actions and return cursor
    func handleEscapePressed() {
        ClickyLogger.info("[SHORTCUT]", "Escape pressed — aborting active flight and companion actions")
        ClickySoundEngine.shared.play(.close)
        elevenLabsTTSClient.stopPlayback()
        grounderTask?.cancel()
        grounderTask = nil
        currentResponseTask?.cancel()
        currentResponseTask = nil
        hideResponseBubbleImmediately()
        clearDetectedElementLocation()
        voiceState = .idle
        isTaskSessionPreApproved = false
        ongoingTaskGoal = nil
        isShowingStreamingResponse = false
        streamingResponseText = ""
        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
        // Cleanly stop any active streaming and dismantle virtual display
        CompanionWindowStreamService.shared.stopStreaming()
        MascotVirtualDesktopService.shared.stopVirtualDesktop()

        // F-22: Close HomeSpace if visible when Escape is pressed
        if let host = CompanionUIHostRegistry.shared {
            if host.isHomeSpaceVisible { host.hideHomeSpace() }
        } else if HomeSpaceWindowManager.shared.isVisible {
            HomeSpaceWindowManager.shared.hide()
        }
    }

    func stop() {
        globalPushToTalkShortcutMonitor.stop()
        buddyDictationManager.cancelCurrentDictation()
        overlayWindowManager.hideOverlay()
        transientHideTask?.cancel()

        currentResponseTask?.cancel()
        currentResponseTask = nil
        shortcutTransitionCancellable?.cancel()
        voiceStateCancellable?.cancel()
        audioPowerCancellable?.cancel()
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
    }

    func refreshAllPermissions() {
        let previouslyHadAccessibility = hasAccessibilityPermission
        let previouslyHadScreenRecording = hasScreenRecordingPermission
        let previouslyHadMicrophone = hasMicrophonePermission
        let previouslyHadSpeech = hasSpeechRecognitionPermission
        let previouslyHadAll = allPermissionsGranted

        let currentlyHasAccessibility = WindowPositionManager.hasAccessibilityPermission()
        hasAccessibilityPermission = currentlyHasAccessibility

        // Keep shortcut monitor running so push-to-talk via global NSEvent monitor and CGEvent tap work
        globalPushToTalkShortcutMonitor.start()

        hasScreenRecordingPermission = WindowPositionManager.shouldTreatScreenRecordingPermissionAsGrantedForSessionLaunch() || hasScreenContentPermission

        let micAuthStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        hasMicrophonePermission = micAuthStatus == .authorized

        let speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        hasSpeechRecognitionPermission = speechAuthStatus == .authorized

        // Debug: log permission state on changes
        if previouslyHadAccessibility != hasAccessibilityPermission
            || previouslyHadScreenRecording != hasScreenRecordingPermission
            || previouslyHadMicrophone != hasMicrophonePermission
            || previouslyHadSpeech != hasSpeechRecognitionPermission {
            ClickyLogger.info("[PERMISSIONS]", "Permissions updated — AX: \(hasAccessibilityPermission), Screen: \(hasScreenRecordingPermission), Mic: \(hasMicrophonePermission), Speech: \(hasSpeechRecognitionPermission)")
        }

        // Track individual permission grants as they happen
        if !previouslyHadAccessibility && hasAccessibilityPermission {
            ClickyAnalytics.trackPermissionGranted(permission: "accessibility")
        }
        if !previouslyHadScreenRecording && hasScreenRecordingPermission {
            ClickyAnalytics.trackPermissionGranted(permission: "screen_recording")
        }
        if !previouslyHadMicrophone && hasMicrophonePermission {
            ClickyAnalytics.trackPermissionGranted(permission: "microphone")
        }
        if !previouslyHadSpeech && hasSpeechRecognitionPermission {
            ClickyAnalytics.trackPermissionGranted(permission: "speech_recognition")
        }
        // Screen content permission is persisted — once the user has approved the
        // SCShareableContent picker, we don't need to re-check it.
        if !hasScreenContentPermission {
            hasScreenContentPermission = UserDefaults.standard.bool(forKey: "hasScreenContentPermission")
        }

        if !previouslyHadAll && allPermissionsGranted {
            ClickyAnalytics.trackAllPermissionsGranted()
        }
    }

    /// Triggers the macOS screen content picker by performing a dummy
    /// screenshot capture. Once the user approves, we persist the grant
    /// so they're never asked again during onboarding.
    @Published private(set) var isRequestingScreenContent = false

    func requestScreenContentPermission() {
        guard !isRequestingScreenContent else { return }
        isRequestingScreenContent = true
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else {
                    await MainActor.run { isRequestingScreenContent = false }
                    return
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = 320
                config.height = 240
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                // Verify the capture actually returned real content — a 0x0 or
                // fully-empty image means the user denied the prompt.
                let didCapture = image.width > 0 && image.height > 0
                print("🔑 Screen content capture result — width: \(image.width), height: \(image.height), didCapture: \(didCapture)")
                await MainActor.run {
                    isRequestingScreenContent = false
                    guard didCapture else { return }
                    hasScreenContentPermission = true
                    UserDefaults.standard.set(true, forKey: "hasScreenContentPermission")
                    ClickyAnalytics.trackPermissionGranted(permission: "screen_content")

                    // If onboarding was already completed, show the cursor overlay now
                    if hasCompletedOnboarding && allPermissionsGranted && !isOverlayVisible && isClickyCursorEnabled {
                        overlayWindowManager.hasShownOverlayBefore = true
                        overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                        isOverlayVisible = true
                    }
                }
            } catch {
                print("⚠️ Screen content permission request failed: \(error)")
                await MainActor.run { isRequestingScreenContent = false }
            }
        }
    }

    // MARK: - Private

    /// Triggers the system microphone prompt if undetermined, or opens settings if denied.
    func requestMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.hasMicrophonePermission = granted
                }
            }
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Triggers the system speech recognition prompt if undetermined, or opens settings if denied.
    func requestSpeechRecognitionPermission() {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
                Task { @MainActor [weak self] in
                    self?.hasSpeechRecognitionPermission = authStatus == .authorized
                }
            }
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func promptForMicrophoneIfNotDetermined() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor [weak self] in
                self?.hasMicrophonePermission = granted
            }
        }
    }

    /// Polls all permissions frequently so the UI updates live after the
    /// user grants them in System Settings. Screen Recording is the exception —
    /// macOS requires an app restart for that one to take effect.
    private func startPermissionPolling() {
        accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshAllPermissions()
            }
        }
    }

    private func bindAudioPowerLevel() {
        audioPowerCancellable = buddyDictationManager.$currentAudioPowerLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] powerLevel in
                self?.currentAudioPowerLevel = powerLevel
            }
    }

    private func bindVoiceStateObservation() {
        voiceStateCancellable = buddyDictationManager.$isRecordingFromKeyboardShortcut
            .combineLatest(
                buddyDictationManager.$isFinalizingTranscript,
                buddyDictationManager.$isPreparingToRecord
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, isFinalizing, isPreparing in
                guard let self else { return }
                // Don't override .responding — the AI response pipeline
                // manages that state directly until streaming finishes.
                guard self.voiceState != .responding else { return }

                if isFinalizing {
                    self.voiceState = .processing
                } else if isRecording {
                    self.voiceState = .listening
                } else if isPreparing {
                    self.voiceState = .processing
                } else {
                    self.voiceState = .idle
                    // If the user pressed and released the hotkey without
                    // saying anything, no response task runs — schedule the
                    // transient hide here so the overlay doesn't get stuck.
                    // Only do this when no response is in flight, otherwise
                    // the brief idle gap between recording and processing
                    // would prematurely hide the overlay.
                    if self.currentResponseTask == nil {
                        self.scheduleTransientHideIfNeeded()
                    }
                }
            }
    }

    private func bindShortcutTransitions() {
        globalPushToTalkShortcutMonitor.onEscapePressed = { [weak self] in
            self?.handleEscapePressed()
        }
        shortcutTransitionCancellable = globalPushToTalkShortcutMonitor
            .shortcutTransitionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transition in
                self?.handleShortcutTransition(transition)
            }
    }

    private func handleShortcutTransition(_ transition: BuddyPushToTalkShortcut.ShortcutTransition) {
        ClickyLogger.info("[SHORTCUT]", "Shortcut event: \(transition) (voiceEnabled: \(Defaults[.cursorAssistantVoiceEnabled]))")
        switch transition {
        case .pressed:
            guard Defaults[.cursorAssistantVoiceEnabled] else { return }
            guard !buddyDictationManager.isDictationInProgress else { return }
            // Don't register push-to-talk while the onboarding video is playing
            guard !showOnboardingVideo else { return }

            ClickySoundEngine.shared.play(.open)

            // Cancel any pending transient hide so the overlay stays visible
            transientHideTask?.cancel()
            transientHideTask = nil

            // If the cursor is hidden, bring it back transiently for this interaction
            if !isClickyCursorEnabled && !isOverlayVisible {
                overlayWindowManager.hasShownOverlayBefore = true
                overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                isOverlayVisible = true
            }

            // Dismiss the menu bar panel so it doesn't cover the screen
            NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)

            // Cancel any in-progress response and TTS from a previous utterance
            currentResponseTask?.cancel()
            elevenLabsTTSClient.stopPlayback()
            clearDetectedElementLocation()
            hideResponseBubbleImmediately()

            // Dismiss the onboarding prompt if it's showing
            if showOnboardingPrompt {
                withAnimation(.easeOut(duration: 0.3)) {
                    onboardingPromptOpacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    self.showOnboardingPrompt = false
                    self.onboardingPromptText = ""
                }
            }
    

            ClickyAnalytics.trackPushToTalkStarted()

            pendingKeyboardShortcutStartTask?.cancel()
            pendingKeyboardShortcutStartTask = Task {
                await buddyDictationManager.startPushToTalkFromKeyboardShortcut(
                    currentDraftText: "",
                    updateDraftText: { _ in
                        // Partial transcripts are hidden (waveform-only UI)
                    },
                    submitDraftText: { [weak self] finalTranscript in
                        self?.lastTranscript = finalTranscript
                        print("🗣️ Companion received transcript: \(finalTranscript)")
                        ClickyAnalytics.trackUserMessageSent(transcript: finalTranscript)
                        self?.sendTranscriptToClaudeWithScreenshot(transcript: finalTranscript)
                    }
                )
            }
        case .released:
            // Cancel the pending start task in case the user released the shortcut
            // before the async startPushToTalk had a chance to begin recording.
            // Without this, a quick press-and-release drops the release event and
            // leaves the waveform overlay stuck on screen indefinitely.
            ClickyAnalytics.trackPushToTalkReleased()
            pendingKeyboardShortcutStartTask?.cancel()
            pendingKeyboardShortcutStartTask = nil
            buddyDictationManager.stopPushToTalkFromKeyboardShortcut()
        case .none:
            break
        }
    }

    // MARK: - Companion Prompt

    static func buildCompanionVoiceResponseSystemPrompt(workSurface: ActiveWorkSurface? = nil, buddy: BuddySession? = nil, isPreApproved: Bool = false, isSiriAIPlannerPath: Bool = false) -> String {
        let currentTime = Date().formatted(date: .complete, time: .shortened)
        var activeWindowContext = ""
        if let ws = workSurface {
            activeWindowContext = """

            active frontmost application window context:
            - application: "\(ws.appName)"
            - window title: "\(ws.windowTitle)"
            - window bounds on screen: origin (x=\(Int(ws.frame.origin.x)), y=\(Int(ws.frame.origin.y))), size (width=\(Int(ws.frame.width)), height=\(Int(ws.frame.height)))
            - window center coordinate: (x=\(Int(ws.windowCenter.x)), y=\(Int(ws.windowCenter.y)))
            - macOS traffic light window controls (use ONLY if the user explicitly asks to close, minimize, or zoom this window; describe them in words, e.g. "red close button in the top-left corner of the frontmost window"):
              • close button (red)
              • minimize button (yellow)
              • zoom/fullscreen button (green)
            NOTE: if pointing to this window or its controls, ensure your expression names this window, NOT background applications behind or beside it!
            """
            if buddy?.executionDomain == .virtualSandbox {
                activeWindowContext += """

                ISOLATED WORKSPACE INVARIANT:
                The frontmost window above is the user's host application. You operate inside an isolated workspace. NEVER ask the user to bring your connected workspace apps (Mail, Safari, etc.) to the front or make them visible!
                """
            }
        }

        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { $0.localizedName }
            .joined(separator: ", ")

        // Scale Dock screen-point coordinates (display space, e.g. 1512x982) to
        // screenshot pixel space (1280x800) for SoM synthetic mark boxes.
        // Raw per-icon coordinates are NO LONGER injected into the prompt (diet:
        // on-device context is small — TN3193; the numbered legend carries ids).
        let screenshotW: CGFloat = 1280.0
        let screenshotH: CGFloat = 800.0
        let displayW = CGFloat(NSScreen.main?.frame.width ?? 1512)
        let displayH = CGFloat(NSScreen.main?.frame.height ?? 982)
        _ = (screenshotW, screenshotH, displayW, displayH)

        let runningAppsContext = """

        pointing contract (planner-grounder split, Opsi D Fase 2):
        The system grounds targets — you NEVER output numbers or coordinates.
        To point, reply with EXACTLY ONE line at the very beginning of your response:
        TARGET: <compact English referring expression, max ~12 words: object + strong visual cue + short position>
        Example: "TARGET: blue outlined text field at bottom".
        Then write one natural spoken sentence for TTS on the next line.
        FORBIDDEN in your output: [POINT:...], [BOX:...], [TARGET:...:...], [CANDIDATE:...], any x/y numbers, any numbered-mark ids.
        There are NO numbered marks on the screenshot. NEVER invent bracket tags.
        (Legacy bracket tags are parsed passively for old logs/debug only.)
        If pointing wouldn't help or is irrelevant, do NOT include any TARGET line.

        running GUI applications on this Mac:
        \(runningApps.isEmpty ? "none detected" : runningApps)

        macOS visual layout landmarks (for describing positions in words, NOT numbers):
        - Top Menu Bar & Notch: top edge of the screen.
        - Desktop Workspace: middle area.
        - Bottom Dock Icons: app icons along the bottom edge.
        """

        var companionIdentityContext = ""
        var hasLoadedSpec = false
        if let b = buddy {
            // Resolve companion slug and load corresponding markdown specification from ~/.izanotchy/companions/<slug>/persona.md
            let slug = CompanionRosterStore.shared.allCompanions.first(where: { $0.id == b.id })?.slug
                       ?? b.name.lowercased().replacingOccurrences(of: " ", with: "-")

            let loadedSpec = CompanionWorkspaceManager.shared.readCompanionSpec(slug: slug)

            companionIdentityContext = """

            active companion profile:
            - companion name: "\(b.name)"
            - companion role: "\(b.roleDescription)"
            - companion slug: "\(slug)"
            - execution domain: "\(b.executionDomain.rawValue)"
            """

            if let spec = loadedSpec, !spec.isEmpty {
                hasLoadedSpec = true
                companionIdentityContext += """

                OFFICIAL COMPANION SPECIFICATION MARKDOWN (persona.md):
                \"\"\"
                \(spec)
                \"\"\"
                MANDATORY COMPANION DIRECTIVE:
                You MUST strictly follow the Primary Goal, Core Capabilities, Standing Rules, and Output Formatting specified in your persona.md above! You are sovereign to this specification and must NEVER drift outside your assigned role.
                """
                ClickyLogger.info("[COMPANION_MD]", "Injected live markdown spec persona.md for \(slug) (\(spec.count) chars)")
            }

            if b.executionDomain == .virtualSandbox {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let deliverablesDir = "\(home)/.izanotchy/companions/\(slug)/workspace/deliverables"
                var latestDeliverableContext = ""
                if let files = try? FileManager.default.contentsOfDirectory(atPath: deliverablesDir) {
                    let jsonFiles = files.filter { $0.hasSuffix(".json") }
                    let sorted = jsonFiles.compactMap { file -> (String, Date)? in
                        let p = "\(deliverablesDir)/\(file)"
                        let attrs = try? FileManager.default.attributesOfItem(atPath: p)
                        let mod = attrs?[.modificationDate] as? Date ?? Date.distantPast
                        return (p, mod)
                    }.sorted { $0.1 > $1.1 }

                    if let newest = sorted.first,
                       let data = try? Data(contentsOf: URL(fileURLWithPath: newest.0)),
                       let receipt = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let summary = receipt["summary"] as? String ?? ""
                        var obsList: [String] = []
                        if let audit = receipt["auditTrail"] as? [[String: Any]] {
                            for step in audit {
                                if let obs = step["observationResult"] as? String, !obs.isEmpty {
                                    obsList.append(obs)
                                }
                            }
                        }
                        latestDeliverableContext = """

                        LATEST AUTONOMOUS TASK DELIVERABLE & OBSERVATION:
                        - Task: "\(receipt["taskPrompt"] as? String ?? "")"
                        - Summary: "\(summary)"
                        - Live Observations:
                          \(obsList.joined(separator: "\n  "))
                        """
                    }
                }

                companionIdentityContext += """

                EXECUTION DOMAIN — VIRTUAL SANDBOX (VM):
                You operate inside your dedicated virtual workspace/sandbox:
                - Path: ~/.izanotchy/companions/\(slug)/workspace/
                - Deliverables: ~/.izanotchy/companions/\(slug)/workspace/deliverables/
                - Browser Data: ~/.izanotchy/companions/\(slug)/browser_data/
                - Standing Rule: You are an autonomous agent living in your own virtual device. You MUST NEVER open host desktop applications, disrupt the user's host Mac screen, or ask the user to bring applications to the front.
                - When the user asks about recent actions, data, application status, or observations, answer DIRECTLY using your latest deliverable and live observations below! Do not claim applications are in the background or invisible.
                \(latestDeliverableContext)
                """
            }

            let isFuturesScout = b.name.localizedCaseInsensitiveContains("Futures") ||
                                 b.roleDescription.localizedCaseInsensitiveContains("Futures") ||
                                 b.roleDescription.localizedCaseInsensitiveContains("Analyst") ||
                                 b.roleDescription.localizedCaseInsensitiveContains("Trading")
            if isFuturesScout {
                companionIdentityContext += """

                SPECIALIZATION — FUTURES ANALYST & TRADINGVIEW EXPERT:
                You are an elite crypto & futures technical analyst. You specialize in Price Action, Smart Money Concepts (SMC), Order Blocks, Liquidity Sweeps, Fair Value Gaps (FVG), Support & Resistance, Trendlines, and Fibonacci Retracements.
                - When the user asks you about charts, prices, trading, or TradingView, analyze the chart seen in the screenshot thoroughly.
                - You have full autonomous native tools to inspect, open, and control TradingView (e.g. launch_app, get_window_state, click, hotkey, type_text).
                - When inspecting charts, observe the real visual candlestick data. If TradingView displays an error, invalid symbol modal, or "This symbol doesn't exist", say the blocker honestly instead of pretending it succeeded!
                """
            }
        }

        let formattingDirective = hasLoadedSpec ? """
        - format your response strictly according to your companion specification markdown above! start with 1-2 spoken summary sentences for TTS, followed by the structured tables, sections, or technical parameters required by your role.
        - always use numeric digits for numbers (e.g. write "10", "5", "100" instead of spelling them out as words).
        """ : """
        - default to one or two sentences. be direct, dense, casual, warm, all lowercase. no emojis.
        - write for the ear, not the eye. short sentences. no lists, bullet points, markdown, or formatting — just natural speech.
        - don't use abbreviations or symbols that sound weird read aloud. write "for example" not "e.g.", always use numeric digits for numbers (e.g. write "10", "5", "100" instead of spelling them out as words like "sepuluh" or "ten").
        - LANGUAGE MIRROR (Hotfix #8): reply in the SAME language the user used. If the user speaks Indonesian, reply in Indonesian (casual, lowercase). If the user speaks English, reply in English. The TARGET: line is always English (for the grounder), but your spoken sentence mirrors the user.
        """

        return """
        you're clicky, a friendly always-on companion that lives next to the user's cursor.
        Izanotchy handles microphone input, screenshots, onboarding, the floating HUD, and spoken summaries.
        You handle reasoning, tools, concise commentary, and the final answer.

        SOVEREIGNTY & CONTEXT INVARIANTS (ClickyModelInstructions.md):
        1. SCREENSHOTS ARE CONTEXT, NOT ROUTE SELECTION:
           - Seeing an app (such as TradingView, WhatsApp, Slack, Notes, Safari) on screen does NOT mean the user asked for visible UI control or automation!
           - If the user merely says "Hai", "Halo", or asks a casual question, reply warmly with natural speech. Do NOT launch apps, type tickers, or perform GUI actions unless the user explicitly requested it!
        2. THE SNAPSHOT-ACT-VERIFY INVARIANT:
           - For GUI automation tasks: inspect the window state first, act via native tools, and verify the effect via a new snapshot.
           - If an action fails, if a modal blocks the screen, or if a symbol doesn't exist: SAY THE BLOCKER HONESTLY instead of pretending it ran. Never hallucinate completion or copy canned scripts!
        3. NO-FOREGROUND CONTRACT:
           - Keep work backgrounded whenever possible so the user can continue typing without focus stealing.

        current local date and time: \(currentTime).\(activeWindowContext)\(runningAppsContext)\(companionIdentityContext)

        rules:
        \(formattingDirective)
        - if the user's question relates to what's on their screen, reference specific things you see.
        - if the screenshot doesn't seem relevant to their question, just answer the question directly.
        - you can help with anything — coding, writing, finding files, UI navigation, general knowledge.
        - never say "simply" or "just".
        - don't read out code verbatim. describe what the code does or what needs to change conversationally.
        - if you receive multiple screen images, the one labeled "primary focus" is where the cursor is — prioritize that one.

        element pointing & navigation (TARGET-FIRST FORMAT, Opsi D Fase 2):
        you have a small blue triangle cursor that can fly to and point at things on screen. use it whenever the user asks where something is, how to do something, looking for a menu, button, icon, or navigating an app.
        CRITICAL: when pointing at an element, put the TARGET line FIRST at the very beginning of your response:
        TARGET: <compact English referring expression, max ~12 words>
        followed by your natural spoken sentence on the next line.
        - pattern: <object> + <strong visual cue> + <short position>. compact beats poetic.
        - GOOD (compact, grounded): "WhatsApp icon in the Dock", "red close button top-left", "blue outlined text field at bottom".
        - BAD (layered clauses, grounder gives up): "text box with blue border and white background in the lower-left corner of the window".
        - name the app/window ONLY if needed to disambiguate (e.g. two similar windows).
        - NEVER invent a target that is not clearly visible in the screenshot. If the requested thing is not on screen, do NOT emit any TARGET line — say so in your spoken sentence instead.
        - NEVER guess a position the user did not mention. If the user says "mana text box" without a position, describe ONLY the object ("blue outlined text field") — do NOT append "at bottom/top/left" from imagination. A wrong guessed position misleads the grounder; no position lets it search the whole screen.
        - examples:
        - When asked where WhatsApp is: "TARGET: WhatsApp icon in the Dock".
        - When asked where an open window is: "TARGET: Antigravity browser window center".
        - When explicitly asked to close a window: "TARGET: red close button top-left".
        if pointing wouldn't help or is irrelevant, do NOT include any TARGET line.
        CRITICAL: NEVER include any TARGET line for casual greetings (e.g. "Halo", "Hai", "Apa kabar"), general chit-chat, code explanations, or general Q&A!
        NEVER tell the user to close a window unless the user specifically and explicitly asked to close/quit it!
        \(Self.buildComputerUsePrompt(isPreApproved: isPreApproved, isSiriAIPlannerPath: isSiriAIPlannerPath))
        """
    }

    private static func buildComputerUsePrompt(isPreApproved: Bool = false, isSiriAIPlannerPath: Bool = false) -> String {
        // Opsi D Fase 2 diet: path Siri (isSiriAI) adalah planner-only — SiriAIEngine
        // tidak pernah mengirim tools (toolCalls selalu []). Blok 56-tools +
        // tvActions (~90 baris) hanya membebani konteks on-device (TN3193).
        // Autonomous loop (Futures/TradingView) TIDAK tersentuh: ia memanggil
        // fungsi ini langsung dengan isPreApproved=true via jalurnya sendiri.
        if isSiriAIPlannerPath {
            return """

            planner-only mode (on-device, no tools):
            You cannot call any tools. Your ONLY pointing output is the TARGET: line
            defined above. Describe targets in words; the system grounds them.
            """
        }
        let isFullAccess = Defaults[.alwaysAllowComputerUse] || isPreApproved
        let tvActionsDesc = """
        TradingView Automation Actions (Zero Tool Limitation):
        You have direct autonomous control over TradingView.app via the following specialized tags:
        - Auto-Fit / Reset Price Scale: [ACTION:tv_reset_scale] (instantly un-squashes candles so chart is full-height and readable via ⌥+R)
        - Close Popups / Dismiss Modals: [ACTION:tv_close_modal] (safely dismisses blocking popups/search dialogs via synthetic escape)
        - Switch Timeframe: [ACTION:tv_timeframe:<tf>] (e.g. [ACTION:tv_timeframe:15], [ACTION:tv_timeframe:60], [ACTION:tv_timeframe:240], [ACTION:tv_timeframe:1D])
        - Switch Symbol: [ACTION:tv_symbol:<symbol>] (e.g. [ACTION:tv_symbol:BTCUSDT], [ACTION:tv_symbol:ETHUSDT])
        - Universal & Native Hotkey Drawing Tools: [ACTION:tv_tool:<ToolName>:<points>]
          Supported tools:
          • "Horizontal Line": places line instantly at target price point via native ⌥+H without opening any modal (e.g. [ACTION:tv_tool:Horizontal Line:500,450])
          • "Horizontal Ray": places ray instantly via native ⌥+J (e.g. [ACTION:tv_tool:Horizontal Ray:500,450])
          • "Trend Line": draws line between two points via native ⌥+T (e.g. [ACTION:tv_tool:Trend Line:250,600|650,300])
          • "Fib Retracement": draws fib retracement via native ⌥+F (e.g. [ACTION:tv_tool:Fib Retracement:250,650|750,200])
          • "Rectangle", "Long Position", "Short Position", "Parallel Channel": selected and drawn at canvas points.
        - Add Technical Indicator: [ACTION:tv_indicator:<name>] (e.g. [ACTION:tv_indicator:Relative Strength Index], [ACTION:tv_indicator:Bollinger Bands])
        - Dynamic Pine Script v5 (Tier 4 Compiler & Auto-Injector): [ACTION:tv_pine:<pinescript_code>]
          Use this to inject full Pine Script v5 code (overlay=true) via Pine Editor to plot mathematically precise levels, order blocks, or custom strategies directly onto the chart!
        - Clear Chart Drawings: [ACTION:tv_clear:all:clear drawings]
        """

        let universalDirectives = """
        ⚠️ CRITICAL CUA-DRIVER RULES — Read these FIRST before any action:
        1. EVERY input tool call (click, type_text, hotkey, scroll, set_value, press_key) MUST include `delivery_mode: "background"`.
        2. NEVER use `scope: "desktop"` for clicks — this warps the user's real cursor. 
           Instead, use WINDOW-SCOPED clicks: click({pid: <pid>, window_id: <window_id>, x: <x>, y: <y>, delivery_mode: "background"})
           where x,y are pixel coordinates measured from the TOP-LEFT corner of the window screenshot from get_window_state or get_desktop_state.
        3. ALWAYS start a computer use task with `get_desktop_state()` to see the full current screen.
        4. For TradingView (Electron app): AX tree is always empty. Use `get_desktop_state()` for screenshots. Get its PID via `list_apps()`, window_id via `list_windows(pid)`. Then use window-scoped pixel clicks.
        5. Observation tools (get_desktop_state, get_window_state, list_apps, list_windows, list_windows, check_permissions) are always safe to call without consent.
        
        Universal Obstacle Self-Healing & Missing Tool Awareness:
        1. If ANY unexpected popup, modal, or dialog blocks your view (e.g. "Search tool", "Trade with..."):
           - Click its physical '✕' button using window-scoped click OR use [ACTION:tv_close_modal].
        2. If you lack a tool/capability needed to fulfill the request, NEVER hallucinate:
           - Output: [REQUEST_FEATURE:<FeatureName>:<Reason>]
           - Explain in English: "This feature is not available yet. I need the <FeatureName> capability (<Reason>) to complete this task."
        """

        let isCuaAvailable = CuaDriverClient.shared.isAvailable
        let cuaInstruction = isCuaAvailable ? """

        NATIVE MACOS COMPUTER-USE AUTOMATION (POWERED BY CUA DRIVER):
        You are equipped with 56 native desktop automation tools from Cua Driver.
        When the user asks you to interact with an application (e.g. close/quit Safari, Terminal, Chrome, click on UI, type, inspect windows):
        ALWAYS INVOKE NATIVE TOOLS DIRECTLY. Do NOT output raw text action tags like [ACTION:...] or <COMPUTER_USE_REQUEST> blocks.

        1. APP TERMINATION & CLOSING (SMART HYBRID CONTRACT — OPTION 3):
          - Step 1: Call `list_apps` to locate the target application and obtain its PID.
          - Step 2: Call `list_windows(pid: <pid>)` to check if the target app has an on-screen window on the active display.
          - Step 3 (SMART HYBRID EXECUTION):
            * ROUTE A (ON-SCREEN VISIBLE WINDOW): If `list_windows` returns a window with `is_on_screen: true` and valid `bounds`:
              - Compute the macOS red close button coordinate: (bounds.origin.x + 14, bounds.origin.y + 14).
              - Call `move_cursor(x: bounds.origin.x + 14, y: bounds.origin.y + 14)` so the agent cursor glides directly to the close button, then call `click(pid: <pid>, x: 14, y: 14, delivery_mode: "foreground", window_id: <wid>)` or `kill_app(pid: <pid>)`.
            * ROUTE B (BACKGROUND / MINIMIZED / NO VISIBLE WINDOW):
              - Do NOT call `move_cursor`! NEVER move the cursor to the screen center (e.g. 640, 400)!
              - Call `kill_app(pid: <pid>)` immediately and deterministically.
          - Step 4: After closing the app, provide a brief 1-sentence confirmation (e.g. "Terminal berhasil saya tutup.").
          - ZERO POINTLESS MOVEMENTS RULE: NEVER call `move_cursor` to the center of the screen (e.g. 640, 400 or 756, 491) or into empty space! Only move the cursor when pointing at a real, concrete UI element (like a close button, menu, or drawing canvas).

        2. CLICKING, DRAWING & INTERACTING (PHYSICAL CUA DRIVER ACTIONS):
          - For UI interactions or drawing tasks (like AutoDraw), call `move_cursor` or `drag` with the real, concrete coordinates on screen.
          - Call `list_windows` or `get_window_state` to obtain accurate coordinates or element tokens.

        3. CONCISE STATUS (HEYCLICKY CONTRACT):
          - When invoking tools, keep intermediate conversational text under 15 words so the floating status card next to the cursor remains sleek and readable.
        """ : ""

        if isFullAccess {
            return """
            \(cuaInstruction)

            computer use & physical mac automation (FULL ACCESS MODE - PRE-APPROVED):
            IMPORTANT: The user has enabled "Always allow computer use" (Full Access).
            When the user asks you to interact with an application (e.g. Safari, Terminal, TradingView, WhatsApp, Notes, Finder):
            Execute the action immediately using your native tools without asking for confirmation.
            \(tvActionsDesc)
            \(universalDirectives)
            """
        } else {
            return """
            \(cuaInstruction)

            computer use & physical mac automation (ASK MODE - CONSENT REQUIRED):
            IMPORTANT: ACTING ON THE USER'S SCREEN REQUIRES EXPLICIT CONSENT.
            When the user asks you to interact with an application on their screen to click, type, or quit apps:
            If you need confirmation, briefly explain what you will do on their screen in 1 natural sentence and call the tool.
            \(tvActionsDesc)
            \(universalDirectives)
            """
        }
    }

    // MARK: - Streaming Response Bubble Control

    // MARK: - Cursor Assistant Text Condensation (HeyClicky HUD Pill)

    /// Condenses long responses for the floating cursor HUD so that it displays a compact, sleek status pill (HeyClicky HUD)
    /// while the full multi-paragraph response is preserved in the HomeSpace chat thread.
    static func condenseForCursorHUD(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        // Strip markdown tokens like **, ##, backticks
        let clean = trimmed
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Take the first non-empty line
        let firstLine = clean.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? clean

        // If line is short and concise, return it directly
        if firstLine.count <= 85 {
            return firstLine
        }

        // Check if there is a complete sentence within the first line under 85 chars
        if let match = firstLine.range(of: #"[.!?]"#, options: .regularExpression) {
            let sentence = String(firstLine[..<match.upperBound]).trimmingCharacters(in: .whitespaces)
            if sentence.count <= 85 && sentence.count >= 10 {
                return sentence
            }
        }

        // Otherwise, truncate cleanly at word boundary around 75 characters
        let prefix = String(firstLine.prefix(75))
        if let lastSpace = prefix.lastIndex(of: " ") {
            return "\(prefix[..<lastSpace])..."
        }
        return "\(prefix)..."
    }

    /// Arms a self-healing watchdog to ensure detectedElementScreenLocation never traps the cursor in an invisible state
    private func armFlightWatchdog(timeout: TimeInterval = 9.0) {
        flightWatchdogWorkItem?.cancel()
        let watchdog = DispatchWorkItem { [weak self] in
            guard let self = self, self.detectedElementScreenLocation != nil else { return }
            ClickyLogger.warning("[WATCHDOG]", "Flight watchdog auto-cleared detectedElementScreenLocation after \(timeout)s timeout")
            self.clearDetectedElementLocation()
            NotificationCenter.default.post(name: .clickyAbortFlight, object: nil)
        }
        self.flightWatchdogWorkItem = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: watchdog)
    }

    /// Public entrypoint to trigger visual element flight to an exact Cocoa screen coordinate (AppKit origin bottom-left)
    public func triggerVisualElementFlight(
        appKitScreenPoint: CGPoint,
        targetRadius: CGFloat = 24.0,
        elementLabel: String? = nil
    ) {
        voiceState = .idle
        detectedElementLabel = elementLabel
        if let label = elementLabel, !label.isEmpty {
            detectedElementBubbleText = "\(label) right here!"
        }
        // Opsi user hold-sejak-awal: AX-HIT = prediksi salah, grounder tak perlu.
        // Lepas hold SEGERA + tampilkan teks yang ditahan (jangan diam sia-sia).
        if groundingHoldActive {
            groundingHoldActive = false
            homeSpaceStreamingText = Self.stripTechnicalTags(from: Self.stripPointingTags(from: accumulatedRawStreamingText))
            isHomeSpaceStreaming = !homeSpaceStreamingText.isEmpty
            streamingResponseText = Self.condenseForCursorHUD(homeSpaceStreamingText)
            ClickyLogger.info("[SYNC]", "hold released at AX-hit — no grounder needed")
        }
        // Fase 4-1 (2026-09-22): tolak kandidat off-screen. Fakta: AX Dock lapor
        // Y goyang (907 vs 987) antar sesi; titik di luar bounds layar (mis. -40)
        // bila diterbangkan = mendarat di luar visual. Jangan flight — tandai miss
        // agar correction/grounder yang tangani, bukan ngarang ke tepi layar.
        let onAnyScreen = NSScreen.screens.contains(where: { $0.frame.contains(appKitScreenPoint) })
        guard onAnyScreen else {
            ClickyLogger.warning("[POINTING]", "rejected off-screen candidate (\(Int(appKitScreenPoint.x)), \(Int(appKitScreenPoint.y))) — no flight")
            markGroundingMiss()
            return
        }
        // Plan sinkron-teks S2: flight mulai -> bubble ditegakkan (jangan hide
        // saat cursor terbang). Reveal kata jalan paralel busur animasi.
        // Opsi user 22 Sep: lepas hold + tampilkan teks BERSAMAAN dengan flight.
        responseBubbleHideWorkItem?.cancel()
        if groundingHoldActive {
            groundingHoldActive = false
            homeSpaceStreamingText = Self.stripTechnicalTags(from: Self.stripPointingTags(from: accumulatedRawStreamingText))
            isHomeSpaceStreaming = !homeSpaceStreamingText.isEmpty
            streamingResponseText = Self.condenseForCursorHUD(homeSpaceStreamingText)
            ClickyLogger.info("[SYNC]", "hold released at flight — text+animation together")
        }
        isShowingStreamingResponse = true
        streamingResponseOpacity = 1.0
        lastFlightEndEstimate = Date().addingTimeInterval(5.0)
        NotificationCenter.default.post(name: .clickyFlightStarted, object: nil)

        let screen = NSScreen.screens.first(where: { $0.frame.contains(appKitScreenPoint) }) ?? NSScreen.main ?? NSScreen.screens[0]
        detectedElementDisplayFrame = screen.frame
        detectedElementTargetRadius = targetRadius
        detectedElementScreenLocation = appKitScreenPoint
        armFlightWatchdog()
        ClickySoundEngine.shared.play(.receive)
        ClickyLogger.info("[POINTING]", "Visual element flight triggered at AppKit point: (\(Int(appKitScreenPoint.x)), \(Int(appKitScreenPoint.y)))")
    }

    /// Sets transparent intermediate status text on the Clicky cursor bubble HUD
    @MainActor
    public func setIntermediateStatusText(_ text: String) {
        streamingResponseText = text
        isShowingStreamingResponse = true
        streamingResponseOpacity = 1.0
        voiceState = .processing
    }

    /// Appends message to chat, finishes HUD streaming, and plays speech aloud
    /// Appends message to chat, finishes HUD streaming, and plays speech aloud.
    /// If `speechNarrative` is provided, speech plays that clean narrative instead of raw `text` (TTS cleanliness contract).
    @MainActor
    public func speakAndReportText(_ text: String, speechNarrative: String? = nil) async {
        disarmStreamingWatchdog()
        self.isHomeSpaceStreaming = false
        self.homeSpaceStreamingText = ""
        voiceState = .responding
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: text))
        finishStreamingResponseText(text)

        let isVoiceOutputEnabled = Defaults[.cursorAssistantVoiceOutputEnabled]
        let speechTarget = speechNarrative ?? text
        let speechClean = Self.stripTechnicalTags(from: speechTarget)
        if isVoiceOutputEnabled && !speechClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let ttsWords = speechClean.split { $0.isWhitespace }.count
            lastTTSDurationEstimate = max(2.0, Double(ttsWords) / 2.5)
            NotificationCenter.default.post(name: .clickyTTSStarted, object: nil)
            do {
                try await elevenLabsTTSClient.speakText(speechClean)
                if elevenLabsTTSClient.lastSpokenDuration > 0 {
                    lastTTSDurationEstimate = elevenLabsTTSClient.lastSpokenDuration
                }
            } catch {
                let synthesizer = NSSpeechSynthesizer()
                synthesizer.startSpeaking(speechClean)
            }
        }

        try? await Task.sleep(nanoseconds: 1_200_000_000)
        self.voiceState = .idle
        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
    }

    func showStreamingChunk(_ chunk: String, screenCaptures: [CompanionScreenCapture] = [], isCorrectionTurn: Bool = false) {
        if chunk.hasPrefix(accumulatedRawStreamingText) && accumulatedRawStreamingText.count > 0 {
            accumulatedRawStreamingText = chunk
        } else {
            accumulatedRawStreamingText += chunk
        }

        // Opsi D Fase 3a: TARGET-first instant flight. Planner expression ->
        // AX fast-path (enumerasi + rarity). Hit = flight instan 50ms.
        // Miss = diam (grounder primer Fase 3b yang lanjutkan). Legacy
        // bracket tags ([CANDIDATE:]/[POINT:]) dipertahankan pasif di bawah.
        let pointingAllowed = Self.hasPointingIntent(transcript: ongoingTaskGoal ?? "")
        if !pointingAllowed, !accumulatedRawStreamingText.isEmpty {
            ClickyLogger.info("[INTENT_GATE]", "suppressed flight for non-spatial transcript")
        }
        // Plan sinkron-teks: flight awal saat baris TARGET TERMINASI + matang.
        // String identik final -> akurasi tidak dikorbankan; fallback akhir turn
        // tetap penentu akhir (verifikasi + koreksi). Parsial tanpa \n = diam.
        if pointingAllowed, !hasTriggeredStreamingFlight {
            if let termExpr = Self.terminatedTargetLine(in: accumulatedRawStreamingText),
               Self.isMatureTargetExpression(termExpr) {
                let enriched = Self.enrichTargetExpressionFixed(termExpr, workSurface: currentActiveWorkSurface)
                // Grounder spekulatif (overlap selagi sisa stream jalan)
                ClickyLogger.info("[TARGET_PLANNER]", "Speculative grounder for \"\(enriched.prefix(60))\"")
                requestGrounderEarly(expression: enriched, screenCaptures: screenCaptures, screenNumber: nil)
            } else if Self.parseTargetExpression(from: accumulatedRawStreamingText) != nil {
                // Plan perbaikan: bedakan "belum terminasi" vs "tak matang".
                if Self.terminatedTargetLine(in: accumulatedRawStreamingText) == nil {
                    ClickyLogger.info("[TARGET_PLANNER]", "unterminated expression - waiting for line end")
                } else {
                    ClickyLogger.info("[TARGET_PLANNER]", "immature expression - waiting for object noun")
                }
            }
            // Plan perbaikan 22 Sep: sentinel hotfix7 DIHAPUS. Legacy bracket di
            // streaming TETAP nonaktif (prematur by-design) — flight legacy hanya
            // di fallback/final. Tanpa sentinel: cabang dihapus total, bukan dijaga
            // kondisi mustahil. parseResult tetap dipakai untuk subtitle/chat bersih.
            _ = Self.parsePointingCoordinates(from: accumulatedRawStreamingText)
        }

        // Plan sinkron-teks S2: anti-hide selama streaming — hide hanya boleh
        // di-arm dari scheduleResponseBubbleHide (final), bukan dari chunk.
        responseBubbleHideWorkItem?.cancel()
        // Opsi user 22 Sep (state machine): intent spasial + flight BELUM terpicu
        // = TAHAN display. Akumulator + parser + early-flight tetap jalan di atas.
        // Lepas: flushHeldTextForFlight saat latch true / deliver / akhir turn biasa.
        let spatialHold = Self.hasPointingIntent(transcript: ongoingTaskGoal ?? "") && !hasTriggeredStreamingFlight
        groundingHoldActive = spatialHold
        if spatialHold {
            return
        }
        let cleanText = Self.stripPointingTags(from: accumulatedRawStreamingText)
        let homeSpaceClean = Self.stripTechnicalTags(from: cleanText)
        self.homeSpaceStreamingText = homeSpaceClean
        self.isHomeSpaceStreaming = !homeSpaceClean.isEmpty
        if self.isHomeSpaceStreaming {
            armStreamingWatchdog()
        }

        guard Defaults[.cursorAssistantShowSubtitles], !cleanText.isEmpty else { return }
        let hudText = Self.condenseForCursorHUD(cleanText)
        streamingResponseText = hudText
        isShowingStreamingResponse = true
        withAnimation(.easeOut(duration: 0.2)) {
            streamingResponseOpacity = 1.0
        }
        // Ensure legacy separate overlay panel remains dismissed
        CompanionResponseOverlayManager.shared.hideOverlay()
    }

    func finishStreamingResponseText(_ finalText: String) {
        disarmStreamingWatchdog()
        self.isHomeSpaceStreaming = false
        self.homeSpaceStreamingText = ""
        guard Defaults[.cursorAssistantShowSubtitles] else { return }
        let cleanText = Self.stripPointingTags(from: finalText)
        let hudText = Self.condenseForCursorHUD(cleanText)
        streamingResponseText = hudText
        isShowingStreamingResponse = true
        withAnimation(.easeOut(duration: 0.2)) {
            streamingResponseOpacity = 1.0
        }
        scheduleResponseBubbleHide(for: hudText)
        CompanionResponseOverlayManager.shared.hideOverlay()
    }

    func scheduleResponseBubbleHide(delay: TimeInterval = 6.0) {
        scheduleResponseBubbleHide(for: streamingResponseText)
    }

    /// Dynamically schedules hide based on reading length (longer text stays longer on screen)
    func scheduleResponseBubbleHide(for text: String) {
        responseBubbleHideWorkItem?.cancel()
        let wordCount = text.split { $0.isWhitespace }.count
        let wordDelay = max(4.0, min(18.0, 4.0 + Double(wordCount) / 6.0))
        // Plan sinkron-teks S2: hide = max(wordDelay, TTS+1.0, flightEnd+3.0).
        // Hide #2 (akhir turn) tidak boleh potong TTS lambat / flight grounder.
        var dynamicDelay = wordDelay
        if lastTTSDurationEstimate > 0 {
            dynamicDelay = max(dynamicDelay, lastTTSDurationEstimate + 1.0)
        }
        if let flightEnd = lastFlightEndEstimate {
            let remain = flightEnd.timeIntervalSinceNow + 3.0
            if remain > 0 { dynamicDelay = max(dynamicDelay, remain) }
        }
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.easeOut(duration: 0.4)) {
                self?.streamingResponseOpacity = 0.0
            }
            self?.isShowingStreamingResponse = false
            self?.streamingResponseText = ""
        }
        responseBubbleHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + dynamicDelay, execute: work)
    }

    func hideResponseBubbleImmediately() {
        responseBubbleHideWorkItem?.cancel()
        responseBubbleHideWorkItem = nil
        streamingResponseText = ""
        isShowingStreamingResponse = false
        streamingResponseOpacity = 0.0
        CompanionResponseOverlayManager.shared.hideOverlay()
    }

    /// Triggers the cursor flight and spatial halo ring towards a detected UI element
    private func triggerElementFlight(
        coordinate: CGPoint,
        normalizedBox: (ymin: Double, xmin: Double, ymax: Double, xmax: Double)? = nil,
        targetRadius: CGFloat,
        elementLabel: String?,
        screenNumber: Int?,
        screenCaptures: [CompanionScreenCapture],
        isCorrection: Bool = false
    ) {
        if detectedElementScreenLocation != nil {
            guard isCorrection else { return }
            ClickyLogger.info("[POINTING]", "Correction turn: clearing prior flight before re-trigger")
            clearDetectedElementLocation()
        }

        voiceState = .idle
        detectedElementLabel = elementLabel
        if let label = elementLabel, !label.isEmpty {
            detectedElementBubbleText = "\(label) right here!"
        }
        // Plan perbaikan 22 Sep (3.3): re-assert S2 di JALUR GROUNDER.
        // Audit: re-assert hanya di triggerVisual — jalur grounder live tanpa hold.
        responseBubbleHideWorkItem?.cancel()
        isShowingStreamingResponse = true
        streamingResponseOpacity = 1.0
        lastFlightEndEstimate = Date().addingTimeInterval(7.0)
        NotificationCenter.default.post(name: .clickyFlightStarted, object: nil)

        let targetScreenCapture: CompanionScreenCapture? = {
            if let screenNumber = screenNumber,
               screenNumber >= 1 && screenNumber <= screenCaptures.count {
                return screenCaptures[screenNumber - 1]
            }
            return screenCaptures.first(where: { $0.isCursorScreen })
        }()

        guard let targetScreenCapture else { return }

        let screenshotWidth = CGFloat(targetScreenCapture.screenshotWidthInPixels)
        let screenshotHeight = CGFloat(targetScreenCapture.screenshotHeightInPixels)
        let displayWidth = CGFloat(targetScreenCapture.displayWidthInPoints)
        let displayHeight = CGFloat(targetScreenCapture.displayHeightInPoints)
        let displayFrame = targetScreenCapture.displayFrame

        var displayLocalX: CGFloat
        var displayLocalY: CGFloat
        var finalRadius: CGFloat
        var hasColorMismatch = false

        if let box = normalizedBox {
            // Normalized 0-1000 bounding box (Gemini spatial grounding)
            let normCenterX = (box.xmin + box.xmax) / 2000.0
            let normCenterY = (box.ymin + box.ymax) / 2000.0
            displayLocalX = normCenterX * displayWidth
            displayLocalY = normCenterY * displayHeight

            let boxWidthInPoints = abs(box.xmax - box.xmin) / 1000.0 * displayWidth
            finalRadius = max(24.0, min(50.0, boxWidthInPoints / 2.0 + 8.0))
        } else if coordinate.x > screenshotWidth || coordinate.y > screenshotHeight || coordinate.y >= 900.0 {
            // Already in screen point coordinates (e.g. Dock items at Y >= 900 or display points)
            displayLocalX = max(0, min(coordinate.x, displayWidth))
            displayLocalY = max(0, min(coordinate.y, displayHeight))
            finalRadius = targetRadius
        } else {
            // Raw pixel coordinates in screenshot space (e.g. 1280x800)
            let clampedX = max(0, min(coordinate.x, screenshotWidth))
            let clampedY = max(0, min(coordinate.y, screenshotHeight))


            // Fase 4-4 (Opsi D): saliency snap DICABUT dari jalur kontrol.
            // Bukti: objectness untuk foto, bukan UI datar kecil ("No salient
            // objects" = perilaku yang diharapkan, bukan bug). Titik grounder
            // dipakai apa adanya; file engine tetap ada untuk debug manual.
            finalRadius = targetRadius
            displayLocalX = clampedX * (displayWidth / screenshotWidth)
            displayLocalY = clampedY * (displayHeight / screenshotHeight)
        }

        // Magnetic Traffic Light Snapping for macOS Windows
        let label = (elementLabel ?? "").lowercased()
        let queryContext = (self.ongoingTaskGoal ?? "").lowercased()
        let bubbleContext = (detectedElementBubbleText ?? "").lowercased()
        let combinedContext = "\(label) \(queryContext) \(bubbleContext)"

        let targetWorkSurface = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: combinedContext) ?? currentActiveWorkSurface

        if let ws = targetWorkSurface {
            let userWantsClose = queryContext.contains("close") ||
                                 queryContext.contains("tutup") ||
                                 queryContext.contains("exit") ||
                                 queryContext.contains("quit") ||
                                 queryContext.contains("keluar") ||
                                 ((queryContext.contains("tombol") || queryContext.contains("button")) && (queryContext.contains("red") || queryContext.contains("merah")))

            let userWantsMinimize = queryContext.contains("minimi") ||
                                   ((queryContext.contains("tombol") || queryContext.contains("button")) && (queryContext.contains("kuning") || queryContext.contains("yellow")))

            let userWantsZoom = queryContext.contains("zoom") ||
                                queryContext.contains("full") ||
                                queryContext.contains("perbesar") ||
                                ((queryContext.contains("tombol") || queryContext.contains("button")) && (queryContext.contains("hijau") || queryContext.contains("green")))

            let isClose = userWantsClose && (label.contains("close") || label.contains("red") || label.contains("merah") || label.contains("tutup"))
            let isMinimize = userWantsMinimize && (label.contains("minimi") || label.contains("kuning") || label.contains("yellow"))
            let isZoom = userWantsZoom && (label.contains("zoom") || label.contains("full") || label.contains("hijau") || label.contains("green"))

            // trafficLight*Center is in CG top-left global space (same convention as
            // ws.frame from CGWindowList). displayFrame is AppKit bottom-left, so
            // convert the CG Y into display-local top-left via the window frame:
            // localY = trafficY - windowTopCG, where windowTopCG = frame.origin.y
            // expressed in the same CG space. Using displayFrame.origin.y (AppKit)
            // here mixed two coordinate systems and shifted snaps vertically.
            let localCloseX = ws.trafficLightCloseCenter.x - displayFrame.origin.x
            let localCloseY = ws.trafficLightCloseCenter.y - ws.frame.origin.y

            let dx = abs(displayLocalX - localCloseX)
            let dy = abs(displayLocalY - localCloseY)

            let localWindowOriginX = ws.frame.origin.x - displayFrame.origin.x
            let isNearWindowTopLeft = (dx < 220 && dy < 140) || (displayLocalX < localWindowOriginX && displayLocalX >= localWindowOriginX - 120 && dy < 120)

            let windowBounds = ws.frame
            let isInsideOrNearWindow = displayLocalX >= (windowBounds.origin.x - 50) &&
                                       displayLocalX <= (windowBounds.origin.x + windowBounds.width + 50) &&
                                       displayLocalY >= (windowBounds.origin.y - 50) &&
                                       displayLocalY <= (windowBounds.origin.y + windowBounds.height + 50)

            if isClose && (isInsideOrNearWindow || isNearWindowTopLeft || combinedContext.contains(ws.appName.lowercased()) || combinedContext.contains("close") || combinedContext.contains("tutup")) {
                ClickyLogger.info("[POINTING]", "Magnetically snapped close button from (\(Int(displayLocalX)), \(Int(displayLocalY))) to active window (\(ws.appName)) close button at (\(Int(localCloseX)), \(Int(localCloseY)))")
                displayLocalX = localCloseX
                displayLocalY = localCloseY
                finalRadius = 24.0
            } else if isMinimize && (isInsideOrNearWindow || isNearWindowTopLeft || combinedContext.contains("minimi")) {
                let localMinX = ws.trafficLightMinimizeCenter.x - displayFrame.origin.x
                let localMinY = ws.trafficLightMinimizeCenter.y - ws.frame.origin.y
                ClickyLogger.info("[POINTING]", "Magnetically snapped minimize button from (\(Int(displayLocalX)), \(Int(displayLocalY))) to active window (\(ws.appName)) minimize button at (\(Int(localMinX)), \(Int(localMinY)))")
                displayLocalX = localMinX
                displayLocalY = localMinY
                finalRadius = 24.0
            } else if isZoom && (isInsideOrNearWindow || isNearWindowTopLeft || combinedContext.contains("zoom") || combinedContext.contains("full")) {
                let localZoomX = ws.trafficLightZoomCenter.x - displayFrame.origin.x
                let localZoomY = ws.trafficLightZoomCenter.y - ws.frame.origin.y
                ClickyLogger.info("[POINTING]", "Magnetically snapped zoom button from (\(Int(displayLocalX)), \(Int(displayLocalY))) to active window (\(ws.appName)) zoom button at (\(Int(localZoomX)), \(Int(localZoomY)))")
                displayLocalX = localZoomX
                displayLocalY = localZoomY
                finalRadius = 24.0
            }
        }

        let appKitY = displayHeight - displayLocalY

        let globalLocation = CGPoint(
            x: displayLocalX + displayFrame.origin.x,
            y: appKitY + displayFrame.origin.y
        )

        detectedElementTargetRadius = finalRadius
        detectedElementScreenLocation = globalLocation
        detectedElementDisplayFrame = displayFrame
        armFlightWatchdog()
        ClickySoundEngine.shared.play(.receive)
        ClickyAnalytics.trackElementPointed(elementLabel: elementLabel)
        if hasColorMismatch {
            ClickyLogger.warning("[POINTING]", "Element pointed with UNVERIFIED color: \"\(elementLabel ?? "element")\" at (\(Int(displayLocalX)), \(Int(displayLocalY))) pt — correction turn may re-ground")
            markGroundingMiss()
        } else {
            ClickyLogger.info("[POINTING]", "Element pointed: \"\(elementLabel ?? "element")\" at (\(Int(displayLocalX)), \(Int(displayLocalY))) pt")
        }
    }

    /// SoM history hygiene: flags the active turn so its tags are neutralized
    /// in future few-shot history instead of poisoning it with wrong coords.
    private func markGroundingMiss() {
        // Called on @MainActor instance context; the Task-local flag is set via
        // the shared pending-miss handoff consumed after the turn completes.
        Self.pendingGroundingMiss = true
    }

    private static var pendingGroundingMiss = false

    /// Stage 3 — ROI re-ground entry: crop around a prior guess on the lossless
    /// frame so a correction turn can localize inside the crop at full fidelity.

    public func navigateCursorTo(point: CGPoint, label: String? = nil) {
        self.detectedElementScreenLocation = point
        self.detectedElementLabel = label
        self.detectedElementTargetRadius = 24.0
        ClickySoundEngine.shared.play(.receive)
    }

    // MARK: - AI Response Pipeline

    /// Public method to submit queries via text (Home Space silent chat & quick chips)
    public func askViaText(prompt: String) {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return }
        self.ongoingTaskGoal = cleanPrompt
        self.isTaskSessionPreApproved = false
        sendTranscriptToClaudeWithScreenshot(transcript: cleanPrompt)
    }

    /// Captures a screenshot, sends it along with the transcript to Claude/Gemini,
    /// and plays the response aloud via ElevenLabs TTS or native TTS.
    /// Opsi D Fase 3b — grounder primer ber-budget (pengganti requestGrounderFallback).
    /// Tetap background Task (JANGAN await di MainActor — temuan A), tapi terstruktur:
    /// SATU Task per turn, budget total ~15 dtk (T0 8s + T1/T2 @6s, early-exit bila
    /// T0/T1 sepakat <=24px), cek Task.isCancelled tiap tingkat, handle disimpan di
    /// grounderTask agar stopCurrentTask/Escape bisa cancel. Callback via MainActor.run.
    /// T0 full-frame lossless -> T1 crop DIDILATASI (roiT1Size, tetangga dipertahankan)
    /// -> T2 ketat (roiT2Size) hanya bila tak sepakat/HSV FAIL. Confidence = kesepakatan
    /// T0/T1 + HSV pass; low-confidence -> markGroundingMiss (correction turn re-ground).
    private var grounderTask: Task<Void, Never>?
    /// Speculative early grounder (plan sinkron-teks): dipanggil dari streaming
    /// saat baris TARGET terminasi tapi AX miss. Task SAMA (grounderTask) —
    /// fallback final yang cocok memakai hasilnya; tak cocok = cancel + restart.
    private var grounderEarlyExpression: String? = nil
    /// Opsi user 22 Sep (state machine, BUKAN prediksi): tahan DISPLAY untuk
    /// SEMUA transkrip spasial sejak chunk pertama. Lepas saat flight terpicu
    /// / grounder selesai / turn selesai tanpa flight. Tanpa tebakan.
    /// Opsi user 22 Sep (state machine): TAHAN DISPLAY untuk transkrip spasial
    /// sampai flight terpicu / grounder selesai / turn selesai. BUKAN prediksi:
    /// - tahan bila: intent spasial + !hasTriggeredStreamingFlight.
    /// - lepas bila: latch true (flight!) / deliverPendingGrounded / akhir turn biasa.
    /// Harga: layar diam untuk query spasial sampai ada kepastian.
    private var groundingHoldActive: Bool = false
    /// Flush teks yang ditahan ke display (sekali, saat flight terpicu).
    private func flushHeldTextForFlight() {
        guard groundingHoldActive else { return }
        groundingHoldActive = false
        homeSpaceStreamingText = Self.stripTechnicalTags(from: Self.stripPointingTags(from: accumulatedRawStreamingText))
        isHomeSpaceStreaming = !homeSpaceStreamingText.isEmpty
        streamingResponseText = Self.condenseForCursorHUD(homeSpaceStreamingText)
        isShowingStreamingResponse = !streamingResponseText.isEmpty
        streamingResponseOpacity = 1.0
        ClickyLogger.info("[SYNC]", "held text flushed with flight — together")
    }
    /// Opsi user 22 Sep: paket chat/TTS yang ditunda menunggu grounder selesai.
    private var pendingGroundedDelivery: (spoken: String, final: String)? = nil
    /// Hotfix #10: requestGrounderEarly dipanggil 16x dalam 1 turn (log 13:28) —
    /// tiap chunk panggil ulang karena grounderTask belum ter-assign saat chunk
    /// berikutnya tiba. Flag ini menahan 1x per turn; direset tiap turn baru.
    private var grounderEarlyFiredThisTurn: Bool = false
    /// Fase 4-2: expression terakhir yang di-ground (untuk pesan infeasible jujur).
    private var lastGrounderExpression: String? = nil

    private func requestGrounderEarly(
        expression: String,
        screenCaptures: [CompanionScreenCapture],
        screenNumber: Int?
    ) {
        // Plan perbaikan 22 Sep (Bug B): guard bungkam = misteri orange 13:28.
        // Tiap penolakan WAJIB log agar terlacak.
        guard grounderTask == nil, !grounderEarlyFiredThisTurn else {
            ClickyLogger.info("[GROUNDER]", "early skipped (task busy or fired this turn)")
            return
        }
        grounderEarlyFiredThisTurn = true
        grounderEarlyExpression = expression
        requestGrounderPrimary(expression: expression, screenCaptures: screenCaptures, screenNumber: screenNumber)
    }

    private func requestGrounderPrimary(
        expression: String,
        screenCaptures: [CompanionScreenCapture],
        screenNumber: Int?
    ) {
        grounderTask?.cancel()
        let target: CompanionScreenCapture? = {
            if let n = screenNumber, n >= 1 && n <= screenCaptures.count { return screenCaptures[n - 1] }
            return screenCaptures.first(where: { $0.isCursorScreen }) ?? screenCaptures.first
        }()
        guard let target else {
            deliverPendingGrounded()
            return
        }

        groundingHoldActive = true
        let label = expression
        grounderTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let snapURL = tempDir.appendingPathComponent("companion_ground_\(UUID().uuidString).jpg")
                try target.imageData.write(to: snapURL)
                defer { try? FileManager.default.removeItem(at: snapURL) }

                let res = try await ChatGPTCodexVisionService.shared.queryCoordinates(
                    imagePath: snapURL.path,
                    targetElementPrompt: expression
                )
                let pt = CGPoint(x: res.x, y: res.y)
                ClickyLogger.success("[GROUNDER]", "Luna grounded '\(expression)' at (\(res.x), \(res.y))")
                self.triggerElementFlight(
                    coordinate: pt,
                    targetRadius: 24.0,
                    elementLabel: label,
                    screenNumber: screenNumber,
                    screenCaptures: screenCaptures
                )
                self.deliverPendingGrounded()
            } catch {
                ClickyLogger.warning("[GROUNDER]", "Luna grounding error: \(error.localizedDescription)")
                self.deliverPendingGrounded()
                self.announceGroundingInfeasible(expression: expression)
            }
            self.grounderTask = nil
        }
    }

    /// Fase 4-2: grounder menyerah ([-1,-1]) = target TIDAK TERLIHAT di layar.
    /// Jangan bungkam — katakan jujur + sebab yang bisa ditindak (app tidak terbuka?).
    /// Dipanggil async SETELAH turn selesai; chat susulan, bukan pengganti jawaban model.
    /// Opsi user 22 Sep: kirim paket chat/TTS/bubble yang ditunda menunggu grounder.
    /// Dipanggil saat grounded (bersamaan flight), infeasible, cancel, atau fail —
    /// agar user tidak pernah stuck tanpa jawaban.
    private func deliverPendingGrounded() {
        // LOGIC PENUH (opsi user 22 Sep): akhir turn MENAHAN semua bila grounder
        // jalan. deliver kirim SEMUA sekaligus: chat + bubble + TTS + hide + idle.
        // Satu-satunya pengiriman — tidak ada duplikat karena turn menahan.
        guard let pending = pendingGroundedDelivery else { return }
        pendingGroundedDelivery = nil
        groundingHoldActive = false
        ClickyLogger.info("[SYNC]", "delivering ALL at once: chat+bubble+TTS+flight")
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: pending.spoken))
        finishStreamingResponseText(pending.spoken)
        homeSpaceStreamingText = ""
        isHomeSpaceStreaming = false
        let speechClean = Self.stripTechnicalTags(from: pending.spoken)
        if Defaults[.cursorAssistantVoiceOutputEnabled] && !speechClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let ttsWords = speechClean.split { $0.isWhitespace }.count
            lastTTSDurationEstimate = max(2.0, Double(ttsWords) / 2.5)
            NotificationCenter.default.post(name: .clickyTTSStarted, object: nil)
            Task {
                do {
                    try await elevenLabsTTSClient.speakText(speechClean)
                    if elevenLabsTTSClient.lastSpokenDuration > 0 {
                        lastTTSDurationEstimate = elevenLabsTTSClient.lastSpokenDuration
                    }
                    voiceState = .responding
                } catch {
                    let synthesizer = NSSpeechSynthesizer()
                    synthesizer.startSpeaking(speechClean)
                    voiceState = .responding
                }
            }
        } else if !pending.spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            voiceState = .responding
        }
        // Card nempel (22 Sep): hide di-arm SEBELUM TTS selesai karena speakText
        // async (Task tanpa await). Solusi: tahan hide sampai audio selesai —
        // polling isPlaying tiap 0.5 dtk, lalu schedule hide normal. Tanpa ini,
        // workItem hide 4-6 dtk bisa menang lawan audio yang baru mulai.
        scheduleHideAfterAudio(text: pending.final)
    }

    /// Tahan hide sampai TTS selesai (fix card-nempel 22 Sep). Polling ringan
    /// tiap 0.5 dtk: selama elevenLabsTTSClient.isPlaying, tunda. Begitu selesai
    /// (atau 30 dtk batas aman), schedule hide normal berbasis panjang teks.
    /// Native NSSpeech fallback tak terlacak isPlaying — beri jeda estimasi
    /// kata/2.5 per dtk sebelum hide (lebih baik telat 1 dtk daripada nempel).
    private func scheduleHideAfterAudio(text: String) {
        responseBubbleHideWorkItem?.cancel()
        if !elevenLabsTTSClient.isPlaying {
            let words = text.split { $0.isWhitespace }.count
            let estimate = max(2.0, Double(words) / 2.5)
            ClickyLogger.info("[SYNC]", "hide after native-speech estimate \(String(format: "%.1f", estimate))s")
            scheduleResponseBubbleHide(for: text)
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.elevenLabsTTSClient.isPlaying {
                self.scheduleHideAfterAudio(text: text)
                return
            }
            self.scheduleResponseBubbleHide(for: text)
        }
        responseBubbleHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func announceGroundingInfeasible(expression: String) {
        markGroundingMiss()
        // Opsi user 22 Sep: lepas hold juga di jalur infeasible — teks jawaban
        // model SUDAH tampil? Tidak (ditahan). Tampilkan jawaban model + pesan jujur.
        groundingHoldActive = false
        let wasID = (ongoingTaskGoal ?? "").range(of: "[a-zA-Z]{4,}", options: .regularExpression) == nil
            || (ongoingTaskGoal ?? "").lowercased().contains("mana")
            || (ongoingTaskGoal ?? "").lowercased().contains("dimana")
        let msg = wasID
            ? "itu tidak terlihat di layar sekarang — coba buka aplikasinya dulu lalu tanya lagi."
            : "that's not visible on screen right now — open the app first, then ask again."
        ClickyLogger.warning("[GROUNDER]", "announcing infeasible to user")
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: msg))
        finishStreamingResponseText(msg)
    }

    private func sendTranscriptToClaudeWithScreenshot(transcript: String) {
        self.ongoingTaskGoal = transcript
        currentResponseTask?.cancel()
        elevenLabsTTSClient.stopPlayback()
        hideResponseBubbleImmediately()
        clearDetectedElementLocation()
        hasTriggeredStreamingFlight = false
        flownTargetExpression = nil
        lastTTSDurationEstimate = 0
        lastFlightEndEstimate = nil
        grounderTask?.cancel()
        grounderTask = nil
        grounderEarlyFiredThisTurn = false
        grounderEarlyExpression = nil
        accumulatedRawStreamingText = ""
        currentActiveWorkSurface = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: transcript)
        if let ws = currentActiveWorkSurface {
            ClickyLogger.info("[SURFACE]", "Active frontmost app: \"\(ws.appName)\" bounds: [X: \(Int(ws.frame.origin.x)), Y: \(Int(ws.frame.origin.y)), W: \(Int(ws.frame.width)), H: \(Int(ws.frame.height))] close: (\(Int(ws.trafficLightCloseCenter.x)), \(Int(ws.trafficLightCloseCenter.y)))")
        }

        // Record user query in conversation transcript if not already appended
        if chatMessages.last?.text != transcript || chatMessages.last?.isUser != true {
            appendChatMessage(HomeSpaceChatMessage(isUser: true, text: transcript))
        }

        currentResponseTask = Task {
            voiceState = .processing
            var finalSpokenText = ""

            do {
                let screenCaptures: [CompanionScreenCapture]
                do {
                    screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
                } catch {
                    ClickyLogger.warning("[SCREEN]", "Screen capture unavailable (\(error.localizedDescription)). Proceeding with text-only voice query.")
                    screenCaptures = []
                }

                guard !Task.isCancelled else { return }

                // Plan perbaikan 22 Sep (3.1b): SoM/legenda DIHAPUS dari pipeline.
                // Model tidak lagi lihat nomor/legenda (sumber [CANDIDATE:] liar).
                // Pipeline kirim JPEG MENTAH + TARGET-expression. Annotate hidup hanya
                // via buildSoMDebugImage() manual (IZANOTCHY_SOM_DEBUG=1, Fase 4 tool).
                // screenCaptures immutable di sini — mutableCaptures = salinan mentah.
                let mutableCaptures = screenCaptures
                let somLegends: [[String]] = Array(repeating: [], count: mutableCaptures.count)
                let labeledImages = mutableCaptures.map { capture in
                    let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
                    return (data: capture.imageData, label: capture.label + dimensionInfo)
                }

                // 1. Build initial conversation history for multi-turn context
                // Use rawResponseWithTags so the model sees [POINT:x,y:label] tags from
                // prior turns and can imitate the same format in its next response.
                var messagesForAPI: [[String: Any]] = []
                for entry in conversationHistory {
                    messagesForAPI.append(["role": "user", "content": entry.userTranscript])
                    // SoM: miss turns must not become few-shot exemplars — neutralize
                    // their tags so the model imitates format, not wrong coordinates.
                    if entry.groundingHit {
                        messagesForAPI.append(["role": "assistant", "content": entry.rawResponseWithTags])
                    } else {
                        messagesForAPI.append(["role": "assistant", "content": Self.neutralizeMissTags(in: entry.rawResponseWithTags)])
                    }
                }

                // 2. Build current turn user content with labeled screenshot images + raw transcript
                var currentTurnContent: [[String: Any]] = []
                for (idx, image) in labeledImages.enumerated() {
                    currentTurnContent.append([
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": image.data.base64EncodedString()
                        ]
                    ])
                    currentTurnContent.append([
                        "type": "text",
                        "text": image.label
                    ])
                    // Plan perbaikan: legenda MATI permanen (array selalu kosong).
                    // Blok dipertahankan agar debug-tool Fase 4 bisa tempel manual.
                    if idx < somLegends.count, !somLegends[idx].isEmpty {
                        currentTurnContent.append([
                            "type": "text",
                            "text": "numbered marks legend (nomor = id = label ID / label EN):\n" + somLegends[idx].joined(separator: "\n")
                        ])
                    }
                }
                currentTurnContent.append([
                    "type": "text",
                    "text": transcript
                ])
                messagesForAPI.append(["role": "user", "content": currentTurnContent])

                // MARK: - 3-Layer Deterministic Pipeline (TUNJUK, AKSI, TANYA)
                // Replaces 56-tool blackbox ReAct loop with fast-path router, category-scoped tools & local gates
                await ClickyDeterministicPipeline.shared.processCommand(
                    transcript: transcript,
                    screenCaptures: mutableCaptures,
                    workSurface: currentActiveWorkSurface
                )
                return

                // 3. Load all 56 native tools from embedded cua-driver MCP (instant RAM/disk cache + KV prompt caching)
                let nativeTools = await CuaDriverClient.shared.getAllNativeTools()

                let siriPlanner = self.isSiriAI
                let systemPrompt = Self.buildCompanionVoiceResponseSystemPrompt(
                    workSurface: currentActiveWorkSurface,
                    buddy: self.activeBuddy,
                    isPreApproved: self.isTaskSessionPreApproved,
                    isSiriAIPlannerPath: siriPlanner
                )

                var currentMessages = messagesForAPI
                var fullResponseText = ""
                var hadGroundingMissThisTurn = false
                var turnCount = 0
                let maxTurns = 25

                // 4. ReAct Autonomous Multi-Turn Loop (HeyClicky Continuous Execution Contract)
                while turnCount < maxTurns {
                    turnCount += 1
                    ClickyLogger.info("[REACT_LOOP]", "Starting Turn \(turnCount)/\(maxTurns) with \(nativeTools.count) native tools...")

                    // Reset per-turn streaming accumulator so text from previous turns isn't mashed together.
                    // turnCount > 1 marks a correction turn: a newly parsed tag may
                    // replace the prior flight (Stage 1 correction unlock).
                    self.accumulatedRawStreamingText = ""
                    self.hasTriggeredStreamingFlight = false
                    // Plan perbaikan 22 Sep: reset early-grounder per ReAct-turn.
                    self.grounderEarlyFiredThisTurn = false
                    self.grounderEarlyExpression = nil
                    let isCorrectionTurn = turnCount > 1

                    let turnResult: ClaudeTurnResult
                    if self.isSiriAI {
                        ClickyLogger.info("[SIRI_AI]", "Routing Turn \(turnCount) to on-device Apple Foundation Models (/usr/bin/fm serve)")
                        turnResult = try await SiriAIEngine.shared.analyzeMessagesWithToolsStreaming(
                            messages: currentMessages,
                            systemPrompt: systemPrompt,
                            tools: nativeTools,
                            maxTokens: 1024,
                            onTextChunk: { [weak self] chunk in
                                Task { @MainActor in
                                    self?.showStreamingChunk(chunk, screenCaptures: mutableCaptures, isCorrectionTurn: isCorrectionTurn)
                                }
                            }
                        )
                    } else {
                        turnResult = try await claudeAPI.analyzeMessagesWithToolsStreaming(
                            messages: currentMessages,
                            systemPrompt: systemPrompt,
                            tools: nativeTools,
                            maxTokens: 1024,
                            onTextChunk: { [weak self] chunk in
                                Task { @MainActor in
                                    self?.showStreamingChunk(chunk, screenCaptures: mutableCaptures, isCorrectionTurn: isCorrectionTurn)
                                }
                            }
                        )
                    }

                    guard !Task.isCancelled else { return }

                    if !turnResult.text.isEmpty {
                        fullResponseText = turnResult.text
                    }

                    // If intermediate status was spoken and tools are about to run,
                    // allow a brief reading dwell time (1.2s) so the user can read the status
                    if !turnResult.text.isEmpty && !turnResult.toolCalls.isEmpty {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                    }

                    // If model did not call any tools, final answer has been produced!
                    if turnResult.toolCalls.isEmpty {
                        ClickyLogger.success("[REACT_LOOP]", "Turn \(turnCount): Model completed turn without further tool calls.")
                        break
                    }

                    // Model called native tools — log with arguments for full transparency:
                    let callSummary = turnResult.toolCalls.map { c -> String in
                        let argsStr = (try? JSONSerialization.data(withJSONObject: c.arguments)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        return "\(c.name)(\(argsStr))"
                    }.joined(separator: ", ")
                    ClickyLogger.info("[REACT_LOOP]", "Turn \(turnCount): Model invoked \(turnResult.toolCalls.count) tool(s): [\(callSummary)]")

                    var assistantContent: [[String: Any]] = []
                    if !turnResult.text.isEmpty {
                        assistantContent.append(["type": "text", "text": turnResult.text])
                    }
                    for call in turnResult.toolCalls {
                        assistantContent.append([
                            "type": "tool_use",
                            "id": call.id,
                            "name": call.name,
                            "input": call.arguments
                        ])
                    }
                    currentMessages.append(["role": "assistant", "content": assistantContent])

                    var toolResultBlocks: [[String: Any]] = []
                    var shouldAbortLoop = false

                    for call in turnResult.toolCalls {
                        ClickyLogger.info("[TOOL_EXEC]", "Preparing to execute tool: \(call.name)")

                        // CONSENT GATE: Input tools require user approval unless pre-approved
                        let reactInputTools = Set(["click", "right_click", "type_text", "press_key", "hotkey", "scroll", "set_value", "page", "launch_app", "kill_app"])
                        let isApprovedForInput = Defaults[.alwaysAllowComputerUse] || self.isTaskSessionPreApproved

                        if reactInputTools.contains(call.name) && !isApprovedForInput {
                            let argsStr = (try? JSONSerialization.data(withJSONObject: call.arguments, options: [])).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                            let consentBody = "Saya ingin mengeksekusi `\(call.name)` pada layar Anda.\nArgumen: \(String(argsStr.prefix(150)))\n\nApakah Anda mengizinkan?"

                            ClickyLogger.info("[CONSENT_GATE]", "Turn \(turnCount): Pausing for consent — tool '\(call.name)' requires approval.")

                            // Save continuation state so we can resume after user approves
                            self.pendingReActMessages = currentMessages
                            self.pendingReActSystemPrompt = systemPrompt
                            self.pendingReActNativeTools = nativeTools
                            self.pendingReActScreenCaptures = screenCaptures
                            self.pendingReActOriginalTranscript = transcript

                            let consentReq = ComputerUseRequest(
                                companionName: self.activeBuddy.name,
                                companionMood: .happy,
                                cloudColorHex: self.activeBuddy.avatarColorHex,
                                ringColorHex: "#BAE6FD",
                                heading: "Ingin mengontrol layar Anda",
                                bodyText: consentBody,
                                payload: ComputerUseActionPayload(
                                    type: .click,
                                    targetCoordinate: nil,
                                    targetApp: "System",
                                    rawDetails: consentBody
                                )
                            )

                            Task { @MainActor in
                                self.pendingComputerUseRequest = consentReq
                                ClickySoundEngine.shared.play(.question)
                                NotchComputerUseConsentWindow.shared.show(with: consentReq)
                            }

                            shouldAbortLoop = true
                            break
                        }

                        var executionResult: [String: Any] = [:]
                        var toolErrorMessage: String? = nil
                        do {
                            executionResult = try await CuaDriverClient.shared.executeTool(name: call.name, arguments: call.arguments)
                        } catch {
                            toolErrorMessage = error.localizedDescription
                            executionResult = ["error": error.localizedDescription]
                            ClickyLogger.error("[TOOL_EXEC]", "✗ \(call.name) THREW: \(error.localizedDescription)")
                        }

                        // --- Detect degraded/error result from structured content ---
                        // Special case: get_window_state on Electron apps (e.g. TradingView) always returns
                        // degraded AX tree (ax_window_unresolved), but STILL returns a valid screenshot.
                        // In this case, do NOT fail-fast — pass the screenshot to the model as visual context
                        // and let it navigate via pixel coordinates instead of AX elements.
                        let hasScreenshotInContent = (executionResult["content"] as? [[String: Any]])?
                            .contains(where: { $0["type"] as? String == "image" }) ?? false

                        if toolErrorMessage == nil {
                            if let err = executionResult["error"] as? String {
                                toolErrorMessage = err
                            } else if let sc = executionResult["structuredContent"] as? [String: Any],
                                      let degraded = sc["degraded"] as? Bool, degraded,
                                      let reason = sc["degraded_reason"] as? String {
                                // Only treat as hard failure if there is NO screenshot to fall back on
                                if hasScreenshotInContent {
                                    ClickyLogger.info("[TOOL_EXEC]", "⚠️ \(call.name) AX degraded (\(reason.prefix(80))...) but screenshot available — continuing with visual-only mode.")
                                } else {
                                    toolErrorMessage = reason
                                }
                            }
                        }

                        // --- Log result transparently ---
                        let resultPreview: String
                        if let textContent = (executionResult["content"] as? [[String: Any]])?
                            .first(where: { $0["type"] as? String == "text" })?["text"] as? String {
                            resultPreview = String(textContent.prefix(300))
                        } else if let err = toolErrorMessage {
                            resultPreview = "ERROR: \(err)"
                        } else if let sc = executionResult["structuredContent"] as? [String: Any],
                                  let scData = try? JSONSerialization.data(withJSONObject: sc),
                                  let scStr = String(data: scData, encoding: .utf8) {
                            resultPreview = String(scStr.prefix(300))
                        } else {
                            resultPreview = "ok"
                        }
                        ClickyLogger.info("[TOOL_EXEC]", "← \(call.name) | \(resultPreview)")

                        // --- FAIL-FAST: if tool failed, stop loop and show fallback error to user ---
                        if let errMsg = toolErrorMessage {
                            let userFacing = "⚠️ Aksi `\(call.name)` gagal: \(String(errMsg.prefix(200))). Silakan coba lagi atau berikan instruksi lebih spesifik."
                            ClickyLogger.error("[REACT_LOOP]", "FAIL-FAST on '\(call.name)': \(errMsg). Stopping loop.")
                            Task { @MainActor in
                                self.showStreamingChunk(userFacing, screenCaptures: screenCaptures)
                            }
                            fullResponseText = userFacing
                            shouldAbortLoop = true
                            break
                        }

                        var resultContent: [[String: Any]] = []

                        // 1. Extract native image or text items directly from cua-driver's content array
                        if let contentBlocks = executionResult["content"] as? [[String: Any]], !contentBlocks.isEmpty {
                            for block in contentBlocks {
                                let blockType = block["type"] as? String ?? ""
                                if blockType == "image", let base64Data = block["data"] as? String {
                                    let mime = block["mimeType"] as? String ?? "image/png"
                                    resultContent.append([
                                        "type": "image",
                                        "source": [
                                            "type": "base64",
                                            "media_type": mime,
                                            "data": base64Data
                                        ]
                                    ])
                                    ClickyLogger.info("[TOOL_EXEC]", "📸 \(call.name) → screenshot attached (\(mime))")
                                } else if blockType == "text", let text = block["text"] as? String {
                                    resultContent.append([
                                        "type": "text",
                                        "text": text
                                    ])
                                }
                            }
                        }

                        // 2. Fallback text representation if no text block was populated
                        if !resultContent.contains(where: { ($0["type"] as? String) == "text" }) {
                            let resultString: String
                            if let sc = executionResult["structuredContent"] as? [String: Any],
                               let scData = try? JSONSerialization.data(withJSONObject: sc, options: [.prettyPrinted]),
                               let scStr = String(data: scData, encoding: .utf8) {
                                resultString = scStr
                            } else if let err = executionResult["error"] as? String {
                                resultString = "Error: \(err)"
                            } else if let resData = try? JSONSerialization.data(withJSONObject: executionResult),
                                      let resStr = String(data: resData, encoding: .utf8) {
                                resultString = resStr
                            } else {
                                resultString = "success: true"
                            }
                            resultContent.insert(["type": "text", "text": resultString], at: 0)
                        }

                        // 3. Fallback file-path screenshot if returned
                        if let shotPath = executionResult["screenshot_file_path"] as? String,
                           let shotData = try? Data(contentsOf: URL(fileURLWithPath: shotPath)) {
                            resultContent.append([
                                "type": "image",
                                "source": [
                                    "type": "base64",
                                    "media_type": "image/png",
                                    "data": shotData.base64EncodedString()
                                ]
                            ])
                            ClickyLogger.info("[TOOL_EXEC]", "📸 \(call.name) → file screenshot attached")
                        }

                        toolResultBlocks.append([
                            "type": "tool_result",
                            "tool_use_id": call.id,
                            "content": resultContent
                        ])
                    }

                    if shouldAbortLoop { break }
                    currentMessages.append(["role": "user", "content": toolResultBlocks])
                }

                guard !Task.isCancelled else { return }

                // 5. Final Verbal Synthesis Pass (Anti-Blank / HeyClicky Guaranteed Voice Response)
                // If the loop finished executing tools but the model did not emit a final text report,
                // give the model one final synthesis turn without tools so it speaks its findings!
                if fullResponseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ClickyLogger.info("[REACT_LOOP]", "ReAct loop finished. Executing final verbal synthesis pass...")
                    let synthesisMessages = currentMessages + [
                        ["role": "user", "content": [
                            ["type": "text", "text": "Seluruh observasi dan tindakan fisik telah selesai dijalankan. Berikan jawaban, laporan analisis visual, dan kesimpulan lengkap kepada pengguna sekarang secara ramah dan profesional."]
                        ]]
                    ]
                    let finalSynthesisResult: ClaudeTurnResult?
                    if self.isSiriAI {
                        finalSynthesisResult = try? await SiriAIEngine.shared.analyzeMessagesWithToolsStreaming(
                            messages: synthesisMessages,
                            systemPrompt: systemPrompt,
                            tools: [],
                            maxTokens: 1536,
                            onTextChunk: { [weak self] chunk in
                                Task { @MainActor in
                                    self?.showStreamingChunk(chunk, screenCaptures: screenCaptures, isCorrectionTurn: true)
                                }
                            }
                        )
                    } else {
                        finalSynthesisResult = try? await claudeAPI.analyzeMessagesWithToolsStreaming(
                            messages: synthesisMessages,
                            systemPrompt: systemPrompt,
                            tools: [], // Empty tools array forces the model to speak text
                            maxTokens: 1536,
                            onTextChunk: { [weak self] chunk in
                                Task { @MainActor in
                                    self?.showStreamingChunk(chunk, screenCaptures: screenCaptures, isCorrectionTurn: true)
                                }
                            }
                        )
                    }
                    if let synthesis = finalSynthesisResult, !synthesis.text.isEmpty {
                        fullResponseText = synthesis.text
                        ClickyLogger.success("[REACT_LOOP]", "Final verbal synthesis successfully generated (\(fullResponseText.count) chars)")
                    }
                }

                let parseResult = Self.parsePointingCoordinates(from: fullResponseText)
                // Opsi D Fase 2 final parse (lawan reorder chunk): TARGET lengkap
                // pertama menang per turn; diobservasi via log, belum gerakkan flight.
                if let targetExpr = Self.parseTargetExpression(from: fullResponseText) {
                    let enriched = Self.enrichTargetExpressionFixed(targetExpr, workSurface: currentActiveWorkSurface)
                    ClickyLogger.info("[TARGET_PLANNER]", "final expression: \"\(enriched)\"")
                }
                var spokenText = parseResult.spokenText

                let (cleanedAfterRequest, computerUseReq) = Self.parseComputerUseRequest(from: spokenText, activeBuddy: self.activeBuddy)
                let (cleanedAfterAction, proposedAction) = Self.parseProposedAction(from: cleanedAfterRequest)
                let tvPayload = Self.extractTradingViewPayload(from: fullResponseText)

                // When native Cua Driver tools are enabled, all actions were executed inside the ReAct loop.
                // Only fall back to legacy regex-parsed actions if native tools were not available (empty).
                if nativeTools.isEmpty, let req = computerUseReq {
                    spokenText = cleanedAfterRequest
                    hideResponseBubbleImmediately()
                    if Defaults[.alwaysAllowComputerUse] || self.isTaskSessionPreApproved {
                        ClickyLogger.info("[COMPUTER_USE]", "Full Access / Session pre-approved. Executing directly in autonomous loop: \(req.payload.rawDetails)")
                        let goal = self.ongoingTaskGoal ?? transcript
                        currentResponseTask?.cancel()
                        currentResponseTask = Task { @MainActor in
                            await self.executeAndContinueAutonomousLoop(payload: req.payload, initialGoal: goal)
                        }
                        return
                    } else {
                        self.pendingComputerUseRequest = req
                        ClickySoundEngine.shared.play(.question)
                        NotchComputerUseConsentWindow.shared.show(with: req)
                    }
                } else if nativeTools.isEmpty, let action = proposedAction {
                    spokenText = cleanedAfterAction
                    if Defaults[.alwaysAllowComputerUse] || self.isTaskSessionPreApproved {
                        let payload = ComputerUseActionPayload(
                            type: tvPayload != nil ? .tradingViewAction : (action.actionType == .keyCombo ? .keyCombo : (action.actionType == .launchApp ? .launchApp : .click)),
                            targetCoordinate: action.targetCoordinate,
                            targetApp: action.appName,
                            tradingViewPayload: tvPayload,
                            rawDetails: action.title
                        )
                        let goal = self.ongoingTaskGoal ?? transcript
                        currentResponseTask?.cancel()
                        currentResponseTask = Task { @MainActor in
                            await self.executeAndContinueAutonomousLoop(payload: payload, initialGoal: goal)
                        }
                        return
                    } else {
                        self.proposedComputerUseAction = action
                        ClickySoundEngine.shared.play(.question)
                    }
                } else {
                    spokenText = Self.stripTechnicalTags(from: spokenText)
                    finishStreamingResponseText(spokenText)
                }

                // Restore local Farza assistant cursor after Cua Driver actions finish (only if not already visible)
                if self.isClickyCursorEnabled && !self.overlayWindowManager.isShowingOverlay() {
                    self.overlayWindowManager.showOverlay(onScreens: NSScreen.screens, companionManager: self)
                }

                spokenText = Self.stripTechnicalTags(from: spokenText)
                finalSpokenText = spokenText

                // Fallback flight trigger (Opsi D Fase 3a): [CANDIDATE:] passive,
                // then TARGET->AX rarity-match, else legacy [POINT:] guess.
                var resolvedCoordinate = parseResult.coordinate
                var resolvedLabel = parseResult.elementLabel
                var resolvedRadius = parseResult.targetRadius

                // Hotfix live-test: intent gate juga di fallback. Tanpa ini,
                // "halo" + [CANDIDATE:] pasif tetap terbang (bug 10:28).
                let fallbackAllowed = Self.hasPointingIntent(transcript: transcript)
                if !fallbackAllowed {
                    ClickyLogger.info("[INTENT_GATE]", "suppressed fallback flight for non-spatial transcript")
                }
                if fallbackAllowed, !hasTriggeredStreamingFlight {
                    if resolvedCoordinate != nil {
                        // Opsi D Fase 3a: enforcement + semantic keyword fallback
                        // dihapus. Coba TARGET-expression -> AX rarity-match dulu;
                        // gagal = pertahankan tebakan legacy (grounder Fase 3b tangani).
                        // Hotfix #3: verifikasi flight streaming vs final — tak sepakat
                        // = flight salah (kasus 10:51) -> clear + flight ulang final.
                        if let targetExpr = Self.parseTargetExpression(from: fullResponseText),
                           Self.isMatureTargetExpression(targetExpr) {
                            let enriched = Self.enrichTargetExpressionFixed(targetExpr, workSurface: currentActiveWorkSurface)
                            if !Self.targetExpressionsAgree(flownTargetExpression ?? "", enriched) {
                                ClickyLogger.warning("[POINTING]", "streaming flight DISAGREES with final (flown=\"\(flownTargetExpression ?? "-")\" final=\"\(enriched)\") - re-flying")
                                clearDetectedElementLocation()
                                hasTriggeredStreamingFlight = false
                                flownTargetExpression = nil
                            }
                        }
                    }
                    if resolvedCoordinate == nil {
                        // Opsi D Fase 3a: semantic keyword fallback (dock/icon/mana,
                        // tombol-merah/close/tutup) DIHAPUS — sumber tembakan keyword.
                        // AX-miss diteruskan ke grounder primer (Fase 3b) di bawah.
                        ClickyLogger.info("[TARGET_PLANNER]", "AX miss at fallback - grounder path")
                    }

                    if let pointCoordinate = resolvedCoordinate {
                        triggerElementFlight(
                            coordinate: pointCoordinate,
                            normalizedBox: parseResult.normalizedBox,
                            targetRadius: resolvedRadius,
                            elementLabel: resolvedLabel,
                            screenNumber: parseResult.screenNumber,
                            screenCaptures: mutableCaptures
                        )
                    } else if transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ClickySoundEngine.shared.play(.question)
                    } else {
                        // Opsi D Fase 3b: AX-miss -> grounder primer. Instruction =
                        // planner TARGET-expression (enriched) bila ada, else transcript
                        // mentah (planner wajib; terbukti MISS tanpa planner — tetap coba).
                        // Hotfix #3: final matang SELALU menang atas transcript mentah.
                        // ID mentah tanpa planner TERBUKTI miss total (uji 21 Sep) —
                        // grounder wajib dapat EN Long-RE, bukan transcript ID.
                        let grounderInstruction: String
                        if let targetExpr = Self.parseTargetExpression(from: fullResponseText),
                           Self.isMatureTargetExpression(targetExpr) {
                            grounderInstruction = Self.enrichTargetExpressionFixed(targetExpr, workSurface: currentActiveWorkSurface)
                        } else if let flown = flownTargetExpression, Self.isMatureTargetExpression(flown) {
                            grounderInstruction = flown
                        } else {
                            grounderInstruction = transcript
                        }
                        if fallbackAllowed {
                            if let early = grounderEarlyExpression,
                               !Self.targetExpressionsAgree(early, grounderInstruction) {
                                ClickyLogger.warning("[GROUNDER]", "early guess DISAGREES with final - restarting")
                                grounderTask?.cancel()
                                grounderTask = nil
                                grounderEarlyExpression = nil
                            }
                            if grounderTask == nil {
                                ClickyLogger.info("[GROUNDER]", "starting primary at fallback for \"(grounderInstruction.prefix(60))\"")
                                grounderEarlyExpression = nil
                                requestGrounderPrimary(
                                    expression: grounderInstruction,
                                    screenCaptures: mutableCaptures,
                                    screenNumber: parseResult.screenNumber
                                )
                                if grounderTask != nil {
                                    // Grounder jalan: TUNDA chat/TTS sampai selesai.
                                    pendingGroundedDelivery = (spoken: spokenText, final: finalSpokenText)
                                    ClickyLogger.info("[SYNC]", "deferring chat+TTS until grounder completes")
                                }
                            } else {
                                // BUKAN leak bila ini task EARLY yang cocok dengan final:
                                // ia masih jalan dan hasilnya dipakai. Tunda chat/TTS juga.
                                if grounderEarlyExpression != nil {
                                    pendingGroundedDelivery = (spoken: spokenText, final: finalSpokenText)
                                    ClickyLogger.info("[SYNC]", "deferring chat+TTS until early grounder completes")
                                } else {
                                    ClickyLogger.warning("[GROUNDER]", "fallback skipped: stale grounderTask busy (lifecycle leak?)")
                                }
                            }
                        }
                    }
                }

                // State machine: turn selesai TANPA flight + TANPA grounder jalan =
                // lepas hold, kirim biasa (jangan bungkam). Grounder jalan = pending
                // (callback deliver). history tetap dicatat dua-duanya.
                if groundingHoldActive, grounderTask == nil, pendingGroundedDelivery == nil {
                    groundingHoldActive = false
                    ClickyLogger.info("[SYNC]", "hold released at turn end (no flight, no grounder)")
                }

                // LOGIC PENUH (opsi user 22 Sep): grounder masih jalan (fresh dari
                // fallback ATAU early-cocok yang dipertahankan) -> TAHAN SEMUA.
                // Tidak chat, tidak TTS, tidak hide, tidak idle. Callback grounder
                // (grounded/infeasible/cancel/fail) kirim semuanya sekaligus.
                if grounderTask != nil, pendingGroundedDelivery == nil {
                    pendingGroundedDelivery = (spoken: spokenText, final: finalSpokenText)
                    ClickyLogger.info("[SYNC]", "holding ALL output until grounder completes")
                }

                // Save this exchange to conversation history.
                // rawResponseWithTags preserves [POINT:x,y:label] tags so the model can
                // imitate the same format in future turns (in-context few-shot memory).
                conversationHistory.append((
                    userTranscript: transcript,
                    assistantResponse: spokenText,
                    rawResponseWithTags: fullResponseText,
                    groundingHit: !hadGroundingMissThisTurn && !Self.pendingGroundingMiss
                ))
                Self.pendingGroundingMiss = false

                // Opsi user 22 Sep: grounder jalan -> chat/TTS ditunda, callback kirim.
                // (history tetap dicatat agar konteks tidak hilang.)
                if pendingGroundedDelivery == nil {
                    appendChatMessage(HomeSpaceChatMessage(isUser: false, text: spokenText))
                } else {
                    ClickyLogger.info("[SYNC]", "chat held for grounder")
                }

                // Immediately clear HomeSpace active streaming state upon successful message arrival
                self.homeSpaceStreamingText = ""
                self.isHomeSpaceStreaming = false
                self.ongoingTaskGoal = nil

                // Keep only the last 10 exchanges to avoid unbounded context growth
                if conversationHistory.count > 10 {
                    conversationHistory.removeFirst(conversationHistory.count - 10)
                }

                print("🧠 Conversation history: \(conversationHistory.count) exchanges")

                ClickyAnalytics.trackAIResponseReceived(response: spokenText)

                // Opsi user 22 Sep: TTS ikut ditunda bila grounder jalan.
                let grounderPending = pendingGroundedDelivery != nil
                // Play the response via TTS if voice output is enabled
                let isVoiceOutputEnabled = Defaults[.cursorAssistantVoiceOutputEnabled] && !grounderPending
                let speechClean = Self.stripTechnicalTags(from: spokenText)
                if isVoiceOutputEnabled && !speechClean.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Plan sinkron-teks S3: estimasi durasi audio (~2.5 kata/dtk) untuk
                    // hold bubble = max(wordDelay, TTS+1.0, flightEnd+3.0). Event started
                    // dipost agar view bisa hold; presisi tidak perlu (±30% diterima).
                    let ttsWords = speechClean.split { $0.isWhitespace }.count
                    lastTTSDurationEstimate = max(2.0, Double(ttsWords) / 2.5)
                    NotificationCenter.default.post(name: .clickyTTSStarted, object: nil)
                    do {
                        try await elevenLabsTTSClient.speakText(speechClean)
                        // speakText returns after player.play() — audio is now playing.
                        // Plan perbaikan 22 Sep (3.3): durasi RIIL menimpa estimasi.
                        if elevenLabsTTSClient.lastSpokenDuration > 0 {
                            lastTTSDurationEstimate = elevenLabsTTSClient.lastSpokenDuration
                        }
                        voiceState = .responding
                    } catch {
                        ClickyAnalytics.trackTTSError(error: error.localizedDescription)
                        print("⚠️ ElevenLabs TTS error: \(error), falling back to macOS native TTS")
                        let synthesizer = NSSpeechSynthesizer()
                        synthesizer.startSpeaking(speechClean)
                        voiceState = .responding
                    }
                } else if !grounderPending, !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Silent Mode (Text Bubble Only):
                    voiceState = .responding
                    try? await Task.sleep(nanoseconds: 800_000_000)
                }
            } catch is CancellationError {
                // User spoke again — response was interrupted
                self.homeSpaceStreamingText = ""
                self.isHomeSpaceStreaming = false
                self.ongoingTaskGoal = nil
            } catch {
                self.homeSpaceStreamingText = ""
                self.isHomeSpaceStreaming = false
                self.ongoingTaskGoal = nil
                ClickyAnalytics.trackResponseError(error: error.localizedDescription)
                print("⚠️ Companion response error: \(error)")
                speakCreditsErrorFallback()
            }

            if !Task.isCancelled, pendingGroundedDelivery == nil {
                voiceState = .idle
                isHomeSpaceStreaming = false
                homeSpaceStreamingText = ""
                self.ongoingTaskGoal = nil
                scheduleTransientHideIfNeeded()
                scheduleResponseBubbleHide(for: finalSpokenText)
            }
        }
    }

    /// If the cursor is in transient mode (user toggled "Show Clicky" off),
    /// waits for TTS playback and any pointing animation to finish, then
    /// fades out the overlay after a 1-second pause. Cancelled automatically
    /// if the user starts another push-to-talk interaction.
    private func scheduleTransientHideIfNeeded() {
        guard !isClickyCursorEnabled && isOverlayVisible else { return }

        transientHideTask?.cancel()
        transientHideTask = Task {
            // Wait for TTS audio to finish playing
            while elevenLabsTTSClient.isPlaying {
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

            // Wait for pointing animation to finish (location is cleared
            // when the buddy flies back to the cursor, max 4s)
            var flightWaitSteps = 0
            while detectedElementScreenLocation != nil && flightWaitSteps < 20 {
                flightWaitSteps += 1
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard !Task.isCancelled else { return }
            }

            // Pause 1s after everything finishes, then fade out
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            overlayWindowManager.fadeOutAndHideOverlay()
            isOverlayVisible = false
        }
    }

    /// Speaks an informative error message using macOS system TTS when AI
    /// connection fails or bridge is unreachable.
    private func speakCreditsErrorFallback() {
        let isBridgeRunning = AntigravityBridgeManager.shared.isRunning
        let utterance: String
        if !isBridgeRunning {
            utterance = "Clicky tidak dapat terhubung ke Gemini AI Bridge. Silakan periksa status AI Bridge di pengaturan BoringNotch."
        } else {
            utterance = "Maaf, terjadi kendala saat meminta respon ke Gemini. Silakan coba lagi."
        }
        let synthesizer = NSSpeechSynthesizer()
        synthesizer.startSpeaking(utterance)
        voiceState = .responding
    }

    // MARK: - Point Tag Parsing

    /// Result of parsing a [CANDIDATE:...], [TARGET:...] or [POINT:...] tag.
    struct PointingParseResult {
        /// The response text with the pointing tag removed — this is what gets spoken.
        let spokenText: String
        /// Stable OS-truth candidate id from [CANDIDATE:<id>:<label>], if present.
        let candidateId: String?
        /// The parsed pixel coordinate, or nil if none was found.
        let coordinate: CGPoint?
        /// Target halo radius in points
        let targetRadius: CGFloat
        /// Short label describing the element (e.g. "close button"), or "none".
        let elementLabel: String?
        /// Which screen the coordinate refers to (1-based), or nil to default to cursor screen.
        let screenNumber: Int?
        /// Normalized 0-1000 bounding box (Gemini spatial grounding: ymin, xmin, ymax, xmax)
        let normalizedBox: (ymin: Double, xmin: Double, ymax: Double, xmax: Double)?
    }

    /// Plan sinkron-teks (2026-09-22): baris TARGET yang TERMINASI newline adalah
    /// sinyal flight awal yang aman. Bedakan "lengkap" (ada \n penutup) dari "matang"
    /// (isMatureTargetExpression). Chunk parsial "Red circle in bottom..." (tanpa \n)
    /// DITOLAK walau matang — itulah yang menembak dock-safari 3x (10:39/10:51/11:23).
    /// Kembalikan expression bila baris TARGET sudah terminasi, else nil.
    static func terminatedTargetLine(in text: String) -> String? {
        // Plan perbaikan 22 Sep (Bug A): syarat \\n MEMBUNUH early-flight — AFM
        // streaming fragmen token tanpa newline sampai kalimat kedua jalan.
        // Terminasi = baris TARGET LENGKAP (akhir-string ATAU \\n). Parsial yang
        // masih diketik (tanpa terminasi) tetap ditolak — bedakan via $ vs \\n.
        let pattern = #"(?im)^[ \t]*TARGET:[ \t]*(.+?)[ \t]*(?:\n|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let expr = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !expr.isEmpty else { return nil }
        return expr
    }

    /// Opsi D Fase 2: planner referring expression — satu baris "TARGET: <Long-RE>".
    /// Dipanggil di streaming (akumulator) DAN di akhir turn (final, lawan reorder).
    /// Kembalikan expression mentah (tanpa prefix), atau nil bila tidak ada.
    static func parseTargetExpression(from responseText: String) -> String? {
        let pattern = #"(?im)^[ \t]*TARGET:[ \t]*(.+?)[ \t]*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: responseText) else { return nil }
        let expr = String(responseText[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !expr.isEmpty else { return nil }
        return expr
    }

    /// DELETED (Hotfix #9): enrichment menempel frontmost-app yang salah.
    /// Pemanggil terakhir dimigrasikan ke Fixed (identitas). Jangan hidupkan lagi.
    /// @deprecated Gunakan enrichTargetExpressionFixed (identitas, tanpa append).
    static func enrichTargetExpression(_ expr: String, workSurface: ActiveWorkSurface?) -> String {
        let lower = expr.lowercased()
        if let ws = workSurface, !ws.appName.isEmpty,
           !lower.contains(ws.appName.lowercased()) && !lower.contains("window") && !lower.contains("screen") && !lower.contains("dock") {
            return "\(expr) in \(ws.appName) window"
        }
        return expr
    }

    /// Hotfix live-test 2026-09-22 (2 bug):
    /// (1) Intent gate — sapaan ("halo") tanpa intensi tunjuk TIDAK boleh terbang,
    ///     walau model keluarkan [CANDIDATE:]/[POINT:]/TARGET:. Tanpa gate ini,
    ///     cabang pasif [CANDIDATE:] menerbangkan kursor untuk chat biasa.
    ///     Deteksi: model chat tidak boleh lagi keluarkan angka — tapi sebelum Fase 4
    ///     (SoM legend masih dikirim) model masih bisa emit bracket tags; gate ini
    ///     menahan flight untuk transkrip non-spasial.
    /// (2) Enrichment menimpa app yang disebut model ("...Autodraw window" + "in Safari
    ///     window") -> rarity cocok ke dock-safari yang salah. Perbaikan: JANGAN append
    ///     bila RE sudah menyebut NAMA APP APAPUN yang sedang berjalan (bukan hanya
    ///     ws.appName), dan jangan append bila RE sudah sebut wilayah (window/screen/dock).
    static func hasPointingIntent(transcript: String) -> Bool {
        let t = transcript.lowercased()
        // Verba/objek spasial ID + EN. Sapaan ("halo", "hai", "hello", "thanks",
        // "apa kabar") tidak mengandung satupun -> gate menolak.
        let markers = ["mana", "dimana", "tunjuk", "tunjukkan", "tunj", "klik", "tombol",
            "ikon", "icon", "lingkaran", "kotak", "gambar", "bentuk", "warna", "merah",
            "kuning", "hijau", "biru", "oranye", "cari", "letak", "posisi", "sebelah",
            "pojok", "atas", "bawah", "kiri", "kanan", "tengah", "jendela", "window",
            "button", "circle", "square", "shape", "color", "red", "yellow", "green",
            "blue", "orange", "where", "which", "show", "point", "click", "close",
            "tutup", "buka", "zoom", "dock", "menu", "tab", "teks", "text"]
        return markers.contains(where: { t.contains($0) })
    }

    /// Nama app berjalan yang disebut di RE (untuk enrichment fix #2).
    static func mentionedRunningApp(in lowerExpr: String) -> String? {
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  let name = app.localizedName, name.count >= 3 else { continue }
            if lowerExpr.contains(name.lowercased()) { return name }
        }
        return nil
    }

    /// Hotfix live-test #2 (2026-09-22 10:39): flight prematur dari expression
    /// PARSIAL. Chunk pertama ("red...") + enrichment ("in Safari window") langsung
    /// cocok rarity ke dock-safari dan mengunci latch — expression lengkap yang benar
    /// ("red circle ... Autodraw window") datang 1 dtk kemudian tapi diabaikan.
    /// Aturan matang: expression minimal 3 token DAN mengandung kata benda objek
    /// (bukan cuma sifat/wilayah). Belum matang = tunggu chunk berikutnya; flight
    /// diputuskan di akhir turn dari expression final. Dock/traffic tidak dikecualikan:
    /// kasus 10:39 membuktikan pengecualian itu yang justru menembak salah.
    /// Hotfix live-test #3 (2026-09-22 10:51): expression PARSIAL yang lolos maturity
    /// ("Red circle with" + enrichment "in Safari window") mengunci latch padahal final
    /// ("Red circle ... Autodraw window") beda total. Aturan: flight streaming BUKAN
    /// final — ia hanya "pinjaman" yang HARUS dikembalikan bila final tak sepakat.
    /// Kesepakatan = token-intersection final vs yang dipakai flight >= 60% token final
    /// (stopword-free, len>=3). Di bawah itu = flight salah sasaran -> clear + flight ulang.
    static func targetExpressionsAgree(_ flown: String, _ final: String) -> Bool {
        func toks(_ s: String) -> Set<String> {
            Set(s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 3 })
        }
        let a = toks(flown), b = toks(final)
        guard !b.isEmpty else { return true }
        let inter = a.intersection(b).count
        return Double(inter) / Double(b.count) >= 0.6
    }

    static func isMatureTargetExpression(_ expr: String) -> Bool {
        let toks = expr.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 3 }
        guard toks.count >= 3 else { return false }
        let objectNouns = ["circle", "lingkaran", "button", "tombol", "icon", "ikon",
            "window", "jendela", "menu", "tab", "dock", "square", "kotak", "shape",
            "bentuk", "text", "teks", "image", "gambar", "field", "slider", "checkbox",
            "link", "close", "tutup", "minimize", "zoom", "trash", "finder", "safari",
            "whatsapp", "terminal", "spot", "search", "create", "rovo",
            "dot", "titik", "spot", "cluster", "sidebar", "panel", "bar", "logo",
            "triangle", "segitiga", "ring", "cincin", "box", "kotak"]
        return toks.contains(where: { objectNouns.contains($0) })
    }

    /// Hotfix #9 (2026-09-22 13:14, BUKTI + SIMULASI): enrichment DIHAPUS TOTAL.
    /// "in Safari window" (frontmost) adalah satu-satunya token yang cocok ke kandidat
    /// (simulasi: DENGAN enrichment dock-safari menang 3.4; TANPA = semua 0.0 = MISS).
    /// Frontmost app TIDAK sama dengan app yang dimaksud user (Autodraw di belakang
    /// Safari saat bicara). Konteks OS disuntik ke PROMPT planner (bukan ke expression),
    /// dan planner yang putuskan menyebut app apa. Fungsi dipertahankan sebagai
    /// identitas agar call-site tak berubah.
    static func enrichTargetExpressionFixed(_ expr: String, workSurface: ActiveWorkSurface?) -> String {
        return expr
    }

    /// Parses [CANDIDATE:<id>:<label>], [TARGET:ymin,xmin,ymax,xmax:label], [TARGET:x,y,r:label], or [POINT:x,y:label:screenN].
    static func parsePointingCoordinates(from responseText: String) -> PointingParseResult {
        let quoteAndWhitespace = CharacterSet(charactersIn: "\"\'").union(.whitespacesAndNewlines)
        let trimmedResponse = responseText.trimmingCharacters(in: quoteAndWhitespace)

        // 0. Stage 2 candidate tag: [CANDIDATE:<id>:<label>] — model selects, OS resolves.
        let candidatePattern = #"(?i)\[CANDIDATE:([A-Za-z0-9_\-]+)(?::([^\]:]*?))?\]"#
        if let candRegex = try? NSRegularExpression(pattern: candidatePattern, options: []),
           let candMatch = candRegex.firstMatch(in: trimmedResponse, range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse)),
           let idRange = Range(candMatch.range(at: 1), in: trimmedResponse) {
            let cid = String(trimmedResponse[idRange])
            var candLabel: String? = nil
            if candMatch.numberOfRanges >= 3, let lr = Range(candMatch.range(at: 2), in: trimmedResponse) {
                let l = String(trimmedResponse[lr]).trimmingCharacters(in: .whitespaces)
                if !l.isEmpty { candLabel = l }
            }
            let cleaned = candRegex.stringByReplacingMatches(
                in: trimmedResponse, options: [],
                range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse),
                withTemplate: ""
            ).trimmingCharacters(in: quoteAndWhitespace)
            let spoken = !cleaned.isEmpty ? cleaned : (candLabel != nil ? "\(candLabel!) right here!" : "this way!")
            return PointingParseResult(spokenText: spoken, candidateId: cid, coordinate: nil, targetRadius: 28.0, elementLabel: candLabel, screenNumber: nil, normalizedBox: nil)
        }

        // 1. Check for normalized 4-value bounding box: [TARGET:ymin,xmin,ymax,xmax:label] or [BOX:ymin,xmin,ymax,xmax:label]
        let boxPattern = #"(?i)\[(?:TARGET|POINT|BOX):(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?\]"#
        if let boxRegex = try? NSRegularExpression(pattern: boxPattern, options: []),
           let match = boxRegex.firstMatch(in: trimmedResponse, range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse)) {
            let cleanedText = boxRegex.stringByReplacingMatches(
                in: trimmedResponse,
                options: [],
                range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse),
                withTemplate: ""
            ).trimmingCharacters(in: quoteAndWhitespace)

            if match.numberOfRanges >= 5,
               let yminRange = Range(match.range(at: 1), in: trimmedResponse),
               let xminRange = Range(match.range(at: 2), in: trimmedResponse),
               let ymaxRange = Range(match.range(at: 3), in: trimmedResponse),
               let xmaxRange = Range(match.range(at: 4), in: trimmedResponse),
               let ymin = Double(trimmedResponse[yminRange]),
               let xmin = Double(trimmedResponse[xminRange]),
               let ymax = Double(trimmedResponse[ymaxRange]),
               let xmax = Double(trimmedResponse[xmaxRange]) {
                var elementLabel: String? = nil
                if match.numberOfRanges >= 6, let labelRange = Range(match.range(at: 5), in: trimmedResponse) {
                    let label = String(trimmedResponse[labelRange]).trimmingCharacters(in: .whitespaces)
                    if !label.isEmpty { elementLabel = label }
                }
                var screenNumber: Int? = nil
                if match.numberOfRanges >= 7, let screenRange = Range(match.range(at: 6), in: trimmedResponse) {
                    screenNumber = Int(trimmedResponse[screenRange])
                }
                let finalSpokenText = !cleanedText.isEmpty ? cleanedText : (elementLabel != nil ? "\(elementLabel!) right here!" : "this way!")
                return PointingParseResult(
                    spokenText: finalSpokenText,
                    candidateId: nil,
                    coordinate: CGPoint(x: (xmin + xmax) / 2.0, y: (ymin + ymax) / 2.0),
                    targetRadius: 30.0,
                    elementLabel: elementLabel,
                    screenNumber: screenNumber,
                    normalizedBox: (ymin: ymin, xmin: xmin, ymax: ymax, xmax: xmax)
                )
            }
        }

        // 2. Check for standard 2 or 3 value pixel format: [TARGET:x,y,r:label] or [POINT:x,y:label]
        let pattern = #"(?i)\[(?:TARGET|POINT):(?:none|(\d+)\s*,\s*(\d+)(?:\s*,\s*(\d+))?(?::([^\]:\s][^\]:]*?))?(?::screen(\d+))?)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: trimmedResponse, range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse)) else {
            return PointingParseResult(spokenText: trimmedResponse, candidateId: nil, coordinate: nil, targetRadius: 35.0, elementLabel: nil, screenNumber: nil, normalizedBox: nil)
        }

        let cleanedText = regex.stringByReplacingMatches(
            in: trimmedResponse,
            options: [],
            range: NSRange(trimmedResponse.startIndex..., in: trimmedResponse),
            withTemplate: ""
        ).trimmingCharacters(in: quoteAndWhitespace)

        guard match.numberOfRanges >= 3,
              let xRange = Range(match.range(at: 1), in: trimmedResponse),
              let yRange = Range(match.range(at: 2), in: trimmedResponse),
              let x = Double(trimmedResponse[xRange]),
              let y = Double(trimmedResponse[yRange]) else {
            return PointingParseResult(spokenText: cleanedText, candidateId: nil, coordinate: nil, targetRadius: 35.0, elementLabel: "none", screenNumber: nil, normalizedBox: nil)
        }

        var targetRadius: CGFloat = 35.0
        if match.numberOfRanges >= 4, let rRange = Range(match.range(at: 3), in: trimmedResponse), let r = Double(trimmedResponse[rRange]) {
            targetRadius = CGFloat(r)
        }

        var elementLabel: String? = nil
        if match.numberOfRanges >= 5, let labelRange = Range(match.range(at: 4), in: trimmedResponse) {
            let label = String(trimmedResponse[labelRange]).trimmingCharacters(in: .whitespaces)
            if !label.isEmpty {
                elementLabel = label
            }
        }

        var screenNumber: Int? = nil
        if match.numberOfRanges >= 6, let screenRange = Range(match.range(at: 5), in: trimmedResponse) {
            screenNumber = Int(trimmedResponse[screenRange])
        }

        let finalSpokenText = !cleanedText.isEmpty ? cleanedText : (elementLabel != nil ? "\(elementLabel!) right here!" : "this way!")

        return PointingParseResult(
            spokenText: finalSpokenText,
            candidateId: nil,
            coordinate: CGPoint(x: x, y: y),
            targetRadius: targetRadius,
            elementLabel: elementLabel,
            screenNumber: screenNumber,
            normalizedBox: nil
        )
    }

    /// Strips any pointing, action, target, or candidate tags from text for clean subtitle, chat & TTS display
    /// Opsi D Fase 2: juga strip baris planner "TARGET: <expression>" agar tidak bocor ke TTS/subtitle.
    static func stripTechnicalTags(from text: String) -> String {
        // 0. Strip planner line: a full line starting with TARGET: (plain, no brackets).
        let plannerPattern = #"(?im)^[ \t]*TARGET:[ \t]*.+?[ \t]*$"#
        var cleaned = text
        if let regex = try? NSRegularExpression(pattern: plannerPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }
        // 1. Strip completed bracket tags: [TARGET:...], [ACTION:...], [POINT:...], [BOX:...], [CANDIDATE:...], [REQUEST_FEATURE:...], etc.
        let fullTagPattern = #"(?i)\[(?:TARGET|POINT|BOX|ACTION|CANDIDATE|REQUEST_FEATURE):[^\]]*\]"#
        if let regex = try? NSRegularExpression(pattern: fullTagPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }

        // 2. Strip XML/HTML tags: <COMPUTER_USE_REQUEST>...</COMPUTER_USE_REQUEST> or generic <...>
        let xmlPattern = #"(?is)<COMPUTER_USE_REQUEST>.*?</COMPUTER_USE_REQUEST>|<[^>]+>"#
        if let xmlRegex = try? NSRegularExpression(pattern: xmlPattern, options: []) {
            cleaned = xmlRegex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(cleaned.startIndex..., in: cleaned),
                withTemplate: ""
            )
        }

        // 3. Strip trailing unclosed tag during live streaming (e.g. "[ACTION:tv_time..." or "<COMPUTER_USE...")
        if let lastOpenBracket = cleaned.lastIndex(of: "[") {
            let suffix = cleaned[lastOpenBracket...]
            if !suffix.contains("]") && (suffix.lowercased().contains("action") || suffix.lowercased().contains("target") || suffix.lowercased().contains("candidate") || suffix.lowercased().contains("point") || suffix.lowercased().contains("request_feature")) {
                cleaned = String(cleaned[..<lastOpenBracket])
            }
        }
        if let lastOpenAngle = cleaned.lastIndex(of: "<") {
            let suffix = cleaned[lastOpenAngle...]
            if !suffix.contains(">") && suffix.lowercased().contains("computer_use") {
                cleaned = String(cleaned[..<lastOpenAngle])
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// SoM: replaces [POINT:]/[TARGET:]/[BOX:]/[CANDIDATE:] tags from a MISS turn
    /// with a neutral marker so history teaches format without wrong coordinates.
    /// Opsi D Fase 2: juga netralkan baris planner "TARGET: <expr>" yang miss.
    static func neutralizeMissTags(in text: String) -> String {
        // Hotfix #8 (2026-09-22): marker "[... removed — miss]" BOCOR ke chat user
        // karena stripTechnicalTags tidak kenal pola "[POINT removed — miss]".
        // Perbaikan: netralkan dengan MENGHAPUS tag (string kosong), bukan marker.
        // History tetap ajarkan format? Tidak — dengan planner TARGET:, history TIDAK
        // perlu contoh koordinat sama sekali. Hapus bersih = tidak bocor + tidak meracuni.
        let missPattern = #"(?i)\[(?:TARGET|POINT|BOX|CANDIDATE):[^\]]*\]"#
        var out = text
        if let rx = try? NSRegularExpression(pattern: missPattern, options: []) {
            out = rx.stringByReplacingMatches(in: out, options: [], range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        let plannerMiss = #"(?im)^[ \t]*TARGET:[ \t]*.+?[ \t]*$"#
        if let rx = try? NSRegularExpression(pattern: plannerMiss, options: []) {
            out = rx.stringByReplacingMatches(in: out, options: [], range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        return out
    }

    static func stripPointingTags(from text: String) -> String {
        return stripTechnicalTags(from: text)
    }

    /// Filters out raw Markdown table rows (| ... |) so TTS vocalizes natural conversational sentences smoothly
    static func stripTableForSpeech(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("|")
        }
        let spoken = filtered.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return spoken.isEmpty ? "I have prepared the trade setup table in your chat." : spoken
    }

    // MARK: - Onboarding Video

    /// Sets up the onboarding video player, starts playback, and schedules
    /// the demo interaction at 40s. Called by BlueCursorView when onboarding starts.
    func setupOnboardingVideo() {
        guard let videoURL = URL(string: "https://stream.mux.com/e5jB8UuSrtFABVnTHCR7k3sIsmcUHCyhtLu1tzqLlfs.m3u8") else { return }

        let player = AVPlayer(url: videoURL)
        player.isMuted = false
        player.volume = 0.0
        self.onboardingVideoPlayer = player
        self.showOnboardingVideo = true
        self.onboardingVideoOpacity = 0.0

        // Start playback immediately — the video plays while invisible,
        // then we fade in both the visual and audio over 1s.
        player.play()

        // Wait for SwiftUI to mount the view, then set opacity to 1.
        // The .animation modifier on the view handles the actual animation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.onboardingVideoOpacity = 1.0
            // Fade audio volume from 0 → 1 over 2s to match visual fade
            self.fadeInVideoAudio(player: player, targetVolume: 1.0, duration: 2.0)
        }

        // At 40 seconds into the video, trigger the onboarding demo where
        // Clicky flies to something interesting on screen and comments on it
        let demoTriggerTime = CMTime(seconds: 40, preferredTimescale: 600)
        onboardingDemoTimeObserver = player.addBoundaryTimeObserver(
            forTimes: [NSValue(time: demoTriggerTime)],
            queue: .main
        ) { [weak self] in
            ClickyAnalytics.trackOnboardingDemoTriggered()
            self?.performOnboardingDemoInteraction()
        }

        // Fade out and clean up when the video finishes
        onboardingVideoEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            ClickyAnalytics.trackOnboardingVideoCompleted()
            self.onboardingVideoOpacity = 0.0
            // Wait for the 2s fade-out animation to complete before tearing down
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.tearDownOnboardingVideo()
                // After the video disappears, stream in the prompt to try talking
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.startOnboardingPromptStream()
                }
            }
        }
    }

    func tearDownOnboardingVideo() {
        showOnboardingVideo = false
        if let timeObserver = onboardingDemoTimeObserver {
            onboardingVideoPlayer?.removeTimeObserver(timeObserver)
            onboardingDemoTimeObserver = nil
        }
        onboardingVideoPlayer?.pause()
        onboardingVideoPlayer = nil
        if let observer = onboardingVideoEndObserver {
            NotificationCenter.default.removeObserver(observer)
            onboardingVideoEndObserver = nil
        }
    }

    private func startOnboardingPromptStream() {
        let message = "press control + option and introduce yourself"
        onboardingPromptText = ""
        showOnboardingPrompt = true
        onboardingPromptOpacity = 0.0

        withAnimation(.easeIn(duration: 0.4)) {
            onboardingPromptOpacity = 1.0
        }

        var currentIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            guard currentIndex < message.count else {
                timer.invalidate()
                // Auto-dismiss after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    guard self.showOnboardingPrompt else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.onboardingPromptOpacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self.showOnboardingPrompt = false
                        self.onboardingPromptText = ""
                    }
                }
                return
            }
            let index = message.index(message.startIndex, offsetBy: currentIndex)
            self.onboardingPromptText.append(message[index])
            currentIndex += 1
        }
    }

    /// Gradually raises an AVPlayer's volume from its current level to the
    /// target over the specified duration, creating a smooth audio fade-in.
    private func fadeInVideoAudio(player: AVPlayer, targetVolume: Float, duration: Double) {
        let steps = 20
        let stepInterval = duration / Double(steps)
        let volumeIncrement = (targetVolume - player.volume) / Float(steps)
        var stepsRemaining = steps

        Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { timer in
            stepsRemaining -= 1
            player.volume += volumeIncrement

            if stepsRemaining <= 0 {
                timer.invalidate()
                player.volume = targetVolume
            }
        }
    }

    // MARK: - Onboarding Demo Interaction

    private static let onboardingDemoSystemPrompt = """
    you're clicky, a small blue cursor buddy living on the user's screen. you're showing off during onboarding — look at their screen and find ONE specific, concrete thing to point at. pick something with a clear name or identity: a specific app icon (say its name), a specific word or phrase of text you can read, a specific filename, a specific button label, a specific tab title, a specific image you can describe. do NOT point at vague things like "a window" or "some text" — be specific about exactly what you see.

    make a short quirky 3-6 word observation about the specific thing you picked — something fun, playful, or curious that shows you actually read/recognized it. no emojis ever. NEVER quote or repeat text you see on screen — just react to it. keep it to 6 words max, no exceptions.

    CRITICAL COORDINATE RULE: you MUST only pick elements near the CENTER of the screen. your x coordinate must be between 20%-80% of the image width. your y coordinate must be between 20%-80% of the image height. do NOT pick anything in the top 20%, bottom 20%, left 20%, or right 20% of the screen. no menu bar items, no dock icons, no sidebar items, no items near any edge. only things clearly in the middle area of the screen. if the only interesting things are near the edges, pick something boring in the center instead.

    respond with ONLY your short comment followed by the coordinate tag. nothing else. all lowercase.

    format: your comment [POINT:x,y:label]

    the screenshot images are labeled with their pixel dimensions. use those dimensions as the coordinate space. origin (0,0) is top-left. x increases rightward, y increases downward.
    """

    /// Captures a screenshot and asks Claude to find something interesting to
    /// point at, then triggers the buddy's flight animation. Used during
    /// onboarding to demo the pointing feature while the intro video plays.
    func performOnboardingDemoInteraction() {
        // Don't interrupt an active voice response
        guard voiceState == .idle || voiceState == .responding else { return }

        Task {
            do {
                let screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()

                // Only send the cursor screen so Claude can't pick something
                // on a different monitor that we can't point at.
                guard let cursorScreenCapture = screenCaptures.first(where: { $0.isCursorScreen }) else {
                    print("🎯 Onboarding demo: no cursor screen found")
                    return
                }

                let dimensionInfo = " (image dimensions: \(cursorScreenCapture.screenshotWidthInPixels)x\(cursorScreenCapture.screenshotHeightInPixels) pixels)"
                let labeledImages = [(data: cursorScreenCapture.imageData, label: cursorScreenCapture.label + dimensionInfo)]

                let (fullResponseText, _) = try await claudeAPI.analyzeImageStreaming(
                    images: labeledImages,
                    systemPrompt: Self.onboardingDemoSystemPrompt,
                    userPrompt: "look around my screen and find something interesting to point at",
                    onTextChunk: { _ in }
                )

                let parseResult = Self.parsePointingCoordinates(from: fullResponseText)

                guard let pointCoordinate = parseResult.coordinate else {
                    print("🎯 Onboarding demo: no element to point at")
                    return
                }

                let screenshotWidth = CGFloat(cursorScreenCapture.screenshotWidthInPixels)
                let screenshotHeight = CGFloat(cursorScreenCapture.screenshotHeightInPixels)
                let displayWidth = CGFloat(cursorScreenCapture.displayWidthInPoints)
                let displayHeight = CGFloat(cursorScreenCapture.displayHeightInPoints)
                let displayFrame = cursorScreenCapture.displayFrame

                let clampedX = max(0, min(pointCoordinate.x, screenshotWidth))
                let clampedY = max(0, min(pointCoordinate.y, screenshotHeight))
                let displayLocalX = clampedX * (displayWidth / screenshotWidth)
                let displayLocalY = clampedY * (displayHeight / screenshotHeight)
                let appKitY = displayHeight - displayLocalY
                let globalLocation = CGPoint(
                    x: displayLocalX + displayFrame.origin.x,
                    y: appKitY + displayFrame.origin.y
                )

                // Set custom bubble text so the pointing animation uses Claude's
                // comment instead of a random phrase
                detectedElementBubbleText = parseResult.spokenText
                detectedElementScreenLocation = globalLocation
                detectedElementDisplayFrame = displayFrame
                print("🎯 Onboarding demo: pointing at \"\(parseResult.elementLabel ?? "element")\" — \"\(parseResult.spokenText)\"")
            } catch {
                print("⚠️ Onboarding demo error: \(error)")
            }
        }
    }

    // MARK: - ReAct Loop Consent Resume

    /// Called when user approves computer use for the pending ReAct loop turn.
    /// Resumes the loop with isTaskSessionPreApproved = true so input tools are allowed.
    public func approveReActLoopAndResume() {
        guard !pendingReActMessages.isEmpty else { return }
        ClickyLogger.info("[CONSENT_GATE]", "User approved ReAct loop continuation. Resuming with pre-approval.")
        NotchComputerUseConsentWindow.shared.dismiss()
        self.pendingComputerUseRequest = nil
        self.isTaskSessionPreApproved = true

        let msgs = self.pendingReActMessages
        let sysPrompt = self.pendingReActSystemPrompt
        let tools = self.pendingReActNativeTools
        let captures = self.pendingReActScreenCaptures
        let originalTranscript = self.pendingReActOriginalTranscript

        // Clear pending state
        self.pendingReActMessages = []
        self.pendingReActSystemPrompt = ""
        self.pendingReActNativeTools = []
        self.pendingReActScreenCaptures = []
        self.pendingReActOriginalTranscript = ""

        self.voiceState = .processing
        self.hideResponseBubbleImmediately()

        currentResponseTask?.cancel()
        currentResponseTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Restart the full voice processing pipeline with pre-approval
            // The stored messages already include all observation turns done so far;
            // the model will continue from where it left off (now allowed to call input tools)
            self.sendTranscriptToClaudeWithScreenshot(transcript: "[Computer use approved for this turn] " + originalTranscript)
        }
    }

    /// Called when user clicks Allow Once on the consent card for ReAct loop
    public func approveReActLoopOnce() {
        approveReActLoopAndResume()
    }

    /// Called when user clicks Always Allow on the consent card for ReAct loop
    public func alwaysAllowAndResumeReActLoop() {
        Defaults[.alwaysAllowComputerUse] = true
        approveReActLoopAndResume()
    }

    // MARK: - Authentic HeyClicky Computer Use ("Wants to use your Mac")

    public func approveComputerUseOnce() {
        guard let request = pendingComputerUseRequest else { return }
        ClickyLogger.info("[COMPUTER_USE]", "User clicked Allow Once for action: \(request.payload.rawDetails)")
        NotchComputerUseConsentWindow.shared.dismiss()
        self.pendingComputerUseRequest = nil
        self.isTaskSessionPreApproved = true
        self.voiceState = .processing

        if ClickyDeterministicPipeline.shared.pendingConsentContinuation != nil {
            ClickyDeterministicPipeline.shared.resumePendingConsent(approved: true)
            return
        }

        self.hideResponseBubbleImmediately()
        let goal = self.ongoingTaskGoal ?? request.payload.rawDetails

        currentResponseTask?.cancel()
        currentResponseTask = Task { @MainActor in
            await self.executeAndContinueAutonomousLoop(payload: request.payload, initialGoal: goal)
        }
    }

    public func alwaysAllowComputerUse() {
        guard let request = pendingComputerUseRequest else { return }
        ClickyLogger.info("[COMPUTER_USE]", "User enabled Always Allow for action: \(request.payload.rawDetails)")
        Defaults[.alwaysAllowComputerUse] = true
        self.isTaskSessionPreApproved = true
        NotchComputerUseConsentWindow.shared.dismiss()
        self.pendingComputerUseRequest = nil
        self.voiceState = .processing

        if ClickyDeterministicPipeline.shared.pendingConsentContinuation != nil {
            ClickyDeterministicPipeline.shared.resumePendingConsent(approved: true)
            return
        }

        self.hideResponseBubbleImmediately()
        let goal = self.ongoingTaskGoal ?? request.payload.rawDetails

        currentResponseTask?.cancel()
        currentResponseTask = Task { @MainActor in
            await self.executeAndContinueAutonomousLoop(payload: request.payload, initialGoal: goal)
        }
    }

    public func rejectComputerUse() {
        guard let request = pendingComputerUseRequest else { return }
        ClickyLogger.info("[COMPUTER_USE]", "User rejected action: \(request.payload.rawDetails)")
        ClickySoundEngine.shared.play(.close)
        NotchComputerUseConsentWindow.shared.dismiss()
        self.pendingComputerUseRequest = nil
        self.isTaskSessionPreApproved = false
        self.ongoingTaskGoal = nil
        self.voiceState = .idle

        if ClickyDeterministicPipeline.shared.pendingConsentContinuation != nil {
            ClickyDeterministicPipeline.shared.resumePendingConsent(approved: false)
            return
        }

        self.hideResponseBubbleImmediately()
        appendChatMessage(HomeSpaceChatMessage(
            isUser: false,
            text: "Understood, I won't perform this action."
        ))
    }

    public func stopCurrentTask() {
        disarmStreamingWatchdog()
        ClickyLogger.info("[COMPANION]", "User stopped current task / loop")
        grounderTask?.cancel()
        grounderTask = nil
        currentResponseTask?.cancel()
        currentResponseTask = nil
        elevenLabsTTSClient.stopPlayback()
        hideResponseBubbleImmediately()
        isTaskSessionPreApproved = false
        ongoingTaskGoal = nil
        voiceState = .idle
        isShowingStreamingResponse = false
        streamingResponseText = ""
        isHomeSpaceStreaming = false
        homeSpaceStreamingText = ""
        CompanionWindowStreamService.shared.stopStreaming()
        MascotVirtualDesktopService.shared.stopVirtualDesktop()
        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
        ClickySoundEngine.shared.play(.close)
    }

    // MARK: - Continuous Autonomous ReAct Loop (Zero Artificial Limits)

    private func executeAndContinueAutonomousLoop(payload: ComputerUseActionPayload, initialGoal: String) async {
        var currentPayload: ComputerUseActionPayload? = payload
        var stepCount = 0

        ClickyLogger.info("[AUTONOMOUS_LOOP]", "Starting continuous autonomous task loop for goal: \"\(initialGoal)\"")
        self.voiceState = .processing
        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .working)

        // Automatically hide HomeSpace chat studio so it does not block the visual screenshot of TradingView
        let wasHomeSpaceVisible = await MainActor.run {
            CompanionUIHostRegistry.shared?.isHomeSpaceVisible ?? HomeSpaceWindowManager.shared.isVisible
        }
        if wasHomeSpaceVisible {
            await MainActor.run {
                CompanionUIHostRegistry.shared?.hideHomeSpace() ?? HomeSpaceWindowManager.shared.hide()
            }
            ClickyLogger.info("[AUTONOMOUS_LOOP]", "Temporarily hid HomeSpace chat window to ensure unobstructed visual analysis")
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        defer {
            self.voiceState = .idle
            self.isTaskSessionPreApproved = false
            self.ongoingTaskGoal = nil
            let currentStatus = CompanionRosterStore.shared.activeCompanion.status
            if currentStatus == .working {
                CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
            }
            if wasHomeSpaceVisible {
                Task { @MainActor in
                    CompanionUIHostRegistry.shared?.showHomeSpace() ?? HomeSpaceWindowManager.shared.show()
                }
            }
        }

        // Verify Accessibility permission upfront so user is alerted if macOS blocks keystrokes/clicks
        if !WindowPositionManager.hasAccessibilityPermission() {
            ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Accessibility permission is missing (AXIsProcessTrusted = false)! Prompting user via System Settings.")
            WindowPositionManager.requestAccessibilityPermission()
            WindowPositionManager.openAccessibilitySettings()
            self.appendChatMessage(HomeSpaceChatMessage(
                isUser: false,
                text: "⚠️ Accessibility permission is required to interact with the screen and control TradingView physically. System Settings has been opened — please enable 'boringNotch' under Privacy & Security > Accessibility."
            ))
        }

        while let activePayload = currentPayload {
            guard !Task.isCancelled else {
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "Task loop cancelled by user")
                self.voiceState = .idle
                self.isTaskSessionPreApproved = false
                self.ongoingTaskGoal = nil
                CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
                return
            }

            stepCount += 1
            ClickyLogger.info("[AUTONOMOUS_LOOP]", "Executing Step #\(stepCount): \(activePayload.rawDetails) [Type: \(activePayload.type.rawValue)]")

            let targetTf = (activePayload.tradingViewPayload?.actionType == .timeframe) ? activePayload.tradingViewPayload?.parameter : nil

            // 1. Physically execute the current action
            await ComputerUsePhysicalExecutor.shared.execute(payload: activePayload)

            guard !Task.isCancelled else { return }

            // 2. Allow UI & graphics to settle
            let settleDelay: UInt64 = (activePayload.type == .launchApp) ? 1_400_000_000 : 750_000_000
            try? await Task.sleep(nanoseconds: settleDelay)

            guard !Task.isCancelled else { return }

            // Reset streaming accumulators for next turn without killing on-screen bubble
            self.hasTriggeredStreamingFlight = false
            self.accumulatedRawStreamingText = ""

            // 3. Capture updated screen state
            let screenCaptures: [CompanionScreenCapture]
            do {
                screenCaptures = try await CompanionScreenCaptureUtility.captureAllScreensAsJPEG()
            } catch {
                ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Screen capture failed: \(error.localizedDescription)")
                screenCaptures = []
            }

            let labeledImages = screenCaptures.map { capture in
                let dimensionInfo = " (image dimensions: \(capture.screenshotWidthInPixels)x\(capture.screenshotHeightInPixels) pixels)"
                return (data: capture.imageData, label: capture.label + dimensionInfo)
            }

            let activeWorkSurface = ActiveWorkSurfaceManager.getActiveWorkSurface(queryHint: initialGoal)

            // Fetch live BingX perpetual swap multi-timeframe market data & concrete candle proof (ONLY for TradingView tasks)
            let isTradingIntent = activePayload.tradingViewPayload != nil ||
                                  activePayload.targetApp?.localizedCaseInsensitiveContains("TradingView") == true ||
                                  initialGoal.localizedCaseInsensitiveContains("chart") ||
                                  initialGoal.localizedCaseInsensitiveContains("trading") ||
                                  initialGoal.localizedCaseInsensitiveContains("crypto") ||
                                  initialGoal.localizedCaseInsensitiveContains("analis")
            var bingXMarketContext = ""
            if isTradingIntent {
                let targetCoin = Self.extractTradingSymbol(from: initialGoal, activeWorkSurface: activeWorkSurface)
                if let mtf = try? await BingXMarketDataEngine.shared.fetchMultiTimeframeAnalysis(symbol: targetCoin) {
                    bingXMarketContext = """

                    \(mtf.promptContextString())
                    """
                    ClickyLogger.info("[AUTONOMOUS_LOOP]", "Injected BingX Multi-Timeframe TA context for \(targetCoin): Last $\(Int(mtf.lastPrice)), Direction: \(mtf.overallDirection.rawValue), WinRate: \(mtf.winRatePercent)%, Trigger: \(mtf.triggerCandleProof.timestampWIB) WIB")
                }
            }

            // 4. Formulate autonomous feedback prompt with Strict Visual Verification Gate & Meta-Cognitive Self-Healing
            let targetTfHint = targetTf != nil ? " (Target timeframe: \(targetTf!))" : ""
            let activeSlug = CompanionRosterStore.shared.allCompanions.first(where: { $0.id == activeBuddy.id })?.slug
                             ?? activeBuddy.name.lowercased().replacingOccurrences(of: " ", with: "-")

            // Ground-Truth System Verification Notice (Anti-Hallucination Gate)
            var factualVerificationNotice = ""
            if let targetAppName = activePayload.targetApp,
               targetAppName.lowercased() != "active app",
               targetAppName.lowercased() != "current" {
                let cleanApp = targetAppName.trimmingCharacters(in: .whitespaces).lowercased()
                let isStillRunning = NSWorkspace.shared.runningApplications.contains {
                    ($0.localizedName?.localizedCaseInsensitiveContains(cleanApp) == true ||
                     $0.bundleIdentifier?.localizedCaseInsensitiveContains(cleanApp) == true) && !$0.isTerminated
                }
                let detailsLower = activePayload.rawDetails.lowercased()
                let isClose = detailsLower.contains("close") || detailsLower.contains("quit") || detailsLower.contains("tutup")
                if isClose {
                    if !isStillRunning {
                        factualVerificationNotice = "\nGROUND-TRUTH SYSTEM VERIFICATION:\n[VERIFIED: '\(targetAppName)' has been confirmed TERMINATED and closed. Its process and windows no longer exist.]\n"
                    } else {
                        factualVerificationNotice = "\nGROUND-TRUTH SYSTEM VERIFICATION:\n[WARNING: '\(targetAppName)' is STILL RUNNING in the operating system. Close/quit was not completed. You must NOT claim it is closed.]\n"
                    }
                }
            }

            let loopPrompt = """
            [AUTONOMOUS TASK IN PROGRESS - STEP #\(stepCount)]:
            Last action executed: "\(activePayload.rawDetails)"\(targetTfHint).
            User's primary objective: "\(initialGoal)"
            \(bingXMarketContext)
            \(factualVerificationNotice)
            OBSTACLE & MODAL SELF-HEALING DIRECTIVE:
            1. Look at the attached screenshot: Is there an unexpected popup, modal, dialog, or text box blocking your view?
            2. If YES, close or dismiss it via [ACTION:tv_close_modal] or [ACTION:tv_clear] before doing any analysis or drawing.

            COMPANION AUTONOMOUS SOP & PROTOCOL DIRECTIVE:
            You are operating autonomously as "\(activeBuddy.name)" (\(activeBuddy.roleDescription)).
            Review the attached screenshot, the latest market data context above, and strictly follow the protocol, capabilities, and standing rules defined in your companion specification markdown (\(activeSlug).md).

            DECISION RULES:
            - If you still need to inspect other timeframes, switch symbols, clear old clutter ([ACTION:tv_clear]), or draw tools on the chart ([ACTION:tv_tool:...]), output ONE action tag [ACTION:...] along with your concrete empirical findings for this step (e.g. [TEMUAN 1H MAKRO], [TEMUAN 15M STRUKTUR], or [TEMUAN 5M TRIGGER]) and a short natural spoken sentence for audio.
            - DILARANG KERAS mencetak tabel pada langkah 1, 2, 3, atau 4! Tabel HANYA boleh dicetak pada langkah terakhir setelah seluruh timeframe (1H, 15m, 5m) diinspeksi dan tool posisi selesai dipasang di chart.
            - If you have completed the required inspections and chart actions according to your markdown specification, DO NOT output any action tags! Instead, synthesize all previous findings without bias and output your complete final report with the structured tables specified in your markdown specification.
            - Never use raw '###' header characters. Always start with a 1-sentence spoken summary for TTS/audio.
            """

            let historyForAPI = conversationHistory.map { entry in
                (userPlaceholder: entry.userTranscript, assistantResponse: entry.assistantResponse)
            }

            do {
                let (fullResponseText, _) = try await claudeAPI.analyzeImageStreaming(
                    images: labeledImages,
                    systemPrompt: Self.buildCompanionVoiceResponseSystemPrompt(workSurface: activeWorkSurface, buddy: self.activeBuddy, isPreApproved: true),
                    conversationHistory: historyForAPI,
                    userPrompt: loopPrompt,
                    onTextChunk: { [weak self] chunk in
                        Task { @MainActor in
                            self?.showStreamingChunk(chunk, screenCaptures: screenCaptures)
                        }
                    }
                )

                guard !Task.isCancelled else { return }

                // Check if the companion is requesting a new missing feature
                if let req = Self.extractFeatureRequest(from: fullResponseText) {
                    ClickyLogger.warning("[AUTONOMOUS_LOOP]", "Companion requested new feature: \(req.featureName) — Reason: \(req.reason)")
                    let politeMessage = """
                    ⚠️ **This feature is not available yet.**

                    I need the **\(req.featureName)** capability (\(req.reason)) to complete this task. This feature request has been saved to the backlog.
                    """
                    self.saveFeatureRequest(featureName: req.featureName, reason: req.reason, goal: initialGoal)
                    ClickySoundEngine.shared.play(.question)
                    self.finishStreamingResponseText(politeMessage)
                    self.appendChatMessage(HomeSpaceChatMessage(isUser: false, text: politeMessage))
                    self.voiceState = .idle
                    self.isTaskSessionPreApproved = false
                    self.ongoingTaskGoal = nil
                    CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
                    return
                }

                let parseResult = Self.parsePointingCoordinates(from: fullResponseText)
                var spokenText = parseResult.spokenText

                let (cleanedAfterRequest, computerUseReq) = Self.parseComputerUseRequest(from: spokenText, activeBuddy: self.activeBuddy)
                let (cleanedAfterAction, proposedAction) = Self.parseProposedAction(from: cleanedAfterRequest)

                var nextPayload: ComputerUseActionPayload? = nil
                if let req = computerUseReq {
                    spokenText = cleanedAfterRequest
                    nextPayload = req.payload
                } else if let action = proposedAction {
                    spokenText = cleanedAfterAction
                    let tvPayload = Self.extractTradingViewPayload(from: fullResponseText)
                    nextPayload = ComputerUseActionPayload(
                        type: tvPayload != nil ? .tradingViewAction : (action.actionType == .keyCombo ? .keyCombo : (action.actionType == .launchApp ? .launchApp : .click)),
                        targetCoordinate: action.targetCoordinate,
                        targetApp: action.appName,
                        tradingViewPayload: tvPayload,
                        rawDetails: action.title
                    )
                }

                if let next = nextPayload {
                    // Next step required: log, post progress snippet if available, and continue loop
                    ClickyLogger.info("[AUTONOMOUS_LOOP]", "Step #\(stepCount) completed. Next action requested: \(next.rawDetails)")
                    let progressSnippet = Self.stripTechnicalTags(from: spokenText)
                    if !progressSnippet.isEmpty {
                        ClickyLogger.info("[AUTONOMOUS_LOOP]", "Step #\(stepCount) note: \"\(progressSnippet)\"")
                        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: progressSnippet))
                        conversationHistory.append((
                            userTranscript: "Step \(stepCount): \(activePayload.rawDetails)",
                            assistantResponse: progressSnippet,
                            rawResponseWithTags: spokenText,
                            groundingHit: true
                        ))
                        finishStreamingResponseText(progressSnippet)

                        // Option 1A: Dynamic reading delay between consecutive autonomous steps (min 3.5s)
                        let words = progressSnippet.split { $0.isWhitespace }.count
                        let paceDuration = max(3.5, min(6.5, 1.5 + Double(words) * 0.25))
                        try? await Task.sleep(nanoseconds: UInt64(paceDuration * 1_000_000_000))
                    }
                    currentPayload = next
                } else {
                    // RUNTIME SOP CONTRACT VALIDATOR (Loop Premature Conclusion Guard):
                    let isFuturesScout = self.activeBuddy.name.localizedCaseInsensitiveContains("Futures") ||
                                         self.activeBuddy.roleDescription.localizedCaseInsensitiveContains("Futures") ||
                                         self.activeBuddy.roleDescription.localizedCaseInsensitiveContains("Analyst")
                    let hasTableMarkup = fullResponseText.contains("| No |") || fullResponseText.contains("| Koin |") || fullResponseText.contains("| Setup |") || (fullResponseText.contains("|---") && fullResponseText.contains("| :---"))

                    if isFuturesScout && hasTableMarkup && stepCount < 4 {
                        let violationError = """
                        ⚠️ **SOP CONTRACT VIOLATION DETECTED**

                        Companion melanggar spesifikasi SOP (`futures-scout.md`):
                        • **Kesalahan**: Menyelesaikan analisis dan mencetak tabel secara prematur pada langkah #\(stepCount) sebelum menyelesaikan siklus inspeksi multi-timeframe (1H, 15m, 5m) dan penempatan tool di chart.
                        • **Aturan SOP yang Dilanggar**: SOP mewajibkan penalaran berurutan (Sequential Thinking) melalui audit 1H, 15m, 5m, dan penempatan tool fisik sebelum mencetak tabel akhir.
                        • **Tindakan Sistem**: Sesuai instruksi mutlak pengguna ("companion dilarang keras melanggar MD nya, jika dilanggar kirimkan errornya, bukan hasil pelanggaran"), hasil kesimpulan prematur ini **DITOLAK**.
                        """
                        ClickyLogger.error("[SOP_VALIDATOR]", "SOP Violation intercepted at step #\(stepCount): Premature conclusion tables. Rejecting illegal output.")
                        finishStreamingResponseText(violationError)
                        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: violationError))
                        voiceState = .idle
                        isTaskSessionPreApproved = false
                        ongoingTaskGoal = nil
                        CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .idle)
                        return
                    }

                    // No further action tags: The autonomous analysis is completely finished!
                    let cleanFinal = Self.stripTechnicalTags(from: spokenText)
                    ClickyLogger.success("[AUTONOMOUS_LOOP]", "Autonomous task loop completed after \(stepCount) steps")
                    finishStreamingResponseText(cleanFinal)
                    currentPayload = nil

                    // Save final analysis to history & chat
                    conversationHistory.append((
                        userTranscript: initialGoal,
                        assistantResponse: cleanFinal,
                        rawResponseWithTags: fullResponseText,
                        groundingHit: true
                    ))
                    appendChatMessage(HomeSpaceChatMessage(isUser: false, text: cleanFinal))

                    // Chime celebration
                    ClickySoundEngine.shared.play(.done)
                    CompanionRosterStore.shared.updateCompanionStatus(id: activeBuddy.id, status: .done)

                    // Speak conclusion if voice output is enabled (filtering out table markdown for speech)
                    let isVoiceOutputEnabled = Defaults[.cursorAssistantVoiceOutputEnabled]
                    let spokenSummary = Self.stripTableForSpeech(from: cleanFinal)
                    if isVoiceOutputEnabled && !spokenSummary.isEmpty {
                        do {
                            try await elevenLabsTTSClient.speakText(spokenSummary)
                            voiceState = .responding
                        } catch {
                            let synthesizer = NSSpeechSynthesizer()
                            synthesizer.startSpeaking(spokenSummary)
                            voiceState = .responding
                        }
                    } else {
                        voiceState = .idle
                    }

                    // Reset session pre-approval and goal
                    self.isTaskSessionPreApproved = false
                    self.ongoingTaskGoal = nil
                }
            } catch is CancellationError {
                ClickyLogger.info("[AUTONOMOUS_LOOP]", "Loop cancelled during API call")
                self.voiceState = .idle
                self.isTaskSessionPreApproved = false
                self.ongoingTaskGoal = nil
                return
            } catch {
                ClickyLogger.error("[AUTONOMOUS_LOOP]", "Error during autonomous loop API call: \(error.localizedDescription)")
                self.voiceState = .idle
                self.isTaskSessionPreApproved = false
                self.ongoingTaskGoal = nil
                speakCreditsErrorFallback()
                return
            }
        }

        self.voiceState = .idle
        self.isTaskSessionPreApproved = false
        self.ongoingTaskGoal = nil
    }

    public func proposeAction(_ action: ComputerUseProposedAction) {
        self.proposedComputerUseAction = action
        ClickySoundEngine.shared.play(.question)
    }

    public func approveComputerUseAction() {
        guard let action = proposedComputerUseAction else { return }
        ClickyLogger.info("[ACTION]", "User approved computer use action: \(action.title)")

        switch action.actionType {
        case .click:
            if let target = action.targetCoordinate {
                executeMouseClick(at: target)
            }
        case .keyCombo:
            executeKeyCombo(key: 0x0D /* 'w' */, flags: .maskCommand)
        case .launchApp:
            if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.\(action.appName.lowercased())") ??
                            NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/System/Applications/\(action.appName).app")) {
                NSWorkspace.shared.openApplication(at: appUrl, configuration: .init(), completionHandler: nil)
            }
        case .runScript:
            break
        }

        ClickySoundEngine.shared.play(.done)
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: "Done! I've executed \"\(action.title)\"."))
        proposedComputerUseAction = nil
    }

    public func rejectComputerUseAction() {
        guard let action = proposedComputerUseAction else { return }
        ClickyLogger.info("[ACTION]", "User cancelled action: \(action.title)")
        ClickySoundEngine.shared.play(.close)
        appendChatMessage(HomeSpaceChatMessage(isUser: false, text: "Understood, I won't execute \"\(action.title)\"."))
        proposedComputerUseAction = nil
    }

    public func executeMouseClick(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)

        moveEvent?.post(tap: .cghidEventTap)
        usleep(30000)
        downEvent?.post(tap: .cghidEventTap)
        usleep(30000)
        upEvent?.post(tap: .cghidEventTap)
    }

    public func executeKeyCombo(key: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        usleep(30000)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Crypto Symbol Extractor Helper (Universal Dynamic Coin Detection)

    public static func extractTradingSymbol(from text: String, activeWorkSurface: ActiveWorkSurface? = nil) -> String {
        let lower = text.lowercased()

        // 1. Explicit user prompt priority (common base coins)
        let commonCoins = [
            "btc", "eth", "sol", "doge", "xrp", "ada", "pepe", "bnb", "avax", "link",
            "sui", "near", "apt", "fet", "wif", "shib", "render", "ondo", "kas", "tao",
            "inj", "sei", "arb", "op", "tia", "bonk", "floki", "ton", "dot", "ltc", "bch"
        ]
        for coin in commonCoins {
            if lower.range(of: "\\b\(coin)\\b", options: .regularExpression) != nil ||
               lower.contains("\(coin)usdt") ||
               lower.contains("\(coin)-usdt") {
                return "\(coin.uppercased())-USDT"
            }
        }

        // Strict regex for custom coin ticker explicitly paired with USDT/USD/PERP (e.g. "INJUSDT", "TAO-USDT", "ETH.P")
        let promptPattern = #"\b([A-Za-z0-9]{2,10})[-/:](?:USDT|USD|PERP)(?:\.P)?\b|\b([A-Za-z0-9]{2,10})(?:USDT|USD)(?:\.P)?\b"#
        if let regex = try? NSRegularExpression(pattern: promptPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
            let stopWords: Set<String> = ["CHART", "ANALISA", "ANALISIS", "SETUP", "TRADE", "TRADING", "TIME", "FRAME", "LONG", "SHORT", "WAIT", "BINGX", "SWAP", "PERP", "CEK", "TOLONG", "COBA"]
            for match in matches {
                let range = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
                if range.location != NSNotFound {
                    let matchedStr = nsText.substring(with: range).uppercased()
                    if !stopWords.contains(matchedStr) && matchedStr.count >= 2 && matchedStr.count <= 10 && !matchedStr.allSatisfy({ $0.isNumber }) {
                        return "\(matchedStr)-USDT"
                    }
                }
            }
        }

        // 2. Active Window Title Auto-Detection (ONLY for TradingView Desktop)
        let isTVActive = activeWorkSurface?.appName.localizedCaseInsensitiveContains("TradingView") == true
        let windowTitle: String = {
            if isTVActive, let title = activeWorkSurface?.windowTitle, !title.isEmpty, title != "TradingView" {
                return title
            }
            let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements)
            if let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                for info in infoList {
                    let owner = info[kCGWindowOwnerName as String] as? String ?? ""
                    let layer = info[kCGWindowLayer as String] as? Int ?? -1
                    if layer == 0 && owner.contains("TradingView") {
                        let name = info[kCGWindowName as String] as? String ?? ""
                        if !name.isEmpty && name != "TradingView" {
                            return name
                        }
                    }
                }
            }
            return ""
        }()

        if !windowTitle.isEmpty {
            ClickyLogger.info("[COMPANION]", "Inspecting TradingView window title for active ticker: '\(windowTitle)'")
            // Match pattern like "BTCUSDT.P / Unnamed" or "SOLUSDT / Unnamed" or "ETHUSDT"
            let titlePattern = #"([A-Za-z0-9]{2,10})(?:USDT|USD)(?:\.P)?"#
            if let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
               let match = titleRegex.firstMatch(in: windowTitle, options: [], range: NSRange(location: 0, length: (windowTitle as NSString).length)) {
                let coin = (windowTitle as NSString).substring(with: match.range(at: 1)).uppercased()
                let nonCoin: Set<String> = ["TRADINGVIEW", "UNNAMED", "CHART", "LAYOUT"]
                if !nonCoin.contains(coin) && coin.count >= 2 && !coin.allSatisfy({ $0.isNumber }) {
                    ClickyLogger.success("[COMPANION]", "Auto-detected active coin from TradingView window title: '\(coin)-USDT'")
                    return "\(coin)-USDT"
                }
            }
        }

        // 3. Graceful Fallback
        return "BTC-USDT"
    }

    // MARK: - Companion Proactive Feature Request Protocol

    public struct CompanionFeatureRequest: Codable {
        public let id: String
        public let timestamp: String
        public let companion: String
        public let goal: String
        public let feature: String
        public let reason: String
    }

    private static func extractFeatureRequest(from text: String) -> (featureName: String, reason: String)? {
        let pattern = #"(?i)\[REQUEST_FEATURE:([^:\]]+):([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nameRange = Range(match.range(at: 1), in: text),
              let reasonRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        let featureName = String(text[nameRange]).trimmingCharacters(in: .whitespaces)
        let reason = String(text[reasonRange]).trimmingCharacters(in: .whitespaces)
        return (featureName, reason)
    }

    private func saveFeatureRequest(featureName: String, reason: String, goal: String) {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let folder = homeDir.appendingPathComponent(".izanotchy")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("feature_requests.json")

        let newItem = CompanionFeatureRequest(
            id: UUID().uuidString,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            companion: self.activeBuddy.name,
            goal: goal,
            feature: featureName,
            reason: reason
        )

        var existingItems: [CompanionFeatureRequest] = []
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([CompanionFeatureRequest].self, from: data) {
            existingItems = decoded
        }
        existingItems.append(newItem)
        if let encoded = try? JSONEncoder().encode(existingItems) {
            try? encoded.write(to: fileURL)
            ClickyLogger.success("[FEATURE_REQUEST]", "Saved companion feature request to \(fileURL.path)")
        }
    }

    // MARK: - TradingView Payload Extractor Helper

    private static func parseSingleTradingViewMatch(_ match: NSTextCheckingResult, in text: String) -> TradingViewActionPayload? {
        guard let subTypeRange = Range(match.range(at: 1), in: text) else { return nil }
        let subType = String(text[subTypeRange]).lowercased()
        let param1: String = (match.numberOfRanges > 2 && match.range(at: 2).location != NSNotFound) ? String(text[Range(match.range(at: 2), in: text)!]).trimmingCharacters(in: .whitespaces) : ""
        let param2: String? = (match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound) ? String(text[Range(match.range(at: 3), in: text)!]).trimmingCharacters(in: .whitespaces) : nil

        switch subType {
        case "setup_workspace", "prepare_workspace", "init_workspace":
            let fullSymbol = (param2 != nil && !param2!.isEmpty) ? "\(param1):\(param2!)" : param1
            return TradingViewActionPayload(
                actionType: .setupWorkspace,
                parameter: fullSymbol.isEmpty ? nil : fullSymbol,
                rawDetails: "Workspace Hygiene & Symbol Alignment"
            )

        case "close_modal", "dismiss", "dismiss_modal":
            return TradingViewActionPayload(
                actionType: .closeModal,
                rawDetails: "Dismiss active modal or popup"
            )

        case "toggle_sidebar", "close_sidebar", "sidebar":
            return TradingViewActionPayload(
                actionType: .toggleSidebar,
                rawDetails: "Toggle/Close Watchlist Sidebar"
            )

        case "maximize", "fullscreen":
            return TradingViewActionPayload(
                actionType: .maximize,
                rawDetails: "Maximize TradingView window"
            )

        case "reset_scale", "autoscale", "scale":
            return TradingViewActionPayload(
                actionType: .resetScale,
                rawDetails: "Auto-Fit and Reset Chart Scale (⌥+R)"
            )

        case "tool":
            var pts: [CGPoint] = []
            if let pointsStr = param2 {
                pts = pointsStr.split(separator: "|").compactMap { pair in
                    let coords = pair.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                    if coords.count >= 2 { return CGPoint(x: coords[0], y: coords[1]) }
                    return nil
                }
            }
            return TradingViewActionPayload(
                actionType: .drawWithTool,
                toolName: param1,
                points: pts.isEmpty ? nil : pts,
                rawDetails: "Draw \(param1) on TradingView"
            )

        case "timeframe":
            return TradingViewActionPayload(
                actionType: .timeframe,
                parameter: param1,
                rawDetails: "Switch timeframe to \(param1)"
            )

        case "symbol":
            let fullSymbol = (param2 != nil && !param2!.isEmpty) ? "\(param1):\(param2!)" : param1
            return TradingViewActionPayload(
                actionType: .symbol,
                parameter: fullSymbol,
                rawDetails: "Switch symbol to \(fullSymbol)"
            )

        case "indicator":
            return TradingViewActionPayload(
                actionType: .addIndicator,
                parameter: param1,
                rawDetails: "Add indicator \(param1)"
            )

        case "pine":
            let code = param2 != nil ? "\(param1):\(param2!)" : param1
            return TradingViewActionPayload(
                actionType: .injectPineScript,
                pineScript: code,
                rawDetails: "Inject Pine Script"
            )

        case "clear", "cleardrawings", "clear_drawings":
            return TradingViewActionPayload(
                actionType: .clearDrawings,
                rawDetails: "Clear drawings on chart"
            )

        default:
            return TradingViewActionPayload(
                actionType: .timeframe,
                parameter: param1,
                rawDetails: "TradingView action: \(param1)"
            )
        }
    }

    private static func extractTradingViewPayload(from text: String) -> TradingViewActionPayload? {
        // Special robust extraction for Pine Script (Tier 4) which can contain colons, brackets, or newlines
        if let pineStartRange = text.range(of: #"(?i)\[ACTION:tv_pine:"#, options: .regularExpression) {
            let remainder = text[pineStartRange.upperBound...]
            var depth = 1
            var scriptEnd: String.Index? = nil
            for idx in remainder.indices {
                if remainder[idx] == "[" {
                    depth += 1
                } else if remainder[idx] == "]" {
                    depth -= 1
                    if depth == 0 {
                        scriptEnd = idx
                        break
                    }
                }
            }
            if let endIdx = scriptEnd {
                let script = String(remainder[..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                return TradingViewActionPayload(
                    actionType: .injectPineScript,
                    pineScript: script,
                    rawDetails: "Inject Dynamic Pine Script v5"
                )
            }
        }

        let tvPattern = #"(?i)\[ACTION:tv_([a-z_]+)(?::([^:\]]+))?(?::([^\]]+))?\]"#
        guard let tvRegex = try? NSRegularExpression(pattern: tvPattern, options: []) else { return nil }
        let matches = tvRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return nil }

        let payloads = matches.compactMap { parseSingleTradingViewMatch($0, in: text) }
        guard !payloads.isEmpty else { return nil }

        if payloads.count == 1 {
            return payloads[0]
        } else {
            // Multi-action chained sequence
            let titles = payloads.map { $0.rawDetails }.joined(separator: " ➔ ")
            return TradingViewActionPayload(
                actionType: .chain,
                subActions: payloads,
                rawDetails: "Multi-action sequence: \(titles)"
            )
        }
    }

    static func parseProposedAction(from responseText: String) -> (cleanedText: String, action: ComputerUseProposedAction?) {
        // Robust extraction for tv_pine with bracket depth counting
        if let pineStartRange = responseText.range(of: #"(?i)\[ACTION:tv_pine:"#, options: .regularExpression) {
            let remainder = responseText[pineStartRange.upperBound...]
            var depth = 1
            var scriptEnd: String.Index? = nil
            for idx in remainder.indices {
                if remainder[idx] == "[" {
                    depth += 1
                } else if remainder[idx] == "]" {
                    depth -= 1
                    if depth == 0 {
                        scriptEnd = idx
                        break
                    }
                }
            }
            if let endIdx = scriptEnd {
                let fullTagRange = pineStartRange.lowerBound...endIdx
                let cleaned = responseText.replacingCharacters(in: fullTagRange, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let tvPayload = extractTradingViewPayload(from: responseText) {
                    let action = ComputerUseProposedAction(
                        category: "TradingView",
                        appName: "TradingView",
                        appIcon: "chart.line.uptrend.xyaxis",
                        title: tvPayload.rawDetails,
                        details: "TradingView automation: \(tvPayload.rawDetails). Izanotchy will execute this action upon your confirmation.",
                        targetCoordinate: nil,
                        actionType: .runScript
                    )
                    return (cleaned, action)
                }
            }
        }

        let tvPattern = #"(?i)\[ACTION:tv_([a-z_]+)(?::([^:\]]+))?(?::([^\]]+))?\]"#
        if let tvRegex = try? NSRegularExpression(pattern: tvPattern, options: []),
           let match = tvRegex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)) {
            let cleaned = tvRegex.stringByReplacingMatches(
                in: responseText,
                options: [],
                range: NSRange(responseText.startIndex..., in: responseText),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            if let tvPayload = extractTradingViewPayload(from: responseText) {
                let action = ComputerUseProposedAction(
                    category: "TradingView",
                    appName: "TradingView",
                    appIcon: "chart.line.uptrend.xyaxis",
                    title: tvPayload.rawDetails,
                    details: "TradingView automation: \(tvPayload.rawDetails). Izanotchy will execute this action upon your confirmation.",
                    targetCoordinate: nil,
                    actionType: .runScript
                )
                return (cleaned, action)
            }
        }

        let actionPattern = #"(?i)\[ACTION:([a-z_]+):([^:\]]+):([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: actionPattern, options: []),
              let match = regex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)) else {
            return (responseText, nil)
        }

        let cleaned = regex.stringByReplacingMatches(
            in: responseText,
            options: [],
            range: NSRange(responseText.startIndex..., in: responseText),
            withTemplate: ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard match.numberOfRanges >= 4,
              let typeRange = Range(match.range(at: 1), in: responseText),
              let targetRange = Range(match.range(at: 2), in: responseText),
              let descRange = Range(match.range(at: 3), in: responseText) else {
            return (cleaned, nil)
        }

        let actionTypeStr = String(responseText[typeRange]).lowercased()
        let targetStr = String(responseText[targetRange]).trimmingCharacters(in: .whitespaces)
        let descStr = String(responseText[descRange]).trimmingCharacters(in: .whitespaces)

        let actionType: ComputerUseProposedAction.ActionType
        switch actionTypeStr {
        case "click": actionType = .click
        case "key_combo", "shortcut": actionType = .keyCombo
        case "launch", "launch_app", "open_app": actionType = .launchApp
        default: actionType = .click
        }

        var parsedCoordinate: CGPoint? = nil
        let parts = targetStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count >= 2 {
            parsedCoordinate = CGPoint(x: parts[0], y: parts[1])
        }

        // Robust target app resolution:
        var resolvedAppName = "Active App"
        if actionType == .launchApp {
            resolvedAppName = targetStr
        } else if parsedCoordinate == nil && !targetStr.isEmpty && targetStr.lowercased() != "current" && targetStr.lowercased() != "active app" {
            resolvedAppName = targetStr
        } else if let detected = ComputerUsePhysicalExecutor.resolveTargetAppName(appName: nil, details: "\(descStr) \(responseText)") {
            resolvedAppName = detected
        }

        let action = ComputerUseProposedAction(
            category: actionType == .launchApp ? "Application" : "System Action",
            appName: resolvedAppName,
            appIcon: actionType == .click ? "cursorarrow.click.2" : (actionType == .keyCombo ? "keyboard" : "macwindow"),
            title: descStr.isEmpty ? "Action on \(resolvedAppName)" : descStr,
            details: "Target: \(resolvedAppName). Izanotchy will safely perform this action upon your confirmation.",
            targetCoordinate: parsedCoordinate,
            actionType: actionType
        )
        return (cleaned, action)
    }

    static func parseComputerUseRequest(from responseText: String, activeBuddy: BuddySession?) -> (cleanedText: String, request: ComputerUseRequest?) {
        // 1. Check for <COMPUTER_USE_REQUEST>...</COMPUTER_USE_REQUEST>
        let requestPattern = #"(?s)<COMPUTER_USE_REQUEST>(.*?)</COMPUTER_USE_REQUEST>"#
        guard let requestRegex = try? NSRegularExpression(pattern: requestPattern, options: []),
              let requestMatch = requestRegex.firstMatch(in: responseText, range: NSRange(responseText.startIndex..., in: responseText)),
              let bodyRange = Range(requestMatch.range(at: 1), in: responseText) else {
            // Check if there is a raw [ACTION:...] without the wrapper tags
            let (cleanedRaw, rawAction) = parseProposedAction(from: responseText)
            if let action = rawAction {
                let tvPayload = extractTradingViewPayload(from: responseText)
                let payload = ComputerUseActionPayload(
                    type: tvPayload != nil ? .tradingViewAction : (action.actionType == .keyCombo ? .keyCombo : (action.actionType == .launchApp ? .launchApp : .click)),
                    targetCoordinate: action.targetCoordinate,
                    targetApp: action.appName,
                    tradingViewPayload: tvPayload,
                    rawDetails: action.title
                )
                let req = ComputerUseRequest(
                    companionId: activeBuddy?.id,
                    companionName: activeBuddy?.name ?? "Shippy",
                    companionMood: activeBuddy?.mood ?? .happy,
                    cloudColorHex: activeBuddy?.avatarColorHex ?? "#38BDF8",
                    ringColorHex: activeBuddy?.ringColorHex ?? "#BAE6FD",
                    heading: tvPayload != nil ? "TradingView Chart Action" : "Wants to use your Mac",
                    bodyText: action.details.isEmpty ? action.title : action.details,
                    payload: payload
                )
                return (cleanedRaw, req)
            }
            return (responseText, nil)
        }

        let innerContent = String(responseText[bodyRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        var actionPayload = ComputerUseActionPayload(type: .click, rawDetails: innerContent)
        var cleanedInner = innerContent

        // 2a. Check for TradingView actions [ACTION:tv_...]
        if let tvPayload = extractTradingViewPayload(from: innerContent) {
            actionPayload = ComputerUseActionPayload(
                type: .tradingViewAction,
                targetApp: "TradingView",
                tradingViewPayload: tvPayload,
                rawDetails: tvPayload.rawDetails
            )
            let tvPattern = #"(?i)\[ACTION:tv_([a-z_]+):([^:\]]+)(?::([^\]]+))?\]"#
            if let tvRegex = try? NSRegularExpression(pattern: tvPattern, options: []) {
                cleanedInner = tvRegex.stringByReplacingMatches(
                    in: innerContent,
                    options: [],
                    range: NSRange(innerContent.startIndex..., in: innerContent),
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            // 2b. Standard [ACTION:type:target:details]
            let actionPattern = #"(?i)\[ACTION:([a-z_]+):([^:\]]+):([^\]]+)\]"#
            if let actionRegex = try? NSRegularExpression(pattern: actionPattern, options: []),
               let actionMatch = actionRegex.firstMatch(in: innerContent, range: NSRange(innerContent.startIndex..., in: innerContent)) {
                if let typeRange = Range(actionMatch.range(at: 1), in: innerContent),
                   let targetRange = Range(actionMatch.range(at: 2), in: innerContent),
                   let detailsRange = Range(actionMatch.range(at: 3), in: innerContent) {
                    let typeStr = String(innerContent[typeRange]).lowercased()
                    let targetStr = String(innerContent[targetRange]).trimmingCharacters(in: .whitespaces)
                    let detailsStr = String(innerContent[detailsRange]).trimmingCharacters(in: .whitespaces)

                    let actType: ComputerUseActionPayload.ActionType
                    switch typeStr {
                    case "click": actType = .click
                    case "right_click", "rightclick": actType = .rightClick
                    case "double_click", "doubleclick": actType = .doubleClick
                    case "type", "type_text", "typetext": actType = .typeText
                    case "shortcut", "key_combo", "keycombo": actType = .keyCombo
                    case "launch", "open_app", "launch_app": actType = .launchApp
                    case "scroll": actType = .scroll
                    default: actType = .click
                    }

                    var targetCoord: CGPoint? = nil
                    if actType == .click || actType == .rightClick || actType == .doubleClick {
                        let parts = targetStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                        if parts.count >= 2 {
                            targetCoord = CGPoint(x: parts[0], y: parts[1])
                        }
                    }

                    var targetAppName: String? = targetStr.isEmpty ? nil : targetStr
                    if targetAppName == nil || targetAppName?.lowercased() == "current" || targetAppName?.lowercased() == "active app" {
                        if let detected = ComputerUsePhysicalExecutor.resolveTargetAppName(appName: targetAppName, details: "\(detailsStr) \(innerContent) \(responseText)") {
                            targetAppName = detected
                        }
                    }

                    actionPayload = ComputerUseActionPayload(
                        type: actType,
                        targetCoordinate: targetCoord,
                        textToType: actType == .typeText ? detailsStr : nil,
                        targetApp: targetAppName,
                        keyCombo: actType == .keyCombo ? (detailsStr.isEmpty ? targetStr : detailsStr) : nil,
                        rawDetails: detailsStr.isEmpty ? targetStr : detailsStr
                    )

                    cleanedInner = actionRegex.stringByReplacingMatches(
                        in: innerContent,
                        options: [],
                        range: NSRange(innerContent.startIndex..., in: innerContent),
                        withTemplate: ""
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        let cleanedText = requestRegex.stringByReplacingMatches(
            in: responseText,
            options: [],
            range: NSRange(responseText.startIndex..., in: responseText),
            withTemplate: cleanedInner
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let heading = actionPayload.type == .tradingViewAction ? "TradingView Chart Action" : "Wants to use your Mac"
        let fallbackBody = actionPayload.type == .tradingViewAction ? "Aku ingin menganalisis dan menggambarkan level teknikal di TradingView. Boleh aku lakukan sekarang?" : "Aku perlu mengambil alih layar sebentar untuk melakukan aksi ini. Boleh aku lakukan sekarang?"

        let request = ComputerUseRequest(
            companionId: activeBuddy?.id,
            companionName: activeBuddy?.name ?? "Shippy",
            companionMood: activeBuddy?.mood ?? .happy,
            cloudColorHex: activeBuddy?.avatarColorHex ?? "#38BDF8",
            ringColorHex: activeBuddy?.ringColorHex ?? "#BAE6FD",
            heading: heading,
            bodyText: cleanedInner.isEmpty ? fallbackBody : cleanedInner,
            payload: actionPayload
        )

        return (cleanedText, request)
    }
}

// MARK: - CompanionReportPresenter Conformance

extension CompanionManager: CompanionReportPresenter {}

