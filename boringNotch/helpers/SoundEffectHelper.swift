//
//  SoundEffectHelper.swift
//  boringNotch
//
//  Created by Antigravity on 16/09/2026.
//

import AVFoundation
import AppKit
import Defaults

public final class ClickySoundEffects {
    public static let shared = ClickySoundEffects()
    private var players: [String: AVAudioPlayer] = [:]
    
    private init() {}
    
    public func play(_ name: String) {
        guard Defaults[.cursorAssistantSoundEnabled] else { return }
        
        if let player = players[name] {
            player.currentTime = 0
            player.play()
            return
        }
        
        let extensions = ["wav", "mp3"]
        var resolvedPath: String? = nil
        
        for ext in extensions {
            let candidates: [String?] = [
                Bundle.main.path(forResource: name, ofType: ext),
                Bundle.main.path(forResource: name, ofType: ext, inDirectory: "Sounds"),
                Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(name).\(ext)").path,
                Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Sounds/\(name).\(ext)").path,
                "boringNotch/Resources/Sounds/\(name).\(ext)",
                "heyclicky-reference/sounds/\(name).\(ext)"
            ]
            
            for candidate in candidates {
                if let candidate = candidate, FileManager.default.fileExists(atPath: candidate) {
                    resolvedPath = candidate
                    break
                }
            }
            if resolvedPath != nil { break }
        }
        
        guard let validPath = resolvedPath else { return }
        let url = URL(fileURLWithPath: validPath)
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            players[name] = player
        } catch {
            // Fallback silently if audio player encounters system error
        }
    }
}
