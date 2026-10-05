// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClickyKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ClickyKit", targets: ["ClickyKit"]),
        .library(name: "ClickyFoundation", targets: ["ClickyFoundation"]),
        .library(name: "ClickyPlatform", targets: ["ClickyPlatform"]),
        .library(name: "ClickyAIProviders", targets: ["ClickyAIProviders"]),
        .library(name: "ClickySpeech", targets: ["ClickySpeech"]),
        .library(name: "ClickyCUA", targets: ["ClickyCUA"]),
        .library(name: "ClickyReasoning", targets: ["ClickyReasoning"]),
        .library(name: "ClickyAstronacci", targets: ["ClickyAstronacci"]),
        .library(name: "ClickyTradingView", targets: ["ClickyTradingView"]),
        .library(name: "ClickyFuturesScout", targets: ["ClickyFuturesScout"]),
        .library(name: "ClickyRoster", targets: ["ClickyRoster"]),
        .library(name: "ClickyDesignSystem", targets: ["ClickyDesignSystem"]),
        .library(name: "ClickyAgent", targets: ["ClickyAgent"]),
        .library(name: "ClickyUI", targets: ["ClickyUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/Defaults", from: "9.0.2")
    ],
    targets: [
        // L0: Foundation
        .target(
            name: "ClickyFoundation",
            dependencies: [
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyFoundation"
        ),
        // L1: Platform
        .target(
            name: "ClickyPlatform",
            dependencies: [
                "ClickyFoundation",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyPlatform"
        ),
        // L2a: AIProviders
        .target(
            name: "ClickyAIProviders",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyAIProviders"
        ),
        // L2b: Speech
        .target(
            name: "ClickySpeech",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickySpeech",
            resources: [
                .process("Resources/Sounds")
            ]
        ),
        // L2c: CUA
        .target(
            name: "ClickyCUA",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyCUA"
        ),
        // L3: Reasoning
        .target(
            name: "ClickyReasoning",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                "ClickyCUA",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyReasoning"
        ),
        // L4: Domain - Astronacci
        .target(
            name: "ClickyAstronacci",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyReasoning",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyAstronacci",
            resources: [
                .process("Resources/economic_calendar_2025_2026.json")
            ]
        ),
        // L4: Domain - TradingView
        .target(
            name: "ClickyTradingView",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                "ClickyCUA",
                "ClickyReasoning",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyTradingView"
        ),
        // L4: Domain - FuturesScout
        .target(
            name: "ClickyFuturesScout",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                "ClickySpeech",
                "ClickyCUA",
                "ClickyReasoning",
                "ClickyAstronacci",
                "ClickyTradingView",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyFuturesScout"
        ),
        // L4: Domain - Roster
        .target(
            name: "ClickyRoster",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                "ClickySpeech",
                "ClickyReasoning",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyRoster"
        ),
        // L5: DesignSystem
        .target(
            name: "ClickyDesignSystem",
            dependencies: [
                "ClickyFoundation"
            ],
            path: "Sources/ClickyDesignSystem"
        ),
        // L5: Agent
        .target(
            name: "ClickyAgent",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                "ClickySpeech",
                "ClickyCUA",
                "ClickyReasoning",
                "ClickyAstronacci",
                "ClickyTradingView",
                "ClickyFuturesScout",
                "ClickyRoster",
                "ClickyDesignSystem",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyAgent"
        ),
        // L6: UI
        .target(
            name: "ClickyUI",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                "ClickySpeech",
                "ClickyCUA",
                "ClickyReasoning",
                "ClickyAstronacci",
                "ClickyTradingView",
                "ClickyFuturesScout",
                "ClickyRoster",
                "ClickyDesignSystem",
                "ClickyAgent",
                .product(name: "Defaults", package: "Defaults")
            ],
            path: "Sources/ClickyUI"
        ),
        // Umbrella target
        .target(
            name: "ClickyKit",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyAIProviders",
                "ClickySpeech",
                "ClickyCUA",
                "ClickyReasoning",
                "ClickyAstronacci",
                "ClickyTradingView",
                "ClickyFuturesScout",
                "ClickyRoster",
                "ClickyDesignSystem",
                "ClickyAgent",
                "ClickyUI"
            ],
            path: "Sources/ClickyKit"
        ),
        // Tests
        .testTarget(
            name: "ClickyReasoningTests",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyReasoning",
                "ClickyAgent"
            ],
            path: "Tests/ClickyReasoningTests"
        ),
        .testTarget(
            name: "ClickyCUATests",
            dependencies: [
                "ClickyFoundation",
                "ClickyPlatform",
                "ClickyCUA",
                "ClickyReasoning",
                "ClickyAgent"
            ],
            path: "Tests/ClickyCUATests"
        )
    ]
)
