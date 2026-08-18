import Testing
import Speech
@testable import NotchDeck

@Suite("Speech Recognition Manager Tests")
struct SpeechRecognitionManagerTests {
    @Test("Speech recognizer initializes with Indonesian locale")
    @MainActor
    func testRecognizerInitialization() {
        let stateController = NotchStateController()
        let manager = SpeechRecognitionManager(stateController: stateController)
        
        #expect(manager.locale.identifier == "id-ID")
        #expect(manager.isRecording == false)
    }
}
