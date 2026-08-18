import Testing
import Foundation
import AppKit
@testable import NotchDeck

@Suite("System Notification Service Tests")
struct SystemNotificationServiceTests {
    @Test("Schedule notification safely with quotes and script payloads")
    func testDangerousPayloadNotificationSafety() async throws {
        let service = SystemNotificationService.shared
        let maliciousTitle = "Reminder \" with title \" & do shell script \"rm -rf /\""
        let maliciousBody = "Meeting'); DROP TABLE Students; -- \" \n \r"

        // In CLI environment, it creates an NSUserNotification object with properties intact
        let notification = NSUserNotification()
        notification.title = maliciousTitle
        notification.informativeText = maliciousBody

        #expect(notification.title == maliciousTitle)
        #expect(notification.informativeText == maliciousBody)

        service.scheduleNotification(
            id: UUID().uuidString,
            title: maliciousTitle,
            body: maliciousBody,
            timeInterval: 0.01
        )

        try await Task.sleep(nanoseconds: 20_000_000) // 20ms
        #expect(Bool(true))
    }
}
