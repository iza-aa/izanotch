//
//  CompanionAvatarLabCatalog.swift
//  izaNotch
//
//  Autentik Ground Truth dari Bible Strong Avatar Lab (smontlouis/bible-strong-avatar-lab)
//  Memuat 11 Character Templates, 27 Calibrated Presets (00-26), dan 23 Animation Sequences.
//

import SwiftUI
import Foundation
import ClickyFoundation
import ClickyRoster

// MARK: - 1. Struktur Data Katalog Avatar Lab

public struct AvatarEyeDefaults: Codable, Equatable, Sendable {
    public var widthLeft: Double
    public var widthRight: Double
    public var heightLeft: Double
    public var heightRight: Double
    public var spacing: Double
    public var positionXLeft: Double
    public var positionXRight: Double
    public var positionYLeft: Double
    public var positionYRight: Double
    public var leftAngle: Double
    public var rightAngle: Double

    public init(
        widthLeft: Double = 20.0,
        widthRight: Double = 20.0,
        heightLeft: Double = 50.0,
        heightRight: Double = 50.0,
        spacing: Double = 35.0,
        positionXLeft: Double = 0.0,
        positionXRight: Double = 0.0,
        positionYLeft: Double = -7.0,
        positionYRight: Double = -7.0,
        leftAngle: Double = 0.0,
        rightAngle: Double = 0.0
    ) {
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
    }
}

public struct AvatarLabTemplate: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var body: AvatarBody
    public var defaultColors: AvatarColors
    public var defaultEyes: AvatarEyeDefaults
    public var iconName: String

    public init(
        id: String,
        name: String,
        body: AvatarBody,
        defaultColors: AvatarColors,
        defaultEyes: AvatarEyeDefaults,
        iconName: String
    ) {
        self.id = id
        self.name = name
        self.body = body
        self.defaultColors = defaultColors
        self.defaultEyes = defaultEyes
        self.iconName = iconName
    }

    public func toAvatarDefinition(name: String? = nil, cloudColorHex: String? = nil, eyesHex: String? = nil) -> CompanionAvatarDefinition {
        let bHex = (cloudColorHex?.isEmpty == false) ? cloudColorHex! : defaultColors.bodyHex
        let eHex = (eyesHex?.isEmpty == false) ? eyesHex! : defaultColors.eyesHex
        return CompanionAvatarDefinition(
            name: name ?? self.name,
            body: body,
            colors: AvatarColors(bodyHex: bHex, eyesHex: eHex)
        )
    }
}

public struct AvatarLabPreset: Identifiable, Sendable {
    public var index: Int
    public var id: String
    public var semanticKey: String
    public var expression: AvatarExpression

    public var badgeNumber: String {
        String(format: "%02d", index)
    }

    public var displayName: String {
        semanticKey.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    public init(
        index: Int,
        id: String,
        semanticKey: String,
        expression: AvatarExpression
    ) {
        self.index = index
        self.id = id
        self.semanticKey = semanticKey
        self.expression = expression
    }
}

public enum AvatarAnimationCategory: String, CaseIterable, Sendable {
    case lifeCycle = "Life Cycle"
    case reaction = "Reactions"
}

public struct AvatarAnimationStep: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var expressionId: String
    public var expressionIndex: Int
    public var semanticKey: String
    public var holdMs: Int
    public var transitionMs: Int

    public init(
        id: String,
        expressionId: String,
        expressionIndex: Int,
        semanticKey: String,
        holdMs: Int,
        transitionMs: Int
    ) {
        self.id = id
        self.expressionId = expressionId
        self.expressionIndex = expressionIndex
        self.semanticKey = semanticKey
        self.holdMs = holdMs
        self.transitionMs = transitionMs
    }
}

public struct AvatarLabAnimation: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var semanticKey: String
    public var category: AvatarAnimationCategory
    public var steps: [AvatarAnimationStep]
    public var iconName: String

    public var displayName: String {
        name.capitalized
    }

    public var totalDurationMs: Int {
        steps.reduce(0) { $0 + $1.holdMs + $1.transitionMs }
    }

    public init(
        id: String,
        name: String,
        semanticKey: String,
        category: AvatarAnimationCategory,
        steps: [AvatarAnimationStep],
        iconName: String
    ) {
        self.id = id
        self.name = name
        self.semanticKey = semanticKey
        self.category = category
        self.steps = steps
        self.iconName = iconName
    }
}

// MARK: - 2. Katalog Lengkap Avatar Lab
public struct CompanionAvatarLabCatalog {
    // MARK: - 11 Character Templates Autentik
    public static let allTemplates: [AvatarLabTemplate] = [
        AvatarLabTemplate(
            id: "strobi",
            name: "Strobi",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "sphere",
                    width: 240.00,
                    height: 240.00,
                    depth: 240.04,
                    roundness: 1.00
                ),
                nodes: [
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#5b7fe5",
                eyesHex: "#111316"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 20.00,
                widthRight: 20.00,
                heightLeft: 50.00,
                heightRight: 50.00,
                spacing: 35.00,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: -7.00,
                positionYRight: -7.00,
                leftAngle: 0.00,
                rightAngle: 0.00
            ),
            iconName: "circle.fill"
        ),
        AvatarLabTemplate(
            id: "avatar-4fe2d1bd-cf46-4e5e-a62d-d6b60be519ed",
            name: "Freddy",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "cube",
                    width: 174.73,
                    height: 149.47,
                    depth: 125.60,
                    roundness: 0.76
                ),
                nodes: [
                    AvatarBodyNode(
                        id: "shape-1089630b-c718-4abb-9891-aa817d0a26c0",
                        name: "Sphère 1",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 81.60,
                            height: 81.60,
                            depth: 37.97,
                            roundness: 1.00
                        ),
                        positionX: -82.00,
                        positionY: -72.00,
                        positionZ: -18.00,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-6c5a8bdd-04b7-4581-8889-cf8e1af5246e",
                        name: "Sphère 2",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 81.60,
                            height: 81.60,
                            depth: 37.02,
                            roundness: 1.00
                        ),
                        positionX: 82.00,
                        positionY: -72.00,
                        positionZ: -18.00,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-68a52731-6b5b-487d-8508-dd3c6cebf781",
                        name: "Cylindre 3",
                        surface: AvatarSurfaceConfig(
                            type: "cylinder",
                            width: 59.48,
                            height: 63.46,
                            depth: 73.10,
                            roundness: 1.50
                        ),
                        positionX: -1.02,
                        positionY: -72.00,
                        positionZ: -18.00,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#e6855c",
                eyesHex: "#ffffff"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 28.93,
                widthRight: 28.93,
                heightLeft: 60.84,
                heightRight: 60.84,
                spacing: 47.38,
                positionXLeft: -0.12,
                positionXRight: -0.12,
                positionYLeft: -4.31,
                positionYRight: -4.31,
                leftAngle: 0.00,
                rightAngle: 0.00
            ),
            iconName: "teddybear.fill"
        ),
        AvatarLabTemplate(
            id: "avatar-295e74a7-5d70-4d61-83d4-7beebb22bdd8",
            name: "Citrus",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "cone",
                    width: 252.71,
                    height: 274.97,
                    depth: 225.00,
                    roundness: 0.00
                ),
                nodes: [
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#ffcf24",
                eyesHex: "#000000"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 20.00,
                widthRight: 20.00,
                heightLeft: 50.00,
                heightRight: 50.00,
                spacing: 35.00,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 22.95,
                positionYRight: 22.95,
                leftAngle: 0.00,
                rightAngle: 0.00
            ),
            iconName: "drop.fill"
        ),
        AvatarLabTemplate(
            id: "avatar-1786600724626",
            name: "Nova",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "capsule",
                    width: 205.00,
                    height: 270.00,
                    depth: 205.00,
                    roundness: 1.00
                ),
                nodes: [
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#55b6c3",
                eyesHex: "#111316"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 13.26,
                widthRight: 13.26,
                heightLeft: 26.07,
                heightRight: 46.99,
                spacing: 19.77,
                positionXLeft: -12.97,
                positionXRight: -12.97,
                positionYLeft: 0.80,
                positionYRight: -6.37,
                leftAngle: -7.49,
                rightAngle: -7.80
            ),
            iconName: "capsule.fill"
        ),
        AvatarLabTemplate(
            id: "avatar-7874f78a-93ec-4536-a3b6-bb53ed744efd",
            name: "Grok bot",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "sphere",
                    width: 240.00,
                    height: 240.00,
                    depth: 240.00,
                    roundness: 1.00
                ),
                nodes: [
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#000000",
                eyesHex: "#ffffff"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 20.00,
                widthRight: 20.00,
                heightLeft: 50.00,
                heightRight: 50.00,
                spacing: 35.00,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: -7.00,
                positionYRight: -7.00,
                leftAngle: 0.00,
                rightAngle: 0.00
            ),
            iconName: "sparkle"
        ),
        AvatarLabTemplate(
            id: "avatar-1b2ee9c6-a6c5-4054-87e7-fec24f285269",
            name: "Sunee",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "sphere",
                    width: 182.96,
                    height: 185.55,
                    depth: 100.01,
                    roundness: 1.00
                ),
                nodes: [
                    AvatarBodyNode(
                        id: "shape-38130162-a15b-4fa8-a58b-9c74b07e1a25",
                        name: "Sphère 1",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 60.00,
                            height: 60.00,
                            depth: 24.38,
                            roundness: 1.00
                        ),
                        positionX: -94.48,
                        positionY: -95.45,
                        positionZ: -10.40,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-f987c6e1-02e3-4256-9053-655414890a3c",
                        name: "Sphère 1 copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 59.58,
                            height: 59.58,
                            depth: 24.20,
                            roundness: 1.00
                        ),
                        positionX: -6.44,
                        positionY: -133.98,
                        positionZ: -10.40,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-0f31bd3d-2d53-4c9d-a5e0-d587d6ef9b8c",
                        name: "Sphère 1 copie copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 81.60,
                            height: 81.60,
                            depth: 33.15,
                            roundness: 1.00
                        ),
                        positionX: 89.09,
                        positionY: -114.30,
                        positionZ: -10.40,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-9a17a167-46fb-4871-9252-24abbb80b1ca",
                        name: "Sphère 1 copie copie copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 70.12,
                            height: 70.12,
                            depth: 28.49,
                            roundness: 1.00
                        ),
                        positionX: 132.25,
                        positionY: -11.70,
                        positionZ: -10.40,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-e6574431-f8b6-482f-89d0-c280a327461f",
                        name: "Sphère 1 copie copie copie copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 61.90,
                            height: 61.90,
                            depth: 25.15,
                            roundness: 1.00
                        ),
                        positionX: -138.13,
                        positionY: -1.18,
                        positionZ: -10.40,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-5bc8f568-1cbb-4419-84bc-ce264b218a02",
                        name: "Sphère 1 copie copie copie copie copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 61.11,
                            height: 61.11,
                            depth: 24.83,
                            roundness: 1.00
                        ),
                        positionX: -103.29,
                        positionY: 92.40,
                        positionZ: -10.40,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-405e86d3-93c9-4de8-a15e-9ae1ba33c88c",
                        name: "Sphère 1 copie copie copie copie copie copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 61.73,
                            height: 61.73,
                            depth: 25.08,
                            roundness: 1.00
                        ),
                        positionX: -2.49,
                        positionY: 133.07,
                        positionZ: -10.40,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-0abdf33f-450d-4125-9354-b02842084138",
                        name: "Sphère 1 copie copie copie copie copie copie copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 64.12,
                            height: 64.12,
                            depth: 26.05,
                            roundness: 1.00
                        ),
                        positionX: 109.54,
                        positionY: 83.98,
                        positionZ: -10.40,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#e69a5c",
                eyesHex: "#111316"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 20.00,
                widthRight: 20.00,
                heightLeft: 50.00,
                heightRight: 50.00,
                spacing: 35.00,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: -7.00,
                positionYRight: -7.00,
                leftAngle: 0.00,
                rightAngle: 0.00
            ),
            iconName: "sun.max.fill"
        ),
        AvatarLabTemplate(
            id: "avatar-b6362e59-81a3-4334-a399-a721b23cf553",
            name: "Kirby",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "sphere",
                    width: 240.00,
                    height: 240.00,
                    depth: 240.00,
                    roundness: 1.00
                ),
                nodes: [
                    AvatarBodyNode(
                        id: "shape-2f26b4c0-61de-4fde-ae09-c4595cdaab59",
                        name: "Sphère 1",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 108.11,
                            height: 81.60,
                            depth: 81.60,
                            roundness: 1.00
                        ),
                        positionX: -103.30,
                        positionY: 30.44,
                        positionZ: -9.78,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: -14.84
                    ),
                    AvatarBodyNode(
                        id: "shape-3cd1a09e-b9a8-4271-95b1-4c21a09a6580",
                        name: "Sphère 1 copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 108.11,
                            height: 81.60,
                            depth: 81.60,
                            roundness: 1.00
                        ),
                        positionX: 98.15,
                        positionY: 32.55,
                        positionZ: -9.78,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 15.18
                    ),
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#ffc2e9",
                eyesHex: "#3e4e65"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 20.00,
                widthRight: 20.00,
                heightLeft: 60.47,
                heightRight: 60.47,
                spacing: 28.75,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: -7.00,
                positionYRight: -7.00,
                leftAngle: 0.00,
                rightAngle: 0.00
            ),
            iconName: "heart.fill"
        ),
        AvatarLabTemplate(
            id: "avatar-fafdaf4d-2071-41d6-9d42-7d34670956f0",
            name: "Cloudee",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "sphere",
                    width: 159.79,
                    height: 159.79,
                    depth: 159.78,
                    roundness: 1.00
                ),
                nodes: [
                    AvatarBodyNode(
                        id: "shape-3e98b39e-4765-4895-9309-3d0dd55bd316",
                        name: "Sphère 1",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 81.60,
                            height: 81.60,
                            depth: 81.60,
                            roundness: 1.00
                        ),
                        positionX: -54.21,
                        positionY: -19.98,
                        positionZ: -18.00,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-52d58f1c-c8da-4077-8d29-454907ad8847",
                        name: "Sphère 1 copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 108.64,
                            height: 87.10,
                            depth: 91.00,
                            roundness: 1.00
                        ),
                        positionX: -64.07,
                        positionY: 18.35,
                        positionZ: -18.00,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-d4b4e8ad-8625-488d-920c-c497da226f9f",
                        name: "Sphère 1 copie copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 97.79,
                            height: 96.84,
                            depth: 89.56,
                            roundness: 1.00
                        ),
                        positionX: 61.23,
                        positionY: 18.96,
                        positionZ: -18.00,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                    AvatarBodyNode(
                        id: "shape-56ea10ed-1202-4b78-9968-96f870f633f7",
                        name: "Sphère 1 copie",
                        surface: AvatarSurfaceConfig(
                            type: "sphere",
                            width: 94.35,
                            height: 94.35,
                            depth: 100.54,
                            roundness: 1.00
                        ),
                        positionX: 41.49,
                        positionY: -37.64,
                        positionZ: -17.99,
                        rotationX: 0.00,
                        rotationY: 0.00,
                        rotationZ: 0.00
                    ),
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#c9cbcf",
                eyesHex: "#111316"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 13.94,
                widthRight: 13.94,
                heightLeft: 45.42,
                heightRight: 45.42,
                spacing: 12.76,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: -1.07,
                positionYRight: -1.07,
                leftAngle: 0.00,
                rightAngle: 0.00
            ),
            iconName: "cloud.fill"
        ),
        AvatarLabTemplate(
            id: "avatar-2739f2c2-a5b4-45d9-8915-c9d6101d4d3b",
            name: "Cubee",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "cube",
                    width: 191.50,
                    height: 191.50,
                    depth: 171.96,
                    roundness: 0.73
                ),
                nodes: [
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#e65c5c",
                eyesHex: "#111316"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 19.98,
                widthRight: 28.01,
                heightLeft: 29.98,
                heightRight: 36.99,
                spacing: 16.81,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: -7.00,
                positionYRight: -7.00,
                leftAngle: 0.00,
                rightAngle: 0.00
            ),
            iconName: "square.fill"
        ),
        AvatarLabTemplate(
            id: "avatar-4b9ea0c1-286f-4aa1-b053-61fcc416ba7e",
            name: "Onee",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "cone",
                    width: 250.00,
                    height: 182.01,
                    depth: 225.00,
                    roundness: 0.00
                ),
                nodes: [
                ]
            ),
            defaultColors: AvatarColors(
                bodyHex: "#dbe2f5",
                eyesHex: "#111316"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 13.39,
                widthRight: 19.10,
                heightLeft: 44.01,
                heightRight: 37.20,
                spacing: 21.41,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 18.61,
                positionYRight: 18.61,
                leftAngle: 6.98,
                rightAngle: -7.01
            ),
            iconName: "cone.fill"
        ),
        AvatarLabTemplate(
            id: "unknown",
            name: "Unknown",
            body: AvatarBody(
                primary: AvatarSurfaceConfig(
                    type: "invisible",
                    width: 240.0,
                    height: 240.0,
                    depth: 240.0,
                    roundness: 1.0
                ),
                nodes: []
            ),
            defaultColors: AvatarColors(
                bodyHex: "#3A3D45",
                eyesHex: "#FFFFFF"
            ),
            defaultEyes: AvatarEyeDefaults(
                widthLeft: 20.0,
                widthRight: 20.0,
                heightLeft: 50.0,
                heightRight: 50.0,
                spacing: 35.0,
                positionXLeft: 0.0,
                positionXRight: 0.0,
                positionYLeft: -7.0,
                positionYRight: -7.0,
                leftAngle: 0.0,
                rightAngle: 0.0
            ),
            iconName: "questionmark.circle.fill"
        )
    ]

    // MARK: - 27 Calibrated Presets (00 s.d. 26)
    public static let allPresets: [AvatarLabPreset] = [
        AvatarLabPreset(
            index: 0,
            id: "expression-00",
            semanticKey: "upward-side-glance",
            expression: AvatarExpression(
                id: "upward-side-glance",
                headX: 7.30,
                headY: 27.80,
                headZ: -16.10,
                widthLeft: 22.50,
                widthRight: 22.50,
                heightLeft: 42.38,
                heightRight: 42.38,
                spacing: 54.30,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: -20.50,
                positionYRight: -20.50,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 1,
            id: "expression-01",
            semanticKey: "downward-gaze",
            expression: AvatarExpression(
                id: "downward-gaze",
                headX: -15.06,
                headY: 0.14,
                headZ: -14.55,
                widthLeft: 22.40,
                widthRight: 22.40,
                heightLeft: 54.57,
                heightRight: 54.57,
                spacing: 57.70,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 2,
            id: "expression-05",
            semanticKey: "skeptical-right",
            expression: AvatarExpression(
                id: "skeptical-right",
                headX: -16.53,
                headY: -3.77,
                headZ: -13.73,
                widthLeft: 23.09,
                widthRight: 49.92,
                heightLeft: 57.68,
                heightRight: 12.43,
                spacing: 56.30,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 3,
            id: "expression-06",
            semanticKey: "small-attentive",
            expression: AvatarExpression(
                id: "small-attentive",
                headX: -4.23,
                headY: 14.36,
                headZ: 11.20,
                widthLeft: 22.07,
                widthRight: 22.07,
                heightLeft: 39.60,
                heightRight: 39.60,
                spacing: 50.90,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 4,
            id: "expression-12",
            semanticKey: "wide-downward-gaze",
            expression: AvatarExpression(
                id: "wide-downward-gaze",
                headX: -19.21,
                headY: 15.20,
                headZ: 11.80,
                widthLeft: 52.08,
                widthRight: 53.11,
                heightLeft: 51.47,
                heightRight: 52.19,
                spacing: 69.50,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 5,
            id: "expression-03",
            semanticKey: "surprised-left",
            expression: AvatarExpression(
                id: "surprised-left",
                headX: 2.95,
                headY: -16.05,
                headZ: -20.92,
                widthLeft: 51.68,
                widthRight: 51.68,
                heightLeft: 51.74,
                heightRight: 51.74,
                spacing: 70.90,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 6,
            id: "expression-04",
            semanticKey: "sleepy-squint",
            expression: AvatarExpression(
                id: "sleepy-squint",
                headX: 3.40,
                headY: 13.23,
                headZ: 8.98,
                widthLeft: 51.77,
                widthRight: 51.77,
                heightLeft: 13.03,
                heightRight: 13.03,
                spacing: 63.87,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 7,
            id: "expression-07",
            semanticKey: "angry-right",
            expression: AvatarExpression(
                id: "angry-right",
                headX: 8.06,
                headY: 17.63,
                headZ: -11.12,
                widthLeft: 20.91,
                widthRight: 20.91,
                heightLeft: 40.40,
                heightRight: 40.40,
                spacing: 52.06,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: -30.87,
                rightAngle: 28.78,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 8,
            id: "expression-08",
            semanticKey: "curious-left",
            expression: AvatarExpression(
                id: "curious-left",
                headX: -12.30,
                headY: -17.60,
                headZ: 5.91,
                widthLeft: 20.61,
                widthRight: 20.61,
                heightLeft: 47.77,
                heightRight: 47.77,
                spacing: 54.90,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 23.52,
                rightAngle: -24.04,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 9,
            id: "expression-09",
            semanticKey: "asymmetric-down-right",
            expression: AvatarExpression(
                id: "asymmetric-down-right",
                headX: -20.06,
                headY: 12.61,
                headZ: -12.70,
                widthLeft: 42.50,
                widthRight: 22.10,
                heightLeft: 41.80,
                heightRight: 22.20,
                spacing: 61.70,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 10,
            id: "expression-10",
            semanticKey: "attentive-left",
            expression: AvatarExpression(
                id: "attentive-left",
                headX: 1.43,
                headY: 6.19,
                headZ: 10.56,
                widthLeft: 23.84,
                widthRight: 23.84,
                heightLeft: 58.13,
                heightRight: 58.13,
                spacing: 56.80,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 11,
            id: "expression-11",
            semanticKey: "joyful-wide",
            expression: AvatarExpression(
                id: "joyful-wide",
                headX: -2.09,
                headY: -15.90,
                headZ: -14.47,
                widthLeft: 34.20,
                widthRight: 34.20,
                heightLeft: 85.33,
                heightRight: 83.18,
                spacing: 59.41,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 12,
            id: "expression-13",
            semanticKey: "eyes-closed",
            expression: AvatarExpression(
                id: "eyes-closed",
                headX: -8.75,
                headY: -8.74,
                headZ: -10.77,
                widthLeft: 56.13,
                widthRight: 56.13,
                heightLeft: 15.50,
                heightRight: 15.16,
                spacing: 69.28,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 13,
            id: "expression-02",
            semanticKey: "joyful-down-right",
            expression: AvatarExpression(
                id: "joyful-down-right",
                headX: -15.29,
                headY: 15.01,
                headZ: 12.79,
                widthLeft: 31.25,
                widthRight: 31.25,
                heightLeft: 76.72,
                heightRight: 76.72,
                spacing: 68.70,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 14,
            id: "expression-14",
            semanticKey: "skeptical-left",
            expression: AvatarExpression(
                id: "skeptical-left",
                headX: 3.53,
                headY: -7.08,
                headZ: 9.83,
                widthLeft: 24.31,
                widthRight: 48.92,
                heightLeft: 59.28,
                heightRight: 13.41,
                spacing: 62.22,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 15,
            id: "expression-15",
            semanticKey: "far-right-glance",
            expression: AvatarExpression(
                id: "far-right-glance",
                headX: 0.32,
                headY: 35.31,
                headZ: -10.90,
                widthLeft: 22.46,
                widthRight: 22.46,
                heightLeft: 39.82,
                heightRight: 39.82,
                spacing: 53.90,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 16,
            id: "expression-16",
            semanticKey: "angry-left",
            expression: AvatarExpression(
                id: "angry-left",
                headX: -14.75,
                headY: -19.35,
                headZ: 5.63,
                widthLeft: 19.60,
                widthRight: 19.60,
                heightLeft: 48.64,
                heightRight: 48.64,
                spacing: 55.10,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: -27.61,
                rightAngle: 26.15,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 17,
            id: "expression-17",
            semanticKey: "playful-right",
            expression: AvatarExpression(
                id: "playful-right",
                headX: -4.40,
                headY: 14.07,
                headZ: -16.13,
                widthLeft: 19.05,
                widthRight: 19.05,
                heightLeft: 43.37,
                heightRight: 43.37,
                spacing: 51.73,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 26.29,
                rightAngle: -20.25,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 18,
            id: "expression-18",
            semanticKey: "asymmetric-up-left",
            expression: AvatarExpression(
                id: "asymmetric-up-left",
                headX: 6.59,
                headY: 4.74,
                headZ: 12.84,
                widthLeft: 42.10,
                widthRight: 22.20,
                heightLeft: 41.70,
                heightRight: 22.10,
                spacing: 60.40,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 19,
            id: "expression-19",
            semanticKey: "gentle-downward-gaze",
            expression: AvatarExpression(
                id: "gentle-downward-gaze",
                headX: -6.08,
                headY: -11.04,
                headZ: -13.97,
                widthLeft: 23.05,
                widthRight: 23.05,
                heightLeft: 58.69,
                heightRight: 58.69,
                spacing: 56.20,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 20,
            id: "expression-20",
            semanticKey: "wide-down-left",
            expression: AvatarExpression(
                id: "wide-down-left",
                headX: -17.13,
                headY: 18.07,
                headZ: 13.89,
                widthLeft: 35.45,
                widthRight: 35.45,
                heightLeft: 79.10,
                heightRight: 79.10,
                spacing: 70.80,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 21,
            id: "expression-21",
            semanticKey: "surprised-wide-left",
            expression: AvatarExpression(
                id: "surprised-wide-left",
                headX: -5.43,
                headY: -11.71,
                headZ: -13.47,
                widthLeft: 51.40,
                widthRight: 50.50,
                heightLeft: 50.10,
                heightRight: 49.40,
                spacing: 69.00,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 22,
            id: "expression-22",
            semanticKey: "drowsy-closed",
            expression: AvatarExpression(
                id: "drowsy-closed",
                headX: 10.29,
                headY: 3.40,
                headZ: 7.58,
                widthLeft: 55.67,
                widthRight: 55.67,
                heightLeft: 14.62,
                heightRight: 14.62,
                spacing: 68.42,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 23,
            id: "expression-23",
            semanticKey: "suspicious-right",
            expression: AvatarExpression(
                id: "suspicious-right",
                headX: -17.80,
                headY: 10.00,
                headZ: -10.89,
                widthLeft: 23.97,
                widthRight: 53.56,
                heightLeft: 55.89,
                heightRight: 13.33,
                spacing: 59.94,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: -9.80,
                positionYRight: -9.80,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 24,
            id: "expression-24",
            semanticKey: "shy-downward",
            expression: AvatarExpression(
                id: "shy-downward",
                headX: 7.13,
                headY: 7.78,
                headZ: 3.94,
                widthLeft: 21.50,
                widthRight: 23.20,
                heightLeft: 32.00,
                heightRight: 33.50,
                spacing: 51.20,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 40.00,
                positionYRight: 40.00,
                leftAngle: 0.00,
                rightAngle: 0.00,
                perspective: 1.00,
                bodyColorHex: nil,
                eyeColorHex: nil,
                bodyMotion: nil,
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 25,
            id: "expression-3d2bed26-f97c-477d-922f-77600cb10e92",
            semanticKey: "angry-brows",
            expression: AvatarExpression(
                id: "angry-brows",
                headX: 10.47,
                headY: 5.09,
                headZ: 4.70,
                widthLeft: 27.13,
                widthRight: 27.13,
                heightLeft: 63.03,
                heightRight: 63.03,
                spacing: 68.70,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: -36.24,
                rightAngle: 27.73,
                perspective: 1.00,
                bodyColorHex: "#ba3636",
                eyeColorHex: "#610000",
                bodyMotion: "shake",
                eyeMotion: nil
            )
        ),
        AvatarLabPreset(
            index: 26,
            id: "expression-5220eaee-32fe-4bd8-ad31-432189534cc8",
            semanticKey: "uneasy-left",
            expression: AvatarExpression(
                id: "uneasy-left",
                headX: -12.30,
                headY: -17.60,
                headZ: 5.91,
                widthLeft: 20.61,
                widthRight: 20.61,
                heightLeft: 47.77,
                heightRight: 47.77,
                spacing: 54.90,
                positionXLeft: 0.00,
                positionXRight: 0.00,
                positionYLeft: 0.00,
                positionYRight: 0.00,
                leftAngle: 23.52,
                rightAngle: -24.04,
                perspective: 1.00,
                bodyColorHex: "#adc3ff",
                eyeColorHex: nil,
                bodyMotion: "slowDrift",
                eyeMotion: "shake"
            )
        ),
    ]

    // MARK: - 23 Animation Sequences (7 Life Cycle + 16 Reactions)
    public static let allAnimations: [AvatarLabAnimation] = [
        AvatarLabAnimation(
            id: "sleeping",
            name: "sleeping",
            semanticKey: "sleeping",
            category: AvatarAnimationCategory.lifeCycle,
            steps: [
                AvatarAnimationStep(
                    id: "sleeping-step-0",
                    expressionId: "expression-13",
                    expressionIndex: 12,
                    semanticKey: "eyes-closed",
                    holdMs: 3600,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "sleeping-step-1",
                    expressionId: "expression-22",
                    expressionIndex: 22,
                    semanticKey: "drowsy-closed",
                    holdMs: 3600,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "sleeping-step-2",
                    expressionId: "expression-04",
                    expressionIndex: 6,
                    semanticKey: "sleepy-squint",
                    holdMs: 3600,
                    transitionMs: 500
                ),
            ],
            iconName: "bed.double.fill"
        ),
        AvatarLabAnimation(
            id: "waking",
            name: "waking",
            semanticKey: "waking",
            category: AvatarAnimationCategory.lifeCycle,
            steps: [
                AvatarAnimationStep(
                    id: "waking-step-0",
                    expressionId: "expression-13",
                    expressionIndex: 12,
                    semanticKey: "eyes-closed",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "sun.and.horizon.fill"
        ),
        AvatarLabAnimation(
            id: "idle",
            name: "idle",
            semanticKey: "idle",
            category: AvatarAnimationCategory.lifeCycle,
            steps: [
                AvatarAnimationStep(
                    id: "idle-step-0",
                    expressionId: "expression-00",
                    expressionIndex: 0,
                    semanticKey: "upward-side-glance",
                    holdMs: 5200,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "idle-step-1",
                    expressionId: "expression-08",
                    expressionIndex: 8,
                    semanticKey: "curious-left",
                    holdMs: 5200,
                    transitionMs: 500
                ),
            ],
            iconName: "person.fill"
        ),
        AvatarLabAnimation(
            id: "listening",
            name: "listening",
            semanticKey: "listening",
            category: AvatarAnimationCategory.lifeCycle,
            steps: [
                AvatarAnimationStep(
                    id: "listening-step-0",
                    expressionId: "expression-10",
                    expressionIndex: 10,
                    semanticKey: "attentive-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "listening-step-1",
                    expressionId: "expression-01",
                    expressionIndex: 1,
                    semanticKey: "downward-gaze",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "listening-step-2",
                    expressionId: "expression-19",
                    expressionIndex: 19,
                    semanticKey: "gentle-downward-gaze",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "ear.fill"
        ),
        AvatarLabAnimation(
            id: "thinking",
            name: "thinking",
            semanticKey: "thinking",
            category: AvatarAnimationCategory.lifeCycle,
            steps: [
                AvatarAnimationStep(
                    id: "thinking-step-0",
                    expressionId: "expression-08",
                    expressionIndex: 8,
                    semanticKey: "curious-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "thinking-step-1",
                    expressionId: "expression-16",
                    expressionIndex: 16,
                    semanticKey: "angry-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "thinking-step-2",
                    expressionId: "expression-14",
                    expressionIndex: 14,
                    semanticKey: "skeptical-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "thinking-step-3",
                    expressionId: "expression-17",
                    expressionIndex: 17,
                    semanticKey: "playful-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "thinking-step-4",
                    expressionId: "expression-05",
                    expressionIndex: 2,
                    semanticKey: "skeptical-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "brain.head.profile"
        ),
        AvatarLabAnimation(
            id: "searching",
            name: "searching",
            semanticKey: "searching",
            category: AvatarAnimationCategory.lifeCycle,
            steps: [
                AvatarAnimationStep(
                    id: "searching-step-0",
                    expressionId: "expression-15",
                    expressionIndex: 15,
                    semanticKey: "far-right-glance",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "searching-step-1",
                    expressionId: "expression-09",
                    expressionIndex: 9,
                    semanticKey: "asymmetric-down-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "searching-step-2",
                    expressionId: "expression-03",
                    expressionIndex: 5,
                    semanticKey: "surprised-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "searching-step-3",
                    expressionId: "expression-20",
                    expressionIndex: 20,
                    semanticKey: "wide-down-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "searching-step-4",
                    expressionId: "expression-12",
                    expressionIndex: 4,
                    semanticKey: "wide-downward-gaze",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "searching-step-5",
                    expressionId: "expression-18",
                    expressionIndex: 18,
                    semanticKey: "asymmetric-up-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "magnifyingglass"
        ),
        AvatarLabAnimation(
            id: "working",
            name: "working",
            semanticKey: "working",
            category: AvatarAnimationCategory.lifeCycle,
            steps: [
                AvatarAnimationStep(
                    id: "working-step-0",
                    expressionId: "expression-07",
                    expressionIndex: 7,
                    semanticKey: "angry-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "working-step-1",
                    expressionId: "expression-16",
                    expressionIndex: 16,
                    semanticKey: "angry-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "working-step-2",
                    expressionId: "expression-11",
                    expressionIndex: 11,
                    semanticKey: "joyful-wide",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "working-step-3",
                    expressionId: "expression-10",
                    expressionIndex: 10,
                    semanticKey: "attentive-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "hammer.fill"
        ),
        AvatarLabAnimation(
            id: "excited",
            name: "excited",
            semanticKey: "excited",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "excited-step-0",
                    expressionId: "expression-02",
                    expressionIndex: 13,
                    semanticKey: "joyful-down-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "excited-step-1",
                    expressionId: "expression-17",
                    expressionIndex: 17,
                    semanticKey: "playful-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "excited-step-2",
                    expressionId: "expression-21",
                    expressionIndex: 21,
                    semanticKey: "surprised-wide-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "excited-step-3",
                    expressionId: "expression-03",
                    expressionIndex: 5,
                    semanticKey: "surprised-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "excited-step-4",
                    expressionId: "expression-11",
                    expressionIndex: 11,
                    semanticKey: "joyful-wide",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "sparkles"
        ),
        AvatarLabAnimation(
            id: "bored",
            name: "bored",
            semanticKey: "bored",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "bored-step-0",
                    expressionId: "expression-04",
                    expressionIndex: 6,
                    semanticKey: "sleepy-squint",
                    holdMs: 3600,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "bored-step-1",
                    expressionId: "expression-22",
                    expressionIndex: 22,
                    semanticKey: "drowsy-closed",
                    holdMs: 3600,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "bored-step-2",
                    expressionId: "expression-00",
                    expressionIndex: 0,
                    semanticKey: "upward-side-glance",
                    holdMs: 3600,
                    transitionMs: 500
                ),
            ],
            iconName: "clock.arrow.circlepath"
        ),
        AvatarLabAnimation(
            id: "suspicious",
            name: "suspicious",
            semanticKey: "suspicious",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "suspicious-step-0",
                    expressionId: "expression-14",
                    expressionIndex: 14,
                    semanticKey: "skeptical-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "suspicious-step-1",
                    expressionId: "expression-05",
                    expressionIndex: 2,
                    semanticKey: "skeptical-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "suspicious-step-2",
                    expressionId: "expression-23",
                    expressionIndex: 23,
                    semanticKey: "suspicious-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "eye.trianglebadge.exclamationmark"
        ),
        AvatarLabAnimation(
            id: "angry",
            name: "angry",
            semanticKey: "angry",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "angry-step-0",
                    expressionId: "expression-07",
                    expressionIndex: 7,
                    semanticKey: "angry-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "angry-step-1",
                    expressionId: "expression-16",
                    expressionIndex: 16,
                    semanticKey: "angry-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "flame.fill"
        ),
        AvatarLabAnimation(
            id: "drowsy",
            name: "drowsy",
            semanticKey: "drowsy",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "drowsy-step-0",
                    expressionId: "expression-04",
                    expressionIndex: 6,
                    semanticKey: "sleepy-squint",
                    holdMs: 3600,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "drowsy-step-1",
                    expressionId: "expression-22",
                    expressionIndex: 22,
                    semanticKey: "drowsy-closed",
                    holdMs: 3600,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "drowsy-step-2",
                    expressionId: "expression-13",
                    expressionIndex: 12,
                    semanticKey: "eyes-closed",
                    holdMs: 3600,
                    transitionMs: 500
                ),
            ],
            iconName: "moon.stars.fill"
        ),
        AvatarLabAnimation(
            id: "happy",
            name: "happy",
            semanticKey: "happy",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "happy-step-0",
                    expressionId: "expression-02",
                    expressionIndex: 13,
                    semanticKey: "joyful-down-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "happy-step-1",
                    expressionId: "expression-11",
                    expressionIndex: 11,
                    semanticKey: "joyful-wide",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "happy-step-2",
                    expressionId: "expression-17",
                    expressionIndex: 17,
                    semanticKey: "playful-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "happy-step-3",
                    expressionId: "expression-19",
                    expressionIndex: 19,
                    semanticKey: "gentle-downward-gaze",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "face.smiling.inverse"
        ),
        AvatarLabAnimation(
            id: "curious",
            name: "curious",
            semanticKey: "curious",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "curious-step-0",
                    expressionId: "expression-03",
                    expressionIndex: 5,
                    semanticKey: "surprised-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "curious-step-1",
                    expressionId: "expression-21",
                    expressionIndex: 21,
                    semanticKey: "surprised-wide-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "curious-step-2",
                    expressionId: "expression-00",
                    expressionIndex: 0,
                    semanticKey: "upward-side-glance",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "curious-step-3",
                    expressionId: "expression-15",
                    expressionIndex: 15,
                    semanticKey: "far-right-glance",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "questionmark"
        ),
        AvatarLabAnimation(
            id: "confused",
            name: "confused",
            semanticKey: "confused",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "confused-step-0",
                    expressionId: "expression-14",
                    expressionIndex: 14,
                    semanticKey: "skeptical-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "confused-step-1",
                    expressionId: "expression-05",
                    expressionIndex: 2,
                    semanticKey: "skeptical-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "confused-step-2",
                    expressionId: "expression-08",
                    expressionIndex: 8,
                    semanticKey: "curious-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "questionmark.bubble.fill"
        ),
        AvatarLabAnimation(
            id: "surprised",
            name: "surprised",
            semanticKey: "surprised",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "surprised-step-0",
                    expressionId: "expression-03",
                    expressionIndex: 5,
                    semanticKey: "surprised-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "surprised-step-1",
                    expressionId: "expression-21",
                    expressionIndex: 21,
                    semanticKey: "surprised-wide-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "bolt.fill"
        ),
        AvatarLabAnimation(
            id: "proud",
            name: "proud",
            semanticKey: "proud",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "proud-step-0",
                    expressionId: "expression-15",
                    expressionIndex: 15,
                    semanticKey: "far-right-glance",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "proud-step-1",
                    expressionId: "expression-08",
                    expressionIndex: 8,
                    semanticKey: "curious-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "proud-step-2",
                    expressionId: "expression-02",
                    expressionIndex: 13,
                    semanticKey: "joyful-down-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "crown.fill"
        ),
        AvatarLabAnimation(
            id: "shy",
            name: "shy",
            semanticKey: "shy",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "shy-step-0",
                    expressionId: "expression-00",
                    expressionIndex: 0,
                    semanticKey: "upward-side-glance",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "shy-step-1",
                    expressionId: "expression-24",
                    expressionIndex: 24,
                    semanticKey: "shy-downward",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "shy-step-2",
                    expressionId: "expression-13",
                    expressionIndex: 12,
                    semanticKey: "eyes-closed",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "hand.raised.slash.fill"
        ),
        AvatarLabAnimation(
            id: "sad",
            name: "sad",
            semanticKey: "sad",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "sad-step-0",
                    expressionId: "expression-04",
                    expressionIndex: 6,
                    semanticKey: "sleepy-squint",
                    holdMs: 3600,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "sad-step-1",
                    expressionId: "expression-13",
                    expressionIndex: 12,
                    semanticKey: "eyes-closed",
                    holdMs: 3600,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "sad-step-2",
                    expressionId: "expression-22",
                    expressionIndex: 22,
                    semanticKey: "drowsy-closed",
                    holdMs: 3600,
                    transitionMs: 500
                ),
            ],
            iconName: "cloud.rain.fill"
        ),
        AvatarLabAnimation(
            id: "laughing",
            name: "laughing",
            semanticKey: "laughing",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "laughing-step-0",
                    expressionId: "expression-02",
                    expressionIndex: 13,
                    semanticKey: "joyful-down-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "laughing-step-1",
                    expressionId: "expression-11",
                    expressionIndex: 11,
                    semanticKey: "joyful-wide",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "laughing-step-2",
                    expressionId: "expression-17",
                    expressionIndex: 17,
                    semanticKey: "playful-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "face.dashed.fill"
        ),
        AvatarLabAnimation(
            id: "scared",
            name: "scared",
            semanticKey: "scared",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "scared-step-0",
                    expressionId: "expression-03",
                    expressionIndex: 5,
                    semanticKey: "surprised-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "scared-step-1",
                    expressionId: "expression-21",
                    expressionIndex: 21,
                    semanticKey: "surprised-wide-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "exclamationmark.shield.fill"
        ),
        AvatarLabAnimation(
            id: "playful",
            name: "playful",
            semanticKey: "playful",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "playful-step-0",
                    expressionId: "expression-02",
                    expressionIndex: 13,
                    semanticKey: "joyful-down-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "playful-step-1",
                    expressionId: "expression-17",
                    expressionIndex: 17,
                    semanticKey: "playful-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "playful-step-2",
                    expressionId: "expression-11",
                    expressionIndex: 11,
                    semanticKey: "joyful-wide",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "playful-step-3",
                    expressionId: "expression-08",
                    expressionIndex: 8,
                    semanticKey: "curious-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "gamecontroller.fill"
        ),
        AvatarLabAnimation(
            id: "celebrate",
            name: "celebrate",
            semanticKey: "celebrate",
            category: AvatarAnimationCategory.reaction,
            steps: [
                AvatarAnimationStep(
                    id: "celebrate-step-0",
                    expressionId: "expression-02",
                    expressionIndex: 13,
                    semanticKey: "joyful-down-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "celebrate-step-1",
                    expressionId: "expression-08",
                    expressionIndex: 8,
                    semanticKey: "curious-left",
                    holdMs: 2300,
                    transitionMs: 500
                ),
                AvatarAnimationStep(
                    id: "celebrate-step-2",
                    expressionId: "expression-17",
                    expressionIndex: 17,
                    semanticKey: "playful-right",
                    holdMs: 2300,
                    transitionMs: 500
                ),
            ],
            iconName: "party.popper.fill"
        ),
    ]

    // MARK: - Helper Lookups
    public static func template(byName name: String) -> AvatarLabTemplate? {
        allTemplates.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    public static func template(byId id: String) -> AvatarLabTemplate? {
        let clean = id.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "_", with: "-")
        return allTemplates.first {
            $0.id.caseInsensitiveCompare(id) == .orderedSame ||
            $0.name.caseInsensitiveCompare(id) == .orderedSame ||
            $0.name.lowercased().replacingOccurrences(of: " ", with: "-") == clean ||
            $0.name.lowercased().replacingOccurrences(of: " ", with: "") == clean.replacingOccurrences(of: "-", with: "")
        }
    }

    public static func preset(byIndex index: Int) -> AvatarLabPreset? {
        allPresets.first { $0.index == index }
    }

    public static func preset(byId id: String) -> AvatarLabPreset? {
        allPresets.first { $0.id == id || $0.semanticKey == id }
    }

    public static func animation(byKey key: String) -> AvatarLabAnimation? {
        allAnimations.first { $0.semanticKey == key || $0.name.caseInsensitiveCompare(key) == .orderedSame }
    }
}

// MARK: - Domain Model Avatar Extensions
extension BuddySession {
    public var avatarDefinition: CompanionAvatarDefinition {
        let template = CompanionAvatarLabCatalog.template(byId: templateId)
            ?? CompanionAvatarLabCatalog.allTemplates[0]
        return template.toAvatarDefinition(
            name: name,
            cloudColorHex: avatarColorHex.isEmpty ? nil : avatarColorHex,
            eyesHex: "#111316"
        )
    }
}

extension CompanionProfile {
    public var avatarDefinition: CompanionAvatarDefinition {
        let template = CompanionAvatarLabCatalog.template(byId: templateId)
            ?? CompanionAvatarLabCatalog.allTemplates[0]
        return template.toAvatarDefinition(
            name: name,
            cloudColorHex: cloudColorHex.isEmpty ? nil : cloudColorHex,
            eyesHex: "#111316"
        )
    }
}

extension ComputerUseRequest {
    public var avatarDefinition: CompanionAvatarDefinition {
        let template = CompanionAvatarLabCatalog.template(byId: "strobi")
            ?? CompanionAvatarLabCatalog.allTemplates[0]
        return template.toAvatarDefinition(
            name: companionName,
            cloudColorHex: cloudColorHex.isEmpty ? nil : cloudColorHex,
            eyesHex: "#111316"
        )
    }
}
