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
