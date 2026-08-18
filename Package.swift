// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotchDeck", targets: ["NotchDeck"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NotchDeck",
            dependencies: [],
            path: "Sources/NotchDeck"
        ),
        .testTarget(
            name: "NotchDeckTests",
            dependencies: ["NotchDeck"],
            path: "Tests/NotchDeckTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
