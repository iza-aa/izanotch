import Foundation
import AppKit
import UserNotifications

public final class SystemNotificationService: @unchecked Sendable {
    public static let shared = SystemNotificationService()

    public init() {}

    private var isBundledApp: Bool {
        Bundle.main.bundleIdentifier != nil && !Bundle.main.bundlePath.contains(".build/")
    }

    public func requestAuthorization() async -> Bool {
        guard isBundledApp else {
            return true
        }

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
        guard timeInterval >= 0 else { return }

        if isBundledApp {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, timeInterval), repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[SystemNotificationService] Error adding notification: \(error)")
                }
            }
        } else {
            // Native Cocoa NSUserNotification (ZERO shell injection, 100% pure API)
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0.1, timeInterval)) {
                let notification = NSUserNotification()
                notification.identifier = id
                notification.title = title
                notification.informativeText = body
                notification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
    }
}
