import Testing
import AVFoundation
@testable import NotchDeck

@Suite("Voice-Over Speaker Tests")
struct VoiceOverSpeakerTests {
    @Test("Configure AVSpeechUtterance with Indonesian locale")
    func testSpeechUtteranceConfig() {
        let text = "Pengingat: Agenda Meeting dimulai dalam sepuluh menit."
        let utterance = VoiceOverSpeaker.createUtterance(for: text, language: "id-ID")
        
        #expect(utterance.speechString == text)
        #expect(utterance.rate >= 0.45 && utterance.rate <= 0.55)
    }
}
