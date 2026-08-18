# Milestone 2: AppKit Notch Window & Global Hotkey Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the physical AppKit `NotchPanel` (`NSPanel` at `.statusBar + 1` level), hardware notch geometry detection, hover gesture detector (`NSTrackingArea`), and global keyboard hotkeys (`⌥ Space` for Push-to-Talk, `⌘ ⇧ Space` for Command Center toggle).

**Architecture:** A modular AppKit window subsystem consisting of `NotchGeometryCalculator` for multi-screen frame math, `NotchPanel` / `NotchWindowController` embedding `NotchRootView`, `NotchHoverMonitor` with a 200ms debounce hover tracker, and `HotkeyManager` for system-wide shortcut listeners.

**Tech Stack:** Swift 6, AppKit (`NSPanel`, `NSScreen`, `NSHostingView`, `NSEvent`), SwiftUI, Combine.

**Spec:** [`docs/superpowers/specs/2026-08-18-notchdeck-design.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/superpowers/specs/2026-08-18-notchdeck-design.md)

## Global Constraints
- Target Platforms: macOS 14.0+, 15.0+, 26.0+ (Tahoe).
- Multi-space floating window: `[.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]`.
- Level: `.statusBar + 1` to float seamlessly over fullscreen IDEs and desktop windows.
- Hover debounce: $200\text{ms}$ delay before expanding on mouse hover.
- Hotkeys: `⌥ Space` (Push-to-Talk) and `⌘ ⇧ Space` (Expand Notch).

---

### Task 1: Screen Notch Geometry & Hardware Frame Calculator (TDD)

**Files:**
- Create: `Sources/NotchDeck/UI/Window/NotchGeometryCalculator.swift`
- Create: `Tests/NotchDeckTests/NotchGeometryCalculatorTests.swift`

**Interfaces:**
- Produces: `NotchGeometryCalculator.calculateFrame(for: NotchState, on: NSScreen) -> NSRect`.

- [ ] **Step 1: Write failing unit tests for NotchGeometryCalculator**

```swift
// Tests/NotchDeckTests/NotchGeometryCalculatorTests.swift
import Testing
import AppKit
@testable import NotchDeck

@Suite("Notch Geometry Calculator Tests")
struct NotchGeometryCalculatorTests {
    @Test("Calculate frame for collapsed state centered at top")
    func testCollapsedFrame() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(for: .collapsed, screenFrame: mockScreenFrame, hasPhysicalNotch: true)
        
        #expect(frame.width == 180)
        #expect(frame.height == 32)
        #expect(frame.midX == mockScreenFrame.midX)
        #expect(frame.maxY == mockScreenFrame.maxY)
    }

    @Test("Calculate frame for expanded state centered at top")
    func testExpandedFrame() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1728, height: 1117)
        let frame = NotchGeometryCalculator.calculateFrame(for: .expanded, screenFrame: mockScreenFrame, hasPhysicalNotch: true)
        
        #expect(frame.width == 540)
        #expect(frame.height == 380)
        #expect(frame.midX == mockScreenFrame.midX)
        #expect(frame.maxY == mockScreenFrame.maxY)
    }

    @Test("External screen without notch adds 10px top margin")
    func testExternalScreenFloatingPill() {
        let mockScreenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let frame = NotchGeometryCalculator.calculateFrame(for: .collapsed, screenFrame: mockScreenFrame, hasPhysicalNotch: false)
        
        #expect(frame.width == 180)
        #expect(frame.maxY == mockScreenFrame.maxY - 10)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotchGeometryCalculatorTests`  
Expected: FAIL.

- [ ] **Step 3: Implement NotchGeometryCalculator**

```swift
// Sources/NotchDeck/UI/Window/NotchGeometryCalculator.swift
import Foundation
import AppKit

public struct NotchGeometryCalculator: Sendable {
    public static func dimensions(for state: NotchState) -> (width: CGFloat, height: CGFloat) {
        switch state {
        case .collapsed: return (180, 32)
        case .voiceActive: return (360, 60)
        case .liveActivity: return (320, 44)
        case .expanded: return (540, 380)
        }
    }

    public static func calculateFrame(
        for state: NotchState,
        screenFrame: NSRect,
        hasPhysicalNotch: Bool
    ) -> NSRect {
        let (width, height) = dimensions(for: state)
        let originX = screenFrame.midX - (width / 2.0)
        let topOffset: CGFloat = hasPhysicalNotch ? 0 : 10.0
        let originY = screenFrame.maxY - height - topOffset

        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    public static func hasPhysicalNotch(screen: NSScreen) -> Bool {
        if #available(macOS 12.0, *) {
            return screen.safeAreaInsets.top > 0 || screen.auxiliaryTopLeftArea != nil
        }
        return false
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NotchGeometryCalculatorTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/UI/Window/ Tests/NotchDeckTests/NotchGeometryCalculatorTests.swift
git commit -m "feat(window): implement NotchGeometryCalculator for hardware and external displays"
```

---

### Task 2: AppKit Floating Notch Panel & Window Controller (TDD)

**Files:**
- Create: `Sources/NotchDeck/UI/Window/NotchPanel.swift`
- Create: `Sources/NotchDeck/UI/Window/NotchWindowController.swift`
- Create: `Tests/NotchDeckTests/NotchWindowControllerTests.swift`

**Interfaces:**
- Produces: `NotchPanel` (`NSPanel`), `NotchWindowController` managing hosting view and frame updates.

- [ ] **Step 1: Write failing unit tests for NotchWindowController**

```swift
// Tests/NotchDeckTests/NotchWindowControllerTests.swift
import Testing
import AppKit
@testable import NotchDeck

@Suite("Notch Window Controller Tests")
struct NotchWindowControllerTests {
    @Test("Window Controller initializes panel with correct style and levels")
    @MainActor
    func testWindowControllerSetup() {
        let stateController = NotchStateController()
        let windowController = NotchWindowController(stateController: stateController)
        
        guard let panel = windowController.window as? NotchPanel else {
            #expect(Bool(false), "Window should be an instance of NotchPanel")
            return
        }

        #expect(panel.level == .statusBar + 1)
        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == .clear)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotchWindowControllerTests`  
Expected: FAIL.

- [ ] **Step 3: Implement NotchPanel & NotchWindowController**

```swift
// Sources/NotchDeck/UI/Window/NotchPanel.swift
import AppKit

public final class NotchPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar + 1
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        self.hidesOnDeactivate = false
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
}
```

```swift
// Sources/NotchDeck/UI/Window/NotchWindowController.swift
import AppKit
import SwiftUI
import Combine

@MainActor
public final class NotchWindowController: NSWindowController {
    public let stateController: NotchStateController
    private var cancellables = Set<AnyCancellable>()

    public init(stateController: NotchStateController) {
        self.stateController = stateController
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let hasNotch = NotchGeometryCalculator.hasPhysicalNotch(screen: screen)
        let initialFrame = NotchGeometryCalculator.calculateFrame(
            for: stateController.currentState,
            screenFrame: screen.frame,
            hasPhysicalNotch: hasNotch
        )

        let panel = NotchPanel(contentRect: initialFrame)
        super.init(window: panel)

        let rootView = NotchRootView(stateController: stateController)
        let hostingView = NSHostingView(rootView: rootView)
        panel.contentView = hostingView

        observeStateChanges()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func observeStateChanges() {
        stateController.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.updateFrame(for: newState)
            }
            .store(in: &cancellables)
    }

    public func updateFrame(for state: NotchState) {
        guard let window = self.window, let screen = window.screen ?? NSScreen.main else { return }
        let hasNotch = NotchGeometryCalculator.hasPhysicalNotch(screen: screen)
        let targetFrame = NotchGeometryCalculator.calculateFrame(
            for: state,
            screenFrame: screen.frame,
            hasPhysicalNotch: hasNotch
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(targetFrame, display: true)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NotchWindowControllerTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/UI/Window/ Tests/NotchDeckTests/NotchWindowControllerTests.swift
git commit -m "feat(window): implement NotchPanel and NotchWindowController with state sync"
```

---

### Task 3: Hover Tracking & Mouse Gesture Monitor (TDD)

**Files:**
- Create: `Sources/NotchDeck/UI/Window/NotchHoverMonitor.swift`
- Create: `Tests/NotchDeckTests/NotchHoverMonitorTests.swift`

**Interfaces:**
- Produces: `NotchHoverMonitor` handling mouse enter/exit debounce to trigger `.expanded` / `.collapsed`.

- [ ] **Step 1: Write failing unit tests for NotchHoverMonitor debounce logic**

```swift
// Tests/NotchDeckTests/NotchHoverMonitorTests.swift
import Testing
import Foundation
@testable import NotchDeck

@Suite("Notch Hover Monitor Tests")
struct NotchHoverMonitorTests {
    @Test("Hover enter triggers expansion after debounce delay")
    @MainActor
    func testHoverEnterDebounce() async throws {
        let stateController = NotchStateController()
        let monitor = NotchHoverMonitor(stateController: stateController, debounceDuration: 0.05)
        
        #expect(stateController.currentState == .collapsed)

        monitor.mouseEntered()
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms (not yet debounced)
        #expect(stateController.currentState == .collapsed)

        try await Task.sleep(nanoseconds: 60_000_000) // 60ms (passed 50ms debounce)
        #expect(stateController.currentState == .expanded)
        
        monitor.mouseExited()
        #expect(stateController.currentState == .collapsed)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotchHoverMonitorTests`  
Expected: FAIL.

- [ ] **Step 3: Implement NotchHoverMonitor**

```swift
// Sources/NotchDeck/UI/Window/NotchHoverMonitor.swift
import Foundation
import Combine

@MainActor
public final class NotchHoverMonitor: ObservableObject {
    private let stateController: NotchStateController
    public let debounceDuration: TimeInterval
    private var hoverTask: Task<Void, Never>?

    public init(stateController: NotchStateController, debounceDuration: TimeInterval = 0.2) {
        self.stateController = stateController
        self.debounceDuration = debounceDuration
    }

    public func mouseEntered() {
        hoverTask?.cancel()
        hoverTask = Task { @MainActor in
            let nano = UInt64(debounceDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nano)
            guard !Task.isCancelled else { return }
            if self.stateController.currentState == .collapsed {
                self.stateController.transition(to: .expanded)
            }
        }
    }

    public func mouseExited() {
        hoverTask?.cancel()
        if stateController.currentState == .expanded {
            stateController.transition(to: .collapsed)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NotchHoverMonitorTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/UI/Window/NotchHoverMonitor.swift Tests/NotchDeckTests/NotchHoverMonitorTests.swift
git commit -m "feat(gesture): implement NotchHoverMonitor with 200ms debounce"
```

---

### Task 4: Global Hotkey Listener & App Integration (TDD)

**Files:**
- Create: `Sources/NotchDeck/Core/HotkeyManager.swift`
- Modify: `Sources/NotchDeck/NotchDeckApp.swift`
- Create: `Tests/NotchDeckTests/HotkeyManagerTests.swift`

**Interfaces:**
- Produces: `HotkeyManager` handling `⌥ Space` (Push-to-Talk) and `⌘ ⇧ Space` (Expand Toggle).

- [ ] **Step 1: Write failing unit tests for HotkeyManager intent resolution**

```swift
// Tests/NotchDeckTests/HotkeyManagerTests.swift
import Testing
@testable import NotchDeck

@Suite("Hotkey Manager Tests")
struct HotkeyManagerTests {
    @Test("Resolve Hotkey action correctly")
    func testHotkeyActions() {
        let toggleAction = HotkeyManager.resolveAction(keyCode: 49, flags: [.command, .shift]) // Cmd + Shift + Space
        #expect(toggleAction == .toggleExpand)

        let pushToTalkAction = HotkeyManager.resolveAction(keyCode: 49, flags: [.option]) // Option + Space
        #expect(pushToTalkAction == .pushToTalk)

        let escapeAction = HotkeyManager.resolveAction(keyCode: 53, flags: []) // Escape
        #expect(escapeAction == .dismiss)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HotkeyManagerTests`  
Expected: FAIL.

- [ ] **Step 3: Implement HotkeyManager and update NotchDeckApp**

```swift
// Sources/NotchDeck/Core/HotkeyManager.swift
import AppKit

public enum HotkeyAction: Equatable, Sendable {
    case toggleExpand
    case pushToTalk
    case dismiss
    case none
}

public struct HotkeyManager: Sendable {
    public static func resolveAction(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> HotkeyAction {
        let relevantFlags = flags.intersection([.command, .shift, .option, .control])

        // Spacebar is keyCode 49
        if keyCode == 49 {
            if relevantFlags.contains(.command) && relevantFlags.contains(.shift) {
                return .toggleExpand
            }
            if relevantFlags.contains(.option) {
                return .pushToTalk
            }
        }

        // Escape is keyCode 53
        if keyCode == 53 {
            return .dismiss
        }

        return .none
    }
}
```

```swift
// Sources/NotchDeck/NotchDeckApp.swift
import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: NotchWindowController?
    var stateController = NotchStateController()
    var hoverMonitor: NotchHoverMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let wc = NotchWindowController(stateController: stateController)
        self.windowController = wc
        self.hoverMonitor = NotchHoverMonitor(stateController: stateController)
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
                let target: NotchState = self.stateController.currentState == .voiceActive ? .collapsed : .voiceActive
                self.stateController.transition(to: target)
                return nil
            case .dismiss:
                if self.stateController.currentState != .collapsed {
                    self.stateController.transition(to: .collapsed)
                    return nil
                }
            case .none:
                break
            }
            return event
        }
    }
}

@main
struct NotchDeckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("NotchDeck Settings & BYOK API Keys")
                .frame(width: 380, height: 260)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter HotkeyManagerTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Core/HotkeyManager.swift Sources/NotchDeck/NotchDeckApp.swift Tests/NotchDeckTests/HotkeyManagerTests.swift
git commit -m "feat(hotkey): implement HotkeyManager and wire AppDelegate to NotchWindowController"
```

---
