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

        // 1. System Notification (Persistent via macOS Notification Center)
        if interval > 0 {
            SystemNotificationService.shared.scheduleNotification(
                id: taskId.uuidString,
                title: "⏰ \(detail.title)",
                body: "Agenda dimulai dalam \(detail.offsetMinutes) menit.",
                timeInterval: interval
            )
        }

        guard interval >= 0 else {
            fireAlarm(for: detail)
            return
        }

        // 2. In-App Live HUD & Voice-Over Speaker
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
