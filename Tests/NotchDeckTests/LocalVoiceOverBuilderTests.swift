import Testing
@testable import NotchDeck

@Suite("Local Voice-Over Builder Tests")
struct LocalVoiceOverBuilderTests {
    @Test("Number to Indonesian words (0-59)")
    func testNumberToIndonesianWords() {
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(0) == "nol")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(1) == "satu")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(10) == "sepuluh")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(11) == "sebelas")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(15) == "lima belas")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(20) == "dua puluh")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(25) == "dua puluh lima")
        #expect(LocalVoiceOverBuilder.numberToIndonesianWords(45) == "empat puluh lima")
    }

    @Test("Build spoken script with positive offset")
    func testBuildScriptWithOffset() {
        let script = LocalVoiceOverBuilder.buildScript(title: "Meeting Tim Backend", offsetMinutes: 10)
        #expect(script == "Pengingat: Agenda Meeting Tim Backend akan dimulai dalam sepuluh menit.")
    }

    @Test("Build spoken script when starting now (0 offset)")
    func testBuildScriptZeroOffset() {
        let script = LocalVoiceOverBuilder.buildScript(title: "Sync Daily", offsetMinutes: 0)
        #expect(script == "Pengingat: Agenda Sync Daily dimulai sekarang.")
    }
}
