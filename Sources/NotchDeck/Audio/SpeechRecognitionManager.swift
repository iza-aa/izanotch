import Foundation
import Speech
import AVFoundation

@MainActor
public final class SpeechRecognitionManager: ObservableObject {
    public let locale: Locale
    private let stateController: NotchStateController
    @Published public var isRecording: Bool = false
    @Published public var audioLevels: [CGFloat] = Array(repeating: 0.15, count: 6)

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    public init(stateController: NotchStateController, locale: Locale = Locale(identifier: "id-ID")) {
        self.stateController = stateController
        self.locale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    public func startRecording() throws {
        guard !isRecording else { return }

        // Reset previous tasks
        recognitionTask?.cancel()
        recognitionTask = nil

        let audioSession = AVAudioEngine()
        self.audioEngine = audioSession

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        if #available(macOS 10.15, *), speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Extract audio levels for waveform
            let channelData = buffer.floatChannelData?[0]
            let frames = Int(buffer.frameLength)
            if let data = channelData {
                let samples = Array(UnsafeBufferPointer(start: data, count: frames))
                let levels = AudioLevelProcessor.calculateNormalizedLevels(from: samples)
                Task { @MainActor [weak self] in
                    self?.audioLevels = levels
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                Task { @MainActor in
                    self.stateController.commandPrompt = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopRecording()
                }
            }
        }
    }

    public func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        audioLevels = Array(repeating: 0.15, count: 6)
    }
}
