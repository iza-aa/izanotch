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
        #expect(alarmOffset == -600.0)
        #expect(detail.eventStartDate > Date())
    }
}
