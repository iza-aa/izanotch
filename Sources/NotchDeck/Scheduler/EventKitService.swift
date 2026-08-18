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
        event.endDate = detail.eventStartDate.addingTimeInterval(3600)
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
