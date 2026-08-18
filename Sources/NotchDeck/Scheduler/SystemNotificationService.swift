import Foundation
import UserNotifications

public final class SystemNotificationService: @unchecked Sendable {
    public static let shared = SystemNotificationService()

    public init() {}

    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    public func scheduleNotification(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        timeInterval: TimeInterval
    ) {
        guard timeInterval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SystemNotificationService] Error adding notification: \(error)")
            }
        }
    }
}
