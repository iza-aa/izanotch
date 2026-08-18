import Testing
import Foundation
@testable import NotchDeck

@Suite("Local Schedule Parser Offline Tests")
struct LocalScheduleParserTests {
    let refDate: Date = {
        var comp = DateComponents()
        comp.year = 2026; comp.month = 8; comp.day = 18; comp.hour = 11; comp.minute = 30; comp.second = 0
        comp.timeZone = TimeZone(identifier: "Asia/Jakarta")
        return Calendar.current.date(from: comp)!
    }()

    @Test("Parse standard Indonesian hour with offset")
    func testParseHourWithOffset() {
        let text = "meeting jam 2 nanti tolong ingatkan 10 menit sebelum"
        let result = LocalScheduleParser.parse(utterance: text, referenceDate: refDate)
        #expect(result != nil)
        #expect(result?.title.lowercased().contains("meeting") == true)
        #expect(result?.offsetMinutes == 10)
    }

    @Test("Parse past time today rolls over to tomorrow")
    func testPastTimeRollover() {
        var comp = DateComponents()
        comp.year = 2026; comp.month = 8; comp.day = 18; comp.hour = 15; comp.minute = 30; comp.second = 0
        comp.timeZone = TimeZone(identifier: "Asia/Jakarta")
        let lateRefDate = Calendar.current.date(from: comp)!

        let text = "meeting jam 2"
        let result = LocalScheduleParser.parse(utterance: text, referenceDate: lateRefDate)
        #expect(result != nil)
        
        let startComponents = Calendar.current.dateComponents(in: TimeZone(identifier: "Asia/Jakarta")!, from: result!.eventStartDate)
        #expect(startComponents.day == 19)
        #expect(startComponents.hour == 14)
    }

    @Test("Parse colloquial 'setengah jam lagi'")
    func testSetengahJam() {
        let text = "setengah jam lagi call client"
        let result = LocalScheduleParser.parse(utterance: text, referenceDate: refDate)
        #expect(result != nil)
        #expect(result?.offsetMinutes == 0)
        
        let startComponents = Calendar.current.dateComponents(in: TimeZone(identifier: "Asia/Jakarta")!, from: result!.eventStartDate)
        #expect(startComponents.hour == 12)
        #expect(startComponents.minute == 0)
    }
}
