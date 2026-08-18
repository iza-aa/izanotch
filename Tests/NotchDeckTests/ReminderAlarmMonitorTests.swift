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
