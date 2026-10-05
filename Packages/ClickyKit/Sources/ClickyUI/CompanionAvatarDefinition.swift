//
//  CompanionAvatarDefinition.swift
//  izaNotch
//
//  Autentik 1:1 Porting dari Bible Strong Avatar Lab (smontlouis/bible-strong-avatar-lab)
//  Spesifikasi Schema: "bible-strong/avatar-definition" v1 (Strobi Model)
//

import SwiftUI
import Foundation
import ClickyFoundation

// MARK: - 1. Geometri Permukaan Tubuh 3D (Surface & Body)
public struct AvatarSurfaceConfig: Codable, Equatable, Sendable {
    public var type: String // "sphere", "capsule", "cube", "cursor", etc.
    public var width: Double
    public var height: Double
    public var depth: Double
    public var roundness: Double

    public init(
        type: String = "sphere",
        width: Double = 240.0,
        height: Double = 240.0,
        depth: Double = 240.0,
        roundness: Double = 1.0
    ) {
        self.type = type
        self.width = width
        self.height = height
        self.depth = depth
        self.roundness = roundness
    }
}

public struct AvatarBodyNode: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var surface: AvatarSurfaceConfig
    public var positionX: Double
    public var positionY: Double
    public var positionZ: Double
    public var rotationX: Double
    public var rotationY: Double
    public var rotationZ: Double

    public init(
        id: String,
        name: String,
        surface: AvatarSurfaceConfig,
        positionX: Double = 0.0,
        positionY: Double = 0.0,
        positionZ: Double = 0.0,
        rotationX: Double = 0.0,
        rotationY: Double = 0.0,
        rotationZ: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.surface = surface
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.rotationX = rotationX
        self.rotationY = rotationY
        self.rotationZ = rotationZ
    }
}

public struct AvatarBody: Codable, Equatable, Sendable {
    public var primary: AvatarSurfaceConfig
    public var nodes: [AvatarBodyNode]

    public init(
        primary: AvatarSurfaceConfig = AvatarSurfaceConfig(),
        nodes: [AvatarBodyNode] = []
    ) {
        self.primary = primary
        self.nodes = nodes
    }
}

// MARK: - 2. Palet Warna Autentik Strobi (Head & Eyes)
public struct AvatarColors: Codable, Equatable, Sendable {
    public var bodyHex: String
    public var eyesHex: String

    public init(bodyHex: String = "#5b7fe5", eyesHex: String = "#111316") {
        self.bodyHex = bodyHex
        self.eyesHex = eyesHex
    }

    enum CodingKeys: String, CodingKey {
        case bodyHex = "body"
        case eyesHex = "eyes"
    }

    public var bodyColor: Color {
        Color(hex: bodyHex)
    }

    public var eyesColor: Color {
        Color(hex: eyesHex)
    }
}

// MARK: - 3. Model Ekspresi 3D (Strobi Expression: Euler Head + Pill Eyes)
public struct AvatarExpression: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var headX: Double       // Pitch rotasi kepala 3D (derajat)
    public var headY: Double       // Yaw rotasi kepala 3D (derajat)
    public var headZ: Double       // Roll rotasi kepala 3D (derajat)
    public var widthLeft: Double   // Lebar kapsul mata kiri
    public var widthRight: Double  // Lebar kapsul mata kanan
    public var heightLeft: Double  // Tinggi kapsul mata kiri
    public var heightRight: Double // Tinggi kapsul mata kanan
    public var spacing: Double     // Jarak antar kedua mata
    public var positionXLeft: Double
    public var positionXRight: Double
    public var positionYLeft: Double  // Latitude posisi mata kiri
    public var positionYRight: Double // Latitude posisi mata kanan
    public var leftAngle: Double      // Kemiringan sudut mata kiri (derajat)
    public var rightAngle: Double     // Kemiringan sudut mata kanan (derajat)
    public var perspective: Double    // Kekuatan perspektif 3D (default: 1.0)
    public var bodyColorHex: String?  // Dynamic body chromatic color override (1:1 Avatar Lab)
    public var eyeColorHex: String?   // Dynamic eye chromatic color override (1:1 Avatar Lab)
    public var bodyMotion: String?    // Body motion ("shake", "slowDrift", "none")
    public var eyeMotion: String?     // Eye motion ("shake", "none")

    public init(
        id: String = "neutral",
        headX: Double = 0.0,
        headY: Double = 0.0,
        headZ: Double = 0.0,
        widthLeft: Double = 27.13,
        widthRight: Double = 27.13,
        heightLeft: Double = 63.03,
        heightRight: Double = 63.03,
        spacing: Double = 48.0,
        positionXLeft: Double = 0.0,
        positionXRight: Double = 0.0,
        positionYLeft: Double = -7.0,
        positionYRight: Double = -7.0,
        leftAngle: Double = 0.0,
        rightAngle: Double = 0.0,
        perspective: Double = 1.0,
        bodyColorHex: String? = nil,
        eyeColorHex: String? = nil,
        bodyMotion: String? = nil,
        eyeMotion: String? = nil
    ) {
        self.id = id
        self.headX = headX
        self.headY = headY
        self.headZ = headZ
        self.widthLeft = widthLeft
        self.widthRight = widthRight
        self.heightLeft = heightLeft
        self.heightRight = heightRight
        self.spacing = spacing
        self.positionXLeft = positionXLeft
        self.positionXRight = positionXRight
        self.positionYLeft = positionYLeft
        self.positionYRight = positionYRight
        self.leftAngle = leftAngle
        self.rightAngle = rightAngle
        self.perspective = perspective
        self.bodyColorHex = bodyColorHex
        self.eyeColorHex = eyeColorHex
        self.bodyMotion = bodyMotion
        self.eyeMotion = eyeMotion
    }

    public static func nearestEquivalentAngle(target: Double, current: Double) -> Double {
        var result = target
        while result - current > 180.0 { result -= 360.0 }
        while result - current < -180.0 { result += 360.0 }
        return max(-365.0, min(365.0, result))
    }

    public static func interpolateColorHex(from: String?, to: String?, progress: Double) -> String? {
        guard from != nil || to != nil else { return nil }
        guard let f = from, let t = to else {
            return progress > 0.5 ? to : from
        }
        let p = max(0.0, min(1.0, progress))
        func parseRGB(_ hex: String) -> (Double, Double, Double) {
            var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
            if clean.count == 3 {
                clean = clean.map { "\($0)\($0)" }.joined()
            }
            guard let val = UInt64(clean, radix: 16) else { return (1.0, 1.0, 1.0) }
            let r = Double((val >> 16) & 0xFF) / 255.0
            let g = Double((val >> 8) & 0xFF) / 255.0
            let b = Double(val & 0xFF) / 255.0
            return (r, g, b)
        }
        let (r1, g1, b1) = parseRGB(f)
        let (r2, g2, b2) = parseRGB(t)
        let r = Int(round((r1 + (r2 - r1) * p) * 255.0))
        let g = Int(round((g1 + (g2 - g1) * p) * 255.0))
        let b = Int(round((b1 + (b2 - b1) * p) * 255.0))
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }

    public func interpolated(to target: AvatarExpression, progress: Double) -> AvatarExpression {
        let p = max(0.0, min(1.0, progress))
        let targetHeadX = AvatarExpression.nearestEquivalentAngle(target: target.headX, current: self.headX)
        let targetHeadY = AvatarExpression.nearestEquivalentAngle(target: target.headY, current: self.headY)
        let targetHeadZ = AvatarExpression.nearestEquivalentAngle(target: target.headZ, current: self.headZ)
        let targetLeftAngle = AvatarExpression.nearestEquivalentAngle(target: target.leftAngle, current: self.leftAngle)
        let targetRightAngle = AvatarExpression.nearestEquivalentAngle(target: target.rightAngle, current: self.rightAngle)

        let interpolatedBodyColor = AvatarExpression.interpolateColorHex(from: self.bodyColorHex, to: target.bodyColorHex, progress: p)
        let interpolatedEyeColor = AvatarExpression.interpolateColorHex(from: self.eyeColorHex, to: target.eyeColorHex, progress: p)

        return AvatarExpression(
            id: target.id,
            headX: self.headX + (targetHeadX - self.headX) * p,
            headY: self.headY + (targetHeadY - self.headY) * p,
            headZ: self.headZ + (targetHeadZ - self.headZ) * p,
            widthLeft: self.widthLeft + (target.widthLeft - self.widthLeft) * p,
            widthRight: self.widthRight + (target.widthRight - self.widthRight) * p,
            heightLeft: self.heightLeft + (target.heightLeft - self.heightLeft) * p,
            heightRight: self.heightRight + (target.heightRight - self.heightRight) * p,
            spacing: self.spacing + (target.spacing - self.spacing) * p,
            positionXLeft: self.positionXLeft + (target.positionXLeft - self.positionXLeft) * p,
            positionXRight: self.positionXRight + (target.positionXRight - self.positionXRight) * p,
            positionYLeft: self.positionYLeft + (target.positionYLeft - self.positionYLeft) * p,
            positionYRight: self.positionYRight + (target.positionYRight - self.positionYRight) * p,
            leftAngle: self.leftAngle + (targetLeftAngle - self.leftAngle) * p,
            rightAngle: self.rightAngle + (targetRightAngle - self.rightAngle) * p,
            perspective: self.perspective + (target.perspective - self.perspective) * p,
            bodyColorHex: interpolatedBodyColor,
            eyeColorHex: interpolatedEyeColor,
            bodyMotion: p > 0.5 ? target.bodyMotion : self.bodyMotion,
            eyeMotion: p > 0.5 ? target.eyeMotion : self.eyeMotion
        )
    }
}

// MARK: - Status Siklus Hidup Companion ke Preset Ekspresi Strobi
public enum CompanionLifecycleState: String, CaseIterable, Codable, Sendable {
    case idle
    case listening
    case thinking
    case working
    case done
    case alert
    case sleeping

    public var defaultExpressionName: String {
        switch self {
        case .idle: return "neutral"
        case .listening: return "attentive-left"
        case .thinking: return "curious-left"
        case .working: return "skeptical-right"
        case .done: return "joyful-down-right"
        case .alert: return "surprised-left"
        case .sleeping: return "eyes-closed"
        }
    }
}

// MARK: - Konfigurasi Kedipan Prosedural (Procedural Blink Config)
public struct AvatarBlinkConfig: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var minInterval: Double
    public var maxInterval: Double
    public var duration: Double

    public init(
        enabled: Bool = true,
        minInterval: Double = 2.8,
        maxInterval: Double = 5.2,
        duration: Double = 0.22
    ) {
        self.enabled = enabled
        self.minInterval = minInterval
        self.maxInterval = maxInterval
        self.duration = duration
    }
}

// MARK: - 4. Master Definition (Kompatibel 1:1 strobi.avatar.json)
public struct CompanionAvatarDefinition: Codable, Identifiable, Equatable, Sendable {
    public var schema: String
    public var schemaVersion: Int
    public var name: String
    public var body: AvatarBody
    public var colors: AvatarColors
    public var expressions: [String: AvatarExpression]
    public var animationOrder: [String]

    public var id: String {
        name.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    public init(
        schema: String = "bible-strong/avatar-definition",
        schemaVersion: Int = 1,
        name: String = "Strobi",
        body: AvatarBody = AvatarBody(),
        colors: AvatarColors = AvatarColors(),
        expressions: [String: AvatarExpression] = CompanionAvatarDefinition.bundledExpressions,
        animationOrder: [String] = CompanionAvatarDefinition.defaultAnimationOrder
    ) {
        self.schema = schema
        self.schemaVersion = schemaVersion
        self.name = name
        self.body = body
        self.colors = colors
        self.expressions = expressions
        self.animationOrder = animationOrder
    }
}

// MARK: - 5. 25 Calibrated Expressions Autentik dari Bible Strong Avatar Lab (presets.ts)
extension CompanionAvatarDefinition {
    public static let defaultAnimationOrder: [String] = [
        "idle", "listening", "thinking", "working", "happy", "curious",
        "surprised", "skeptical", "alert", "sleeping", "celebrate"
    ]

    public static let bundledExpressions: [String: AvatarExpression] = [
        "neutral": AvatarExpression(
            id: "neutral",
            headX: 0.0, headY: 0.0, headZ: 0.0,
            widthLeft: 27.13, widthRight: 27.13,
            heightLeft: 63.03, heightRight: 63.03,
            spacing: 48.0,
            positionYLeft: -7.0, positionYRight: -7.0,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "upward-side-glance": AvatarExpression(
            id: "upward-side-glance",
            headX: 7.3, headY: 27.8, headZ: -16.1,
            widthLeft: 24.2, widthRight: 27.6,
            heightLeft: 38.9, heightRight: 40.7,
            spacing: 54.3,
            positionYLeft: -20.5, positionYRight: -20.5,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "downward-gaze": AvatarExpression(
            id: "downward-gaze",
            headX: -35.6, headY: 0.7, headZ: -8.5,
            widthLeft: 29.4, widthRight: 27.3,
            heightLeft: 49.5, heightRight: 49.8,
            spacing: 57.7,
            positionYLeft: -42.0, positionYRight: -42.0,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "joyful-down-right": AvatarExpression(
            id: "joyful-down-right",
            headX: -36.2, headY: 13.1, headZ: 15.5,
            widthLeft: 44.3, widthRight: 51.3,
            heightLeft: 74.2, heightRight: 76.0,
            spacing: 68.7,
            positionYLeft: -40.7, positionYRight: -40.7,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "surprised-left": AvatarExpression(
            id: "surprised-left",
            headX: 15.6, headY: -16.5, headZ: -11.3,
            widthLeft: 54.0, widthRight: 51.0,
            heightLeft: 49.6, heightRight: 48.5,
            spacing: 70.9,
            positionYLeft: 30.1, positionYRight: 30.1,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "sleepy-squint": AvatarExpression(
            id: "sleepy-squint",
            headX: 3.4, headY: 13.0, headZ: 8.9,
            widthLeft: 42.6, widthRight: 44.0,
            heightLeft: 17.3, heightRight: 16.0,
            spacing: 57.9,
            positionYLeft: 4.9, positionYRight: 4.9,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "skeptical-right": AvatarExpression(
            id: "skeptical-right",
            headX: -17.7, headY: -1.4, headZ: -8.8,
            widthLeft: 29.5, widthRight: 19.2,
            heightLeft: 51.6, heightRight: 41.9,
            spacing: 56.3,
            positionYLeft: 0.0, positionYRight: 0.0,
            leftAngle: 0.0, rightAngle: 90.0
        ),
        "curious-left": AvatarExpression(
            id: "curious-left",
            headX: -22.8, headY: -15.9, headZ: 6.2,
            widthLeft: 44.5, widthRight: 43.9,
            heightLeft: 32.3, heightRight: 24.6,
            spacing: 54.9,
            positionYLeft: -42.0, positionYRight: -42.0,
            leftAngle: -60.9, rightAngle: 69.2
        ),
        "attentive-left": AvatarExpression(
            id: "attentive-left",
            headX: 20.3, headY: 7.0, headZ: 8.7,
            widthLeft: 30.2, widthRight: 28.1,
            heightLeft: 48.8, heightRight: 49.2,
            spacing: 56.8,
            positionYLeft: 39.9, positionYRight: 39.9,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "joyful-wide": AvatarExpression(
            id: "joyful-wide",
            headX: 17.5, headY: -15.2, headZ: -8.7,
            widthLeft: 51.0, widthRight: 49.2,
            heightLeft: 75.3, heightRight: 73.4,
            spacing: 70.2,
            positionYLeft: 41.6, positionYRight: 41.6,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "eyes-closed": AvatarExpression(
            id: "eyes-closed",
            headX: -6.0, headY: -7.7, headZ: -9.4,
            widthLeft: 43.6, widthRight: 42.8,
            heightLeft: 8.0, heightRight: 8.0,
            spacing: 57.9,
            positionYLeft: 3.5, positionYRight: 3.5,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "angry-left": AvatarExpression(
            id: "angry-left",
            headX: 3.5, headY: -16.1, headZ: 15.8,
            widthLeft: 51.0, widthRight: 48.5,
            heightLeft: 34.9, heightRight: 33.0,
            spacing: 55.1,
            positionYLeft: 41.9, positionYRight: 41.9,
            leftAngle: 80.0, rightAngle: -62.2
        ),
        "angry-brows": AvatarExpression(
            id: "angry-brows",
            headX: 10.47, headY: 5.09, headZ: 4.70,
            widthLeft: 27.13, widthRight: 27.13,
            heightLeft: 63.03, heightRight: 63.03,
            spacing: 68.7,
            positionYLeft: 0.0, positionYRight: 0.0,
            leftAngle: -36.24, rightAngle: 27.73,
            perspective: 1.0,
            bodyColorHex: "#ba3636",
            eyeColorHex: "#610000",
            bodyMotion: "shake",
            eyeMotion: "none"
        ),
        "hover-round": AvatarExpression(
            id: "hover-round",
            headX: 0.0, headY: 0.0, headZ: 0.0,
            widthLeft: 40.0, widthRight: 40.0,
            heightLeft: 40.0, heightRight: 40.0,
            spacing: 48.0,
            positionYLeft: -14.0, positionYRight: -14.0,
            leftAngle: 0.0, rightAngle: 0.0
        ),
        "hover-focus-upright": AvatarExpression(
            id: "hover-focus-upright",
            headX: 20.0,
            headY: 22.0,
            headZ: -14.0,
            widthLeft: 44.0,
            widthRight: 30.0,
            heightLeft: 40.0,
            heightRight: 36.0,
            spacing: 56.0,
            positionYLeft: -16.0,
            positionYRight: -16.0,
            leftAngle: -6.0,
            rightAngle: 10.0,
            perspective: 1.0,
            bodyColorHex: nil,
            eyeColorHex: nil,
            bodyMotion: "none",
            eyeMotion: "none"
        ),
        "drowsy-closed": AvatarExpression(
            id: "drowsy-closed",
            headX: 10.29, headY: 3.40, headZ: 7.58,
            widthLeft: 55.67, widthRight: 55.67,
            heightLeft: 14.62, heightRight: 14.62,
            spacing: 68.42,
            positionYLeft: 0.0, positionYRight: 0.0,
            leftAngle: 0.0, rightAngle: 0.0,
            perspective: 1.0,
            bodyMotion: "none",
            eyeMotion: "none"
        ),
        "preset-22": AvatarExpression(
            id: "preset-22",
            headX: 10.29, headY: 3.40, headZ: 7.58,
            widthLeft: 55.67, widthRight: 55.67,
            heightLeft: 14.62, heightRight: 14.62,
            spacing: 68.42,
            positionYLeft: 0.0, positionYRight: 0.0,
            leftAngle: 0.0, rightAngle: 0.0,
            perspective: 1.0,
            bodyMotion: "none",
            eyeMotion: "none"
        ),
        "preset-25": AvatarExpression(
            id: "preset-25",
            headX: 10.47, headY: 5.09, headZ: 4.70,
            widthLeft: 27.13, widthRight: 27.13,
            heightLeft: 63.03, heightRight: 63.03,
            spacing: 68.7,
            positionYLeft: 0.0, positionYRight: 0.0,
            leftAngle: -36.24, rightAngle: 27.73,
            perspective: 1.0,
            bodyColorHex: "#ba3636",
            eyeColorHex: "#610000",
            bodyMotion: "shake",
            eyeMotion: "none"
        ),
        "uneasy-left": AvatarExpression(
            id: "uneasy-left",
            headX: 0.0, headY: 0.0, headZ: 0.0,
            widthLeft: 20.61, widthRight: 20.61,
            heightLeft: 47.77, heightRight: 47.77,
            spacing: 54.9,
            positionYLeft: 0.0, positionYRight: 0.0,
            leftAngle: 23.52, rightAngle: -24.04,
            perspective: 1.0,
            bodyColorHex: "#adc3ff",
            eyeColorHex: "#111316",
            bodyMotion: "slowDrift",
            eyeMotion: "shake"
        ),
        "preset-26": AvatarExpression(
            id: "preset-26",
            headX: 0.0, headY: 0.0, headZ: 0.0,
            widthLeft: 20.61, widthRight: 20.61,
            heightLeft: 47.77, heightRight: 47.77,
            spacing: 54.9,
            positionYLeft: 0.0, positionYRight: 0.0,
            leftAngle: 23.52, rightAngle: -24.04,
            perspective: 1.0,
            bodyColorHex: "#adc3ff",
            eyeColorHex: "#111316",
            bodyMotion: "slowDrift",
            eyeMotion: "shake"
        ),
        "sad-downward": AvatarExpression(
            id: "sad-downward",
            headX: -12.30, headY: -17.60, headZ: 5.91,
            widthLeft: 20.61, widthRight: 20.61,
            heightLeft: 47.77, heightRight: 47.77,
            spacing: 54.9,
            positionYLeft: 0.0, positionYRight: 0.0,
            leftAngle: 23.52, rightAngle: -24.04,
            perspective: 1.0,
            bodyColorHex: "#adc3ff",
            eyeColorHex: "#111316",
            bodyMotion: "slowDrift",
            eyeMotion: "shake"
        ),
        "playful-right": AvatarExpression(
            id: "playful-right",
            headX: -17.3, headY: 11.2, headZ: -9.1,
            widthLeft: 24.2, widthRight: 44.5,
            heightLeft: 44.5, heightRight: 32.2,
            spacing: 55.0,
            positionYLeft: -36.5, positionYRight: -36.5,
            leftAngle: 18.5, rightAngle: 67.9
        ),
        "shy-downward": AvatarExpression(
            id: "shy-downward",
            headX: -29.6, headY: 7.5, headZ: 10.1,
            widthLeft: 21.5, widthRight: 23.2,
            heightLeft: 32.0, heightRight: 33.5,
            spacing: 51.2,
            positionYLeft: -37.4, positionYRight: -37.4,
            leftAngle: 0.0, rightAngle: 0.0
        )
    ]
}

// MARK: - 6. Presets Companion Izanotchy Berbasis Strobi Model
extension CompanionAvatarDefinition {
    /// 1. Clicky (Strobi Classic - Biru Periwinkle / Cornflower)
    public static let defaultClicky = CompanionAvatarDefinition(
        name: "Clicky (Strobi)",
        colors: AvatarColors(bodyHex: "#5b7fe5", eyesHex: "#111316")
    )

    /// 2. Market Scout (Futures Radar - Ungu Elektrik)
    public static let defaultMarketScout = CompanionAvatarDefinition(
        name: "Market Scout",
        colors: AvatarColors(bodyHex: "#8B5CF6", eyesHex: "#0D0E12")
    )

    /// 3. Research Buddy (Exa & Deep Research - Hijau Zamrud)
    public static let defaultResearchBuddy = CompanionAvatarDefinition(
        name: "Research Buddy",
        colors: AvatarColors(bodyHex: "#10B981", eyesHex: "#0F172A")
    )

    /// 4. Shippy (Outbound & Production - Oranye Hangat)
    public static let defaultShippy = CompanionAvatarDefinition(
        name: "Shippy",
        colors: AvatarColors(bodyHex: "#F97316", eyesHex: "#18181B")
    )

    /// 5. Grok Bot (White Edition - Pure White Body #FFFFFF, Deep Obsidian Eyes #111316)
    public static let defaultGrokBotWhite = CompanionAvatarDefinition(
        name: "Grok Bot (White)",
        colors: AvatarColors(bodyHex: "#FFFFFF", eyesHex: "#111316")
    )
}
