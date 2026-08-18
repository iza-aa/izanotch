import AVFoundation

public final class VoiceOverSpeaker: NSObject, @unchecked Sendable {
    public static let shared = VoiceOverSpeaker()
    private let synthesizer = AVSpeechSynthesizer()

    public static func createUtterance(for text: String, language: String = "id-ID") -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        if let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = 0.50
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        return utterance
    }

    public func speak(text: String, language: String = "id-ID") {
        let utterance = Self.createUtterance(for: text, language: language)
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
