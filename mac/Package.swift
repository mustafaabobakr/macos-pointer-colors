// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PointerColors",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PointerColors",
            path: "Sources/PointerColors",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PointerColorsTests",
            dependencies: ["PointerColors"],
            path: "Tests/PointerColorsTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
