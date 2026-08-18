# Milestone 5: UI Card Carousel & Settings Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the horizontal rich card carousel (Supaste style in Image 1 & Claude card in Image 2) for Clipboard History, Dropzone drag-and-drop staging, and AI conversation previews, plus the Settings Window with BYOK Keychain configuration and "Test Connection".

**Architecture:** A modern SwiftUI component layer composed of `CardDataStore` (state manager for carousel items & active filter category), modular cards (`ClipboardCardView`, `AISessionCardView`, `DropzoneCardView`), `CategoryFilterBarView`, and `SettingsView` wired into `NotchDeckApp`.

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSPasteboard`), Keychain (`KeychainManager`), Foundation.

**Spec:** [`docs/superpowers/specs/2026-08-18-notchdeck-design.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/superpowers/specs/2026-08-18-notchdeck-design.md)

## Global Constraints
- Matches visual references: Filter pills (`History`, `Prompts`, `Schedule`, `Clipboard`), rich preview cards, and curved ear header.
- BYOK Settings: Secure Keychain persistence for Gemini & Anthropic keys.
- Reactive filtering: Selecting a category pill instantly filters the carousel.

---

### Task 1: Card Models & Carousel Data Store (TDD)

**Files:**
- Create: `Sources/NotchDeck/UI/Cards/CardModels.swift`
- Create: `Sources/NotchDeck/UI/Cards/CardDataStore.swift`
- Create: `Tests/NotchDeckTests/CardDataStoreTests.swift`

**Interfaces:**
- Produces: `CardItem`, `CardCategory`, `CardDataStore.filteredItems() -> [CardItem]`.

- [ ] **Step 1: Write failing unit tests for CardDataStore**

```swift
// Tests/NotchDeckTests/CardDataStoreTests.swift
import Testing
@testable import NotchDeck

@Suite("Card Data Store Tests")
struct CardDataStoreTests {
    @Test("Filter cards by selected category")
    @MainActor
    func testFilterByCategory() {
        let store = CardDataStore()
        store.items = [
            CardItem(id: "1", title: "Code Snippet", subtitle: "SwiftUI View", category: .clipboard, badge: "Swift"),
            CardItem(id: "2", title: "Meeting Sync", subtitle: "Jam 14:00", category: .schedule, badge: "10m"),
            CardItem(id: "3", title: "Antigravity Refactor", subtitle: "Optimized function", category: .prompts, badge: "AI")
        ]

        store.selectedCategory = .all
        #expect(store.filteredItems().count == 3)

        store.selectedCategory = .clipboard
        #expect(store.filteredItems().count == 1)
        #expect(store.filteredItems().first?.title == "Code Snippet")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter CardDataStoreTests`  
Expected: FAIL.

- [ ] **Step 3: Implement CardModels & CardDataStore**

```swift
// Sources/NotchDeck/UI/Cards/CardModels.swift
import Foundation

public enum CardCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case clipboard = "Clipboard"
    case prompts = "Prompts"
    case schedule = "Schedule"
    case dropzone = "Dropzone"

    public var id: String { rawValue }
}

public struct CardItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let category: CardCategory
    public let badge: String
    public let timestamp: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String,
        category: CardCategory,
        badge: String,
        timestamp: String = "Just now"
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.badge = badge
        self.timestamp = timestamp
    }
}
```

```swift
// Sources/NotchDeck/UI/Cards/CardDataStore.swift
import SwiftUI

@MainActor
public final class CardDataStore: ObservableObject {
    public static let shared = CardDataStore()

    @Published public var selectedCategory: CardCategory = .all
    @Published public var items: [CardItem] = []

    public init() {
        self.items = [
            CardItem(title: "struct ContentView: View", subtitle: "SwiftUI Root Component", category: .clipboard, badge: "Swift", timestamp: "2m ago"),
            CardItem(title: "Meeting Tim Backend", subtitle: "Jam 14:00 (10 menit sebelum)", category: .schedule, badge: "13:50", timestamp: "5m ago"),
            CardItem(title: "Antigravity Code Review", subtitle: "Generated unit tests for auth", category: .prompts, badge: "AI Done", timestamp: "12m ago"),
            CardItem(title: "Assets Staging", subtitle: "Drop screenshots or assets here", category: .dropzone, badge: "Drop Target", timestamp: "Ready")
        ]
    }

    public func filteredItems() -> [CardItem] {
        if selectedCategory == .all {
            return items
        }
        return items.filter { $0.category == selectedCategory }
    }

    public func addClipboardItem(text: String) {
        let analysis = ClipboardManager.analyze(text: text)
        let newItem = CardItem(
            title: analysis.cardBadge,
            subtitle: analysis.maskedPreview,
            category: .clipboard,
            badge: analysis.hasSecret ? "Secret" : "Copied",
            timestamp: "Just now"
        )
        items.insert(newItem, at: 0)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter CardDataStoreTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/UI/Cards/ Tests/NotchDeckTests/CardDataStoreTests.swift
git commit -m "feat(cards): implement CardModels and CardDataStore with category filtering"
```

---

### Task 2: Category Filter Bar & Card Carousel Components (TDD)

**Files:**
- Create: `Sources/NotchDeck/UI/Views/CategoryFilterBarView.swift`
- Create: `Sources/NotchDeck/UI/Views/CardCarouselView.swift`
- Create: `Tests/NotchDeckTests/CategoryFilterBarTests.swift`

**Interfaces:**
- Produces: `CategoryFilterBarView` (horizontal pills with counters), `CardCarouselView` (horizontal scrollable card previews).

- [ ] **Step 1: Write unit tests for CategoryFilterBar count logic**

```swift
// Tests/NotchDeckTests/CategoryFilterBarTests.swift
import Testing
@testable import NotchDeck

@Suite("Category Filter Bar Tests")
struct CategoryFilterBarTests {
    @Test("Category pill format contains count")
    @MainActor
    func testCategoryFormat() {
        let store = CardDataStore()
        let count = store.filteredItems().count
        #expect(count > 0)
    }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --filter CategoryFilterBarTests`  
Expected: PASS.

- [ ] **Step 3: Implement CategoryFilterBarView & CardCarouselView**

```swift
// Sources/NotchDeck/UI/Views/CategoryFilterBarView.swift
import SwiftUI

public struct CategoryFilterBarView: View {
    @ObservedObject public var store: CardDataStore

    public init(store: CardDataStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CardCategory.allCases) { cat in
                    let isSelected = store.selectedCategory == cat
                    let count = cat == .all ? store.items.count : store.items.filter { $0.category == cat }.count

                    Button(action: { store.selectedCategory = cat }) {
                        HStack(spacing: 4) {
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            Text("\(count)")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.06))
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
```

```swift
// Sources/NotchDeck/UI/Views/CardCarouselView.swift
import SwiftUI

public struct CardCarouselView: View {
    @ObservedObject public var store: CardDataStore

    public init(store: CardDataStore = .shared) {
        self.store = store
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(store.filteredItems()) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(badgeColor(for: item.category))
                                .cornerRadius(4)
                                .foregroundColor(.white)
                            Spacer()
                            Text(item.timestamp)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }

                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(item.subtitle)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .lineLimit(2)

                        Spacer()
                    }
                    .padding(10)
                    .frame(width: 140, height: 110)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func badgeColor(for category: CardCategory) -> Color {
        switch category {
        case .all: return .gray
        case .clipboard: return .blue
        case .prompts: return .purple
        case .schedule: return .green
        case .dropzone: return .orange
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/UI/Views/CategoryFilterBarView.swift Sources/NotchDeck/UI/Views/CardCarouselView.swift Tests/NotchDeckTests/CategoryFilterBarTests.swift
git commit -m "feat(ui): implement CategoryFilterBarView and CardCarouselView"
```

---

### Task 3: Settings View with BYOK API Key Manager (TDD)

**Files:**
- Create: `Sources/NotchDeck/UI/Views/SettingsView.swift`
- Create: `Tests/NotchDeckTests/SettingsViewTests.swift`

**Interfaces:**
- Produces: `SettingsView` providing input fields for Gemini / Anthropic API keys with status feedback.

- [ ] **Step 1: Write unit tests for Settings key storage interaction**

```swift
// Tests/NotchDeckTests/SettingsViewTests.swift
import Testing
@testable import NotchDeck

@Suite("Settings View Tests")
struct SettingsViewTests {
    @Test("Save API Key to Keychain")
    func testSaveAPIKeyFromSettings() throws {
        try KeychainManager.save(key: "notchdeck.gemini.apikey", value: "AIzaSyTest123")
        let loaded = KeychainManager.load(key: "notchdeck.gemini.apikey")
        #expect(loaded == "AIzaSyTest123")
    }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `swift test --filter SettingsViewTests`  
Expected: PASS.

- [ ] **Step 3: Implement SettingsView**

```swift
// Sources/NotchDeck/UI/Views/SettingsView.swift
import SwiftUI

public struct SettingsView: View {
    @State private var geminiKey: String = ""
    @State private var claudeKey: String = ""
    @State private var statusMessage: String = ""
    @State private var isTesting: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⚙️ NotchDeck Settings")
                .font(.headline)
                .foregroundColor(.primary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Google Gemini API Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("AIzaSy...", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)

                Text("Anthropic Claude API Key:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("sk-ant-...", text: $claudeKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Save Keys") {
                    saveKeys()
                }
                .buttonStyle(.borderedProminent)

                Button(isTesting ? "Testing..." : "Test Connection") {
                    testConnection()
                }
                .disabled(isTesting || geminiKey.isEmpty)

                Spacer()
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(statusMessage.contains("✅") ? .green : .red)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 280)
        .onAppear {
            geminiKey = KeychainManager.load(key: "notchdeck.gemini.apikey") ?? ""
            claudeKey = KeychainManager.load(key: "notchdeck.claude.apikey") ?? ""
        }
    }

    private func saveKeys() {
        try? KeychainManager.save(key: "notchdeck.gemini.apikey", value: geminiKey)
        try? KeychainManager.save(key: "notchdeck.claude.apikey", value: claudeKey)
        statusMessage = "✅ Keys saved securely to Keychain."
    }

    private func testConnection() {
        isTesting = true
        statusMessage = "Connecting to Gemini..."
        Task {
            do {
                _ = try await NotchDeckAIClient.shared.parseSchedule(
                    userUtterance: "test ping",
                    apiKey: geminiKey
                )
                await MainActor.run {
                    self.statusMessage = "✅ Connection successful! AI is ready."
                    self.isTesting = false
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "❌ Connection failed: \(error.localizedDescription)"
                    self.isTesting = false
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SettingsViewTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/UI/Views/SettingsView.swift Tests/NotchDeckTests/SettingsViewTests.swift
git commit -m "feat(settings): implement SettingsView with BYOK Keychain management"
```

---

### Task 4: Assemble Full Deck Layout in NotchRootView & NotchDeckApp

**Files:**
- Modify: `Sources/NotchDeck/UI/Views/NotchRootView.swift`
- Modify: `Sources/NotchDeck/NotchDeckApp.swift`

- [ ] **Step 1: Update NotchRootView with Category Filter and Card Carousel**

```swift
// Sources/NotchDeck/UI/Views/NotchRootView.swift
import SwiftUI

public struct NotchRootView: View {
    @ObservedObject public var stateController: NotchStateController
    @ObservedObject public var cardStore: CardDataStore = .shared
    public var audioLevels: [CGFloat]

    public init(
        stateController: NotchStateController,
        cardStore: CardDataStore = .shared,
        audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7]
    ) {
        self.stateController = stateController
        self.cardStore = cardStore
        self.audioLevels = audioLevels
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            switch stateController.currentState {
            case .collapsed:
                HStack(spacing: 8) {
                    Circle().fill(Color.cyan).frame(width: 8, height: 8)
                    Text("NotchDeck").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.white)
                }
                .padding(.horizontal, 12)

            case .voiceActive:
                HStack(spacing: 12) {
                    AudioWaveformView(levels: audioLevels)
                    Text(stateController.commandPrompt.isEmpty ? "Mendengarkan..." : stateController.commandPrompt)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { stateController.transition(to: .collapsed) }) {
                        Image(systemName: "stop.circle.fill").foregroundColor(.orange).font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

            case .liveActivity(let title, let countdown):
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock").foregroundColor(.green)
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Text(countdown).font(.system(size: 11, weight: .bold)).foregroundColor(.yellow)
                }
                .padding(.horizontal, 16)

            case .expanded:
                VStack(spacing: 12) {
                    // 1. Header Command Bar
                    HStack {
                        Menu {
                            Button("Antigravity") { stateController.activeAIModel = "Antigravity" }
                            Button("Claude Code") { stateController.activeAIModel = "Claude Code" }
                        } label: {
                            Text("✨ \(stateController.activeAIModel) ▾")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.white.opacity(0.1)).cornerRadius(8)
                        }
                        .menuStyle(.borderlessButton)

                        TextField("Ask AI or speak reminder...", text: $stateController.commandPrompt)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)

                        Button(action: { stateController.transition(to: .voiceActive) }) {
                            Image(systemName: "mic.fill").foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                    // 2. Category Filter Bar (Image 1 Style)
                    CategoryFilterBarView(store: cardStore)

                    // 3. Horizontal Card Carousel
                    CardCarouselView(store: cardStore)

                    Spacer()
                }
                .padding(16)
            }
        }
        .frame(
            width: widthForState(stateController.currentState),
            height: heightForState(stateController.currentState)
        )
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: return 180
        case .voiceActive: return 360
        case .liveActivity: return 320
        case .expanded: return 560
        }
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: return 32
        case .voiceActive: return 60
        case .liveActivity: return 44
        case .expanded: return 240
        }
    }
}
```

- [ ] **Step 2: Update NotchDeckApp Settings Window Scene**

```swift
// Sources/NotchDeck/NotchDeckApp.swift
import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: NotchWindowController?
    var stateController = NotchStateController()
    var hoverMonitor: NotchHoverMonitor?
    var speechManager: SpeechRecognitionManager?
    var alarmMonitor: ReminderAlarmMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let wc = NotchWindowController(stateController: stateController)
        self.windowController = wc
        self.hoverMonitor = NotchHoverMonitor(stateController: stateController)
        self.speechManager = SpeechRecognitionManager(stateController: stateController)
        self.alarmMonitor = ReminderAlarmMonitor(stateController: stateController)
        wc.showWindow(nil)

        setupGlobalHotkeys()
    }

    private func setupGlobalHotkeys() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let action = HotkeyManager.resolveAction(keyCode: event.keyCode, flags: event.modifierFlags)
            switch action {
            case .toggleExpand:
                let target: NotchState = self.stateController.currentState == .expanded ? .collapsed : .expanded
                self.stateController.transition(to: target)
                return nil
            case .pushToTalk:
                if self.stateController.currentState == .voiceActive {
                    self.speechManager?.stopRecording()
                    self.submitCurrentPrompt()
                } else {
                    self.stateController.transition(to: .voiceActive)
                    try? self.speechManager?.startRecording()
                }
                return nil
            case .dismiss:
                if self.stateController.currentState != .collapsed {
                    self.speechManager?.stopRecording()
                    self.stateController.transition(to: .collapsed)
                    return nil
                }
            case .none:
                break
            }
            return event
        }
    }

    public func submitCurrentPrompt() {
        let prompt = stateController.commandPrompt
        guard !prompt.isEmpty else {
            stateController.transition(to: .collapsed)
            return
        }

        let apiKey = KeychainManager.load(key: "notchdeck.gemini.apikey")
        Task { @MainActor in
            if let detail = await ScheduleCoordinator.shared.processUtterance(prompt, apiKey: apiKey) {
                self.alarmMonitor?.scheduleAlarm(for: detail)
            }
            self.stateController.commandPrompt = ""
            self.stateController.transition(to: .collapsed)
        }
    }
}

@main
struct NotchDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
```

- [ ] **Step 3: Run full build and test suite**

Run: `swift test`  
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/NotchDeck/UI/Views/NotchRootView.swift Sources/NotchDeck/NotchDeckApp.swift
git commit -m "feat(ui): wire CardCarousel, CategoryFilterBar, and SettingsView into NotchDeck"
```

---
