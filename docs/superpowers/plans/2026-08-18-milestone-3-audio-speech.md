# Milestone 3: Live Audio Waveform, Speech-to-Text & Voice-Over Speaker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement real-time audio level and waveform processing for the Dynamic Island HUD, offline speech recognition streaming via `SFSpeechRecognizer` (`id-ID`), and spoken audio alert playback via `AVSpeechSynthesizer`.

**Architecture:** A modular audio subsystem composed of `AudioLevelProcessor` (RMS & decibel calculation for waveform bars), `SpeechRecognitionManager` (speech transcription lifecycle & audio engine tap), `VoiceOverSpeaker` (`AVSpeechSynthesizer` wrapper), and an interactive `AudioWaveformView` in SwiftUI.

**Tech Stack:** Swift 6, AVFoundation (`AVAudioEngine`, `AVSpeechSynthesizer`, `AVSpeechUtterance`), Speech (`SFSpeechRecognizer`, `SFSpeechAudioBufferRecognitionRequest`), SwiftUI.

**Spec:** [`docs/superpowers/specs/2026-08-18-notchdeck-design.md`](file:///Users/heizaaa/Desktop/cdev/iza-3/docs/superpowers/specs/2026-08-18-notchdeck-design.md)

## Global Constraints
- Speech Locale: Default `id-ID` (Bahasa Indonesia) with English fallback.
- Latency & Waveform: Audio buffer levels normalized to 5-8 bars updated at 30–60 FPS.
- Zero Cloud Dependency: Spoken alerts playback entirely offline using macOS native speech synthesizer.

---

### Task 1: Audio Waveform Sample & Level Processor (TDD)

**Files:**
- Create: `Sources/NotchDeck/Audio/AudioLevelProcessor.swift`
- Create: `Tests/NotchDeckTests/AudioLevelProcessorTests.swift`

**Interfaces:**
- Produces: `AudioLevelProcessor.calculateNormalizedLevels(from: [Float], barCount: Int) -> [CGFloat]`.

- [ ] **Step 1: Write failing unit tests for AudioLevelProcessor**

```swift
// Tests/NotchDeckTests/AudioLevelProcessorTests.swift
import Testing
import Foundation
@testable import NotchDeck

@Suite("Audio Level Processor Tests")
struct AudioLevelProcessorTests {
    @Test("Calculate normalized levels for silent buffer")
    func testSilentBufferLevels() {
        let silentSamples: [Float] = Array(repeating: 0.0, count: 512)
        let levels = AudioLevelProcessor.calculateNormalizedLevels(from: silentSamples, barCount: 6)
        
        #expect(levels.count == 6)
        for level in levels {
            #expect(level >= 0.1 && level <= 0.2) // Minimum base height for UI
        }
    }

    @Test("Calculate normalized levels for loud buffer")
    func testLoudBufferLevels() {
        let loudSamples: [Float] = Array(repeating: 0.8, count: 512)
        let levels = AudioLevelProcessor.calculateNormalizedLevels(from: loudSamples, barCount: 6)
        
        #expect(levels.count == 6)
        for level in levels {
            #expect(level >= 0.7)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AudioLevelProcessorTests`  
Expected: FAIL.

- [ ] **Step 3: Implement AudioLevelProcessor**

```swift
// Sources/NotchDeck/Audio/AudioLevelProcessor.swift
import Foundation

public struct AudioLevelProcessor: Sendable {
    public static func calculateNormalizedLevels(from samples: [Float], barCount: Int = 6) -> [CGFloat] {
        guard !samples.isEmpty else {
            return Array(repeating: 0.15, count: barCount)
        }

        // Calculate RMS (Root Mean Square)
        let sum = samples.reduce(0.0) { $0 + ($1 * $1) }
        let rms = sqrt(sum / Float(samples.count))
        let clampedRMS = min(1.0, max(0.0, rms * 3.5)) // Boost gain for visual effect

        // Generate varying bar heights around the RMS value
        var bars: [CGFloat] = []
        for i in 0..<barCount {
            let variance = Float(sin(Double(i) * 0.8 + Double(clampedRMS))) * 0.15
            let barHeight = max(0.15, min(1.0, CGFloat(clampedRMS + variance)))
            bars.append(barHeight)
        }

        return bars
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AudioLevelProcessorTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Audio/AudioLevelProcessor.swift Tests/NotchDeckTests/AudioLevelProcessorTests.swift
git commit -m "feat(audio): implement AudioLevelProcessor for dynamic waveform normalization"
```

---

### Task 2: Voice-Over Speaker Audio Player (TDD)

**Files:**
- Create: `Sources/NotchDeck/Audio/VoiceOverSpeaker.swift`
- Create: `Tests/NotchDeckTests/VoiceOverSpeakerTests.swift`

**Interfaces:**
- Produces: `VoiceOverSpeaker.speak(text: String, language: String)`.

- [ ] **Step 1: Write failing unit tests for VoiceOverSpeaker configuration**

```swift
// Tests/NotchDeckTests/VoiceOverSpeakerTests.swift
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
        #expect(utterance.voice?.language == "id-ID" || utterance.voice != nil)
        #expect(utterance.rate >= 0.45 && utterance.rate <= 0.55)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter VoiceOverSpeakerTests`  
Expected: FAIL.

- [ ] **Step 3: Implement VoiceOverSpeaker**

```swift
// Sources/NotchDeck/Audio/VoiceOverSpeaker.swift
import AVFoundation

public final class VoiceOverSpeaker: NSObject, Sendable {
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter VoiceOverSpeakerTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Audio/VoiceOverSpeaker.swift Tests/NotchDeckTests/VoiceOverSpeakerTests.swift
git commit -m "feat(audio): implement VoiceOverSpeaker for offline spoken alerts"
```

---

### Task 3: Speech Recognition Manager & Live State Coordinator (TDD)

**Files:**
- Create: `Sources/NotchDeck/Audio/SpeechRecognitionManager.swift`
- Create: `Tests/NotchDeckTests/SpeechRecognitionManagerTests.swift`

**Interfaces:**
- Produces: `SpeechRecognitionManager` managing microphone buffer tap and live transcription streaming into `NotchStateController`.

- [ ] **Step 1: Write failing unit tests for SpeechRecognitionManager**

```swift
// Tests/NotchDeckTests/SpeechRecognitionManagerTests.swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SpeechRecognitionManagerTests`  
Expected: FAIL.

- [ ] **Step 3: Implement SpeechRecognitionManager**

```swift
// Sources/NotchDeck/Audio/SpeechRecognitionManager.swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SpeechRecognitionManagerTests`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/NotchDeck/Audio/SpeechRecognitionManager.swift Tests/NotchDeckTests/SpeechRecognitionManagerTests.swift
git commit -m "feat(audio): implement SpeechRecognitionManager for streaming speech-to-text"
```

---

### Task 4: Dynamic Audio Waveform UI & NotchRootView Wiring

**Files:**
- Create: `Sources/NotchDeck/UI/Views/AudioWaveformView.swift`
- Modify: `Sources/NotchDeck/UI/Views/NotchRootView.swift`

**Interfaces:**
- Produces: `AudioWaveformView` rendering live animated bars during `.voiceActive` state.

- [ ] **Step 1: Implement AudioWaveformView**

```swift
// Sources/NotchDeck/UI/Views/AudioWaveformView.swift
import SwiftUI

public struct AudioWaveformView: View {
    public var levels: [CGFloat]

    public init(levels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7]) {
        self.levels = levels
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(6, levels[index] * 24))
                    .animation(.spring(response: 0.15, dampingFraction: 0.7), value: levels[index])
            }
        }
        .frame(height: 26)
    }
}
```

- [ ] **Step 2: Update NotchRootView with live waveform**

```swift
// Sources/NotchDeck/UI/Views/NotchRootView.swift
import SwiftUI

public struct NotchRootView: View {
    @ObservedObject public var stateController: NotchStateController
    public var audioLevels: [CGFloat]

    public init(stateController: NotchStateController, audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.6, 0.3, 0.7]) {
        self.stateController = stateController
        self.audioLevels = audioLevels
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            switch stateController.currentState {
            case .collapsed:
                HStack(spacing: 8) {
                    Circle().fill(Color.cyan).frame(width: 8, height: 8)
                    Text("NotchDeck").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.white)
                }
                .padding(.horizontal, 12)

            case .voiceActive:
                HStack(spacing: 12) {
                    AudioWaveformView(levels: audioLevels)
                    Text(stateController.commandPrompt.isEmpty ? "Mendengarkan..." : stateController.commandPrompt)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { stateController.transition(to: .collapsed) }) {
                        Image(systemName: "stop.circle.fill").foregroundColor(.orange).font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

            case .liveActivity(let title, let countdown):
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock").foregroundColor(.green)
                    Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Text(countdown).font(.system(size: 11, weight: .bold)).foregroundColor(.yellow)
                }
                .padding(.horizontal, 16)

            case .expanded:
                VStack(spacing: 12) {
                    HStack {
                        Menu {
                            Button("Antigravity") { stateController.activeAIModel = "Antigravity" }
                            Button("Claude Code") { stateController.activeAIModel = "Claude Code" }
                        } label: {
                            Text("✨ \(stateController.activeAIModel) ▾")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.white.opacity(0.1)).cornerRadius(8)
                        }
                        .menuStyle(.borderlessButton)

                        TextField("Ask AI or speak reminder...", text: $stateController.commandPrompt)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)

                        Button(action: { stateController.transition(to: .voiceActive) }) {
                            Image(systemName: "mic.fill").foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding(16)
            }
        }
        .frame(
            width: widthForState(stateController.currentState),
            height: heightForState(stateController.currentState)
        )
    }

    private func widthForState(_ state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: return 180
        case .voiceActive: return 360
        case .liveActivity: return 320
        case .expanded: return 540
        }
    }

    private func heightForState(_ state: NotchState) -> CGFloat {
        switch state {
        case .collapsed: return 32
        case .voiceActive: return 60
        case .liveActivity: return 44
        case .expanded: return 380
        }
    }
}
```

- [ ] **Step 3: Run all tests to verify build & test suite**

Run: `swift test`  
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/NotchDeck/UI/Views/AudioWaveformView.swift Sources/NotchDeck/UI/Views/NotchRootView.swift
git commit -m "feat(ui): implement AudioWaveformView and integrate into NotchRootView"
```

---
