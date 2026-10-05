import ClickyFoundation
//
//  ElevenLabsTTSClient.swift
//  leanring-buddy
//
//  Streams text-to-speech audio from ElevenLabs and plays it back
//  through the system audio output. Uses the streaming endpoint so
//  playback begins before the full audio has been generated.
//

import AVFoundation
import Foundation

@MainActor
public final class ElevenLabsTTSClient {
    private let proxyURL: URL
    private let session: URLSession

    /// The audio player for the current TTS playback. Kept alive so the
    /// audio finishes playing even if the caller doesn't hold a reference.
    private var audioPlayer: AVAudioPlayer?

    /// Plan perbaikan 22 Sep (3.3): durasi audio terakhir (dtk) untuk hold bubble.
    /// Diisi saat play(); 0 bila belum pernah bunyi / fallback NSSpeech.
    public var lastSpokenDuration: TimeInterval = 0

    public init(proxyURL: String) {
        self.proxyURL = URL(string: proxyURL)!

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    /// Sends `text` to ElevenLabs TTS and plays the resulting audio.
    /// Throws on network or decoding errors. Cancellation-safe.
    public func speakText(_ text: String) async throws {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_flash_v2_5",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ElevenLabsTTS", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ElevenLabsTTS", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "TTS API error (\(httpResponse.statusCode)): \(errorBody)"])
        }

        try Task.checkCancellation()

        let player = try AVAudioPlayer(data: data)
        self.audioPlayer = player
        player.play()
        // Plan perbaikan 22 Sep (3.3): expose durasi riil + event saat play.
        // Audit: estimasi hanya sebelum-await; tanpa ini bubble tak hold audio.
        lastSpokenDuration = player.duration
        NotificationCenter.default.post(name: .clickyTTSStarted, object: nil)
        print("🔊 ElevenLabs TTS: playing \(data.count / 1024)KB audio (\(String(format: "%.1f", player.duration))s)")
    }

    /// Whether TTS audio is currently playing back.
    public var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }

    /// Stops any in-progress playback immediately.
    public func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
