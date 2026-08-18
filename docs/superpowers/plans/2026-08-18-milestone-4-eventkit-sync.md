# Milestone 4: Apple EventKit Synchronization & Schedule Coordinator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement two-way synchronization with Apple Calendar & Apple Reminders via `EventKit`, create the unified `ScheduleCoordinator` (Cloud NLP + Offline Fallback + Auto-Save to EventKit), and build the `ReminderAlarmMonitor` for triggering verbal Voice-Over alarms.

**Architecture:** A robust scheduler subsystem composed of `EventKitService` (`EKEventStore` wrapper with permissions handling), `ScheduleCoordinator` (orchestrating AI client, local regex fallback, and EventKit persistence), and `ReminderAlarmMonitor` (monitoring upcoming events and firing `VoiceOverSpeaker` announcements).

**Tech Stack:** Swift 6, EventKit (`EKEventStore`, `EKEvent`, `EKReminder`, `EKAlarm`), Foundation, SwiftUI.

**Spec:** [`docs/superpowers/specs/2026-08-18-notchdeck-design.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/superpowers/specs/2026-08-18-notchdeck-design.md)

## Global Constraints
- Two-way Calendar & Reminder creation in native macOS Apple databases.
- Resilient Dual-Engine: If Cloud API fails or is offline, instantly fallback to `LocalScheduleParser`.
- Timed Alarm Trigger: Fires `VoiceOverSpeaker` precisely at `reminderDate`.

---

### Task 1: EventKit Service Protocol & Data Adapters (TDD)

**Files:**
- Create: `Sources/NotchDeck/Scheduler/EventKitService.swift`
- Create: `Tests/NotchDeckTests/EventKitServiceTests.swift`

**Interfaces:**
- Produces: `EventKitServiceProtocol`, `EventKitService.createCalendarEvent(detail: ScheduleDetail) async throws -> String`, `EventKitService.createReminder(detail: ScheduleDetail) async throws -> String`.

- [ ] **Step 1: Write failing unit tests for EventKit data model conversion**

```swift
// Tests/NotchDeckTests/EventKitServiceTests.swift
import Testing
import Foundation
@testable import NotchDeck

@Suite("EventKit Service Tests")
struct EventKitServiceTests {
    @Test("ScheduleDetail converts accurately to Event and Reminder payloads")
    func testScheduleDetailConversion() {
        let isoFormatter = ISO8601DateFormatter()
        let start = Date().addingTimeInterval(3600)
        let reminder = Date().addingTimeInterval(3000)

        let detail = ScheduleDetail(
            title: "Meeting Tim Frontend",
            eventType: "meeting",
            eventStartISO: isoFormatter.string(from: start),
            reminderISO: isoFormatter.string(from: reminder),
            offsetMinutes: 10,
            confidenceScore: 0.95
        )

        let alarmOffset = EventKitService.calculateAlarmOffset(for: detail)
        #expect(alarmOffset == -600.0) // 10 minutes prior in seconds
        #expect(detail.eventStartDate > Date())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter EventKitServiceTests`  
Expected: FAIL.

- [ ] **Step 3: Implement EventKitService**

```swift
// Sources/NotchDeck/Scheduler/EventKitService.swift
import Foundation
import EventKit

public protocol EventKitServiceProtocol: Sendable {
    func createCalendarEvent(detail: ScheduleDetail) async throws -> String
    func createReminder(detail: ScheduleDetail) async throws -> String
}

public final class EventKitService: EventKitServiceProtocol, @unchecked Sendable {
    public static let shared = EventKitService()
    public let eventStore = EKEventStore()

    public static func calculateAlarmOffset(for detail: ScheduleDetail) -> TimeInterval {
        return -Double(detail.offsetMinutes * 60)
    }

    public func requestAccess() async throws -> (calendarGranted: Bool, reminderGranted: Bool) {
        let calGranted: Bool
        let remGranted: Bool

        if #available(macOS 14.0, *) {
            calGranted = (try? await eventStore.requestFullAccessToEvents()) ?? false
            remGranted = (try? await eventStore.requestFullAccessToReminders()) ?? false
        } else {
            calGranted = (try? await eventStore.requestAccess(to: .event)) ?? false
            remGranted = (try? await eventStore.requestAccess(to: .reminder)) ?? false
        }

        return (calGranted, remGranted)
    }

    public func createCalendarEvent(detail: ScheduleDetail) async throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = detail.title
        event.startDate = detail.eventStartDate
        event.endDate = detail.eventStartDate.addingTimeInterval(3600) // Default 1 hour duration
        event.calendar = eventStore.defaultCalendarForNewEvents

        if detail.offsetMinutes > 0 {
            let alarm = EKAlarm(relativeOffset: Self.calculateAlarmOffset(for: detail))
            event.addAlarm(alarm)
        }

        try eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier ?? UUID().uuidString
    }

    public func createReminder(detail: ScheduleDetail) async throws -> String {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = detail.title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        let cal = Calendar.current
        reminder.dueDateComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: detail.reminderDate)

        let alarm = EKAlarm(absoluteDate: detail.reminderDate)
        reminder.addAlarm(alarm)

        try eventStore.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter EventKitServiceTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Scheduler/EventKitService.swift Tests/NotchDeckTests/EventKitServiceTests.swift
git commit -m "feat(scheduler): implement EventKitService for Apple Calendar and Reminders"
```

---

### Task 2: Unified Schedule Coordinator with Dual-Engine (TDD)

**Files:**
- Create: `Sources/NotchDeck/Scheduler/ScheduleCoordinator.swift`
- Create: `Tests/NotchDeckTests/ScheduleCoordinatorTests.swift`

**Interfaces:**
- Produces: `ScheduleCoordinator.processUtterance(_ utterance: String, apiKey: String?) async -> ScheduleDetail?`.

- [ ] **Step 1: Write failing unit tests for ScheduleCoordinator fallback**

```swift
// Tests/NotchDeckTests/ScheduleCoordinatorTests.swift
import Testing
import Foundation
@testable import NotchDeck

@Suite("Schedule Coordinator Tests")
struct ScheduleCoordinatorTests {
    @Test("Coordinator falls back to LocalScheduleParser when API key is missing")
    func testCoordinatorFallback() async {
        let coordinator = ScheduleCoordinator()
        let utterance = "meeting jam 3 sore tolong ingatkan 15 menit sebelum"
        
        let result = await coordinator.processUtterance(utterance, apiKey: nil)
        #expect(result != nil)
        #expect(result?.offsetMinutes == 15)
        #expect(result?.title.lowercased().contains("meeting") == true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ScheduleCoordinatorTests`  
Expected: FAIL.

- [ ] **Step 3: Implement ScheduleCoordinator**

```swift
// Sources/NotchDeck/Scheduler/ScheduleCoordinator.swift
import Foundation

public final class ScheduleCoordinator: Sendable {
    public static let shared = ScheduleCoordinator()
    private let aiClient: NotchDeckAIClient
    private let eventKitService: EventKitServiceProtocol

    public init(
        aiClient: NotchDeckAIClient = .shared,
        eventKitService: EventKitServiceProtocol = EventKitService.shared
    ) {
        self.aiClient = aiClient
        self.eventKitService = eventKitService
    }

    public func processUtterance(
        _ utterance: String,
        currentDate: Date = Date(),
        apiKey: String? = nil
    ) async -> ScheduleDetail? {
        let cleanUtterance = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUtterance.isEmpty else { return nil }

        // 1. Try Cloud AI if API Key is available
        if let apiKey = apiKey, !apiKey.isEmpty {
            do {
                let aiResult = try await aiClient.parseSchedule(
                    userUtterance: cleanUtterance,
                    currentDate: currentDate,
                    apiKey: apiKey
                )
                if aiResult.success, let detail = aiResult.payload {
                    _ = try? await eventKitService.createCalendarEvent(detail: detail)
                    _ = try? await eventKitService.createReminder(detail: detail)
                    return detail
                }
            } catch {
                // Fallback to local parsing on network/decoding error
            }
        }

        // 2. Fallback to Local Regex Parser
        if let localDetail = LocalScheduleParser.parse(utterance: cleanUtterance, referenceDate: currentDate) {
            _ = try? await eventKitService.createCalendarEvent(detail: localDetail)
            _ = try? await eventKitService.createReminder(detail: localDetail)
            return localDetail
        }

        return nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ScheduleCoordinatorTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Scheduler/ScheduleCoordinator.swift Tests/NotchDeckTests/ScheduleCoordinatorTests.swift
git commit -m "feat(scheduler): implement ScheduleCoordinator with dual-engine fallback and EventKit auto-save"
```

---

### Task 3: Background Reminder Alarm Monitor (TDD)

**Files:**
- Create: `Sources/NotchDeck/Scheduler/ReminderAlarmMonitor.swift`
- Create: `Tests/NotchDeckTests/ReminderAlarmMonitorTests.swift`

**Interfaces:**
- Produces: `ReminderAlarmMonitor.scheduleAlarm(for: ScheduleDetail)`.

- [ ] **Step 1: Write failing unit tests for ReminderAlarmMonitor**

```swift
// Tests/NotchDeckTests/ReminderAlarmMonitorTests.swift
import Testing
import Foundation
@testable import NotchDeck

@Suite("Reminder Alarm Monitor Tests")
struct ReminderAlarmMonitorTests {
    @Test("Alarm monitor schedules and triggers Voice-Over speech")
    @MainActor
    func testAlarmTriggering() async throws {
        let stateController = NotchStateController()
        let monitor = ReminderAlarmMonitor(stateController: stateController)
        
        let isoFormatter = ISO8601DateFormatter()
        let nearDate = Date().addingTimeInterval(0.05) // 50ms in the future

        let detail = ScheduleDetail(
            title: "Quick Standup",
            eventType: "meeting",
            eventStartISO: isoFormatter.string(from: nearDate),
            reminderISO: isoFormatter.string(from: nearDate),
            offsetMinutes: 0,
            confidenceScore: 1.0
        )

        monitor.scheduleAlarm(for: detail)
        try await Task.sleep(nanoseconds: 80_000_000) // 80ms

        // Verify state changed to liveActivity
        switch stateController.currentState {
        case .liveActivity(let title, _):
            #expect(title.contains("Quick Standup"))
        default:
            #expect(Bool(false), "State should have transitioned to liveActivity")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ReminderAlarmMonitorTests`  
Expected: FAIL.

- [ ] **Step 3: Implement ReminderAlarmMonitor**

```swift
// Sources/NotchDeck/Scheduler/ReminderAlarmMonitor.swift
import Foundation
import Combine

@MainActor
public final class ReminderAlarmMonitor: ObservableObject {
    public let stateController: NotchStateController
    public let voiceSpeaker: VoiceOverSpeaker
    private var scheduledTasks: [UUID: Task<Void, Never>] = [:]

    public init(
        stateController: NotchStateController,
        voiceSpeaker: VoiceOverSpeaker = .shared
    ) {
        self.stateController = stateController
        self.voiceSpeaker = voiceSpeaker
    }

    public func scheduleAlarm(for detail: ScheduleDetail) {
        let targetDate = detail.reminderDate
        let interval = targetDate.timeIntervalSince(Date())
        let taskId = UUID()

        guard interval >= 0 else {
            fireAlarm(for: detail)
            return
        }

        let task = Task { @MainActor in
            let nano = UInt64(max(0, interval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nano)
            guard !Task.isCancelled else { return }
            self.fireAlarm(for: detail)
            self.scheduledTasks.removeValue(forKey: taskId)
        }

        scheduledTasks[taskId] = task
    }

    public func fireAlarm(for detail: ScheduleDetail) {
        let script = LocalVoiceOverBuilder.buildScript(title: detail.title, offsetMinutes: detail.offsetMinutes)
        voiceSpeaker.speak(text: script, language: "id-ID")

        let countdown = detail.offsetMinutes == 0 ? "Now" : "in \(detail.offsetMinutes)m"
        stateController.transition(to: .liveActivity(title: detail.title, countdown: countdown))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ReminderAlarmMonitorTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Scheduler/ReminderAlarmMonitor.swift Tests/NotchDeckTests/ReminderAlarmMonitorTests.swift
git commit -m "feat(scheduler): implement ReminderAlarmMonitor for automated spoken alerts"
```

---
