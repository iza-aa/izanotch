//
//  ClickySoundEngine.swift
//  izaNotch / Clicky
//
//  Dedicated low-latency sound effects engine for HeyClicky audio UI chimes.
//

import Foundation
import AVFoundation
import AppKit
import Defaults

/// High-performance audio feedback engine for Clicky companion interactions.
@MainActor
final class ClickySoundEngine {
    static let shared = ClickySoundEngine()

    enum SoundEffect: String, CaseIterable {
        case open = "clicky-text-open"
        case send = "clicky-text-send"
        case receive = "clicky-text-receive"
        case question = "clicky-question"
        case close = "clicky-text-close"
        case done = "agent-done"

        var filename: String {
            return "\(self.rawValue).wav"
        }
    }

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private var isInitialized = false

    private init() {
        preloadSounds()
    }

    /// Pre-load audio buffers to eliminate cold-start audio lag and pop/crackle
    func preloadSounds() {
        guard !isInitialized else { return }
        isInitialized = true

        for sound in SoundEffect.allCases {
            if let url = resolveAudioURL(for: sound) {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    player.volume = 0.85
                    players[sound] = player
                    ClickyLogger.info("[SOUND]", "Preloaded audio chime: \(sound.rawValue)")
                } catch {
                    ClickyLogger.warning("[SOUND]", "Failed to load audio chime \(sound.rawValue): \(error.localizedDescription)")
                }
            }
        }
    }

    /// Play a specific sound effect with low latency
    func play(_ sound: SoundEffect, volume: Float = 0.85) {
        guard Defaults[.cursorAssistantSoundEnabled] else {
            return
        }

        if let player = players[sound] {
            player.volume = volume
            if player.isPlaying {
                player.currentTime = 0
            }
            player.play()
            ClickyLogger.info("[SOUND]", "Played chime: \(sound.rawValue)")
        } else if let url = resolveAudioURL(for: sound) {
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = volume
                player.play()
                players[sound] = player
                ClickyLogger.info("[SOUND]", "Played chime (lazy loaded): \(sound.rawValue)")
            } else if let nsSound = NSSound(contentsOf: url, byReference: true) {
                nsSound.volume = volume
                nsSound.play()
                ClickyLogger.info("[SOUND]", "Played chime via NSSound fallback: \(sound.rawValue)")
            }
        }
    }

    /// Resolve audio file URL across App Bundle, local Clicky Resources, and mounted DMG
    private func resolveAudioURL(for sound: SoundEffect) -> URL? {
        let baseName = sound.rawValue

        // 1. App Bundle Resources root
        if let url = Bundle.main.url(forResource: baseName, withExtension: "wav") {
            return url
        }

        // 2. App Bundle Resources/Sounds subdirectory
        if let url = Bundle.main.url(forResource: baseName, withExtension: "wav", subdirectory: "Sounds") {
            return url
        }

        // 3. Development local path
        let devPath = "/Users/heizaaa/Desktop/cdev/izanotch/izanotch-app/boringNotch/Clicky/Resources/Sounds/\(sound.filename)"
        if FileManager.default.fileExists(atPath: devPath) {
            return URL(fileURLWithPath: devPath)
        }

        // 4. Mounted DMG fallback
        let dmgPath = "/tmp/cursorassist_mount/HeyClicky.app/Contents/Resources/\(sound.filename)"
        if FileManager.default.fileExists(atPath: dmgPath) {
            return URL(fileURLWithPath: dmgPath)
        }

        return nil
    }
}
