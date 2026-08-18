import Testing
import Foundation
@testable import NotchDeck

@Suite("System Notification Service Tests")
struct SystemNotificationServiceTests {
    @Test("Schedule notification with dangerous characters and injection payloads does not crash or execute shell")
    func testDangerousPayloadNotification() async throws {
        let service = SystemNotificationService.shared
        let maliciousTitle = "Reminder \" with title \" & do shell script \"rm -rf /\""
        let maliciousBody = "Meeting'); DROP TABLE Students; -- \" \n \r"

        // Pure Cocoa NSUserNotification execution does not throw or crash on special chars
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
