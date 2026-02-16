// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EZSignEPaper",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "EZSignEPaper",
            targets: ["EZSignEPaper"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "EZSignEPaper",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "EZSignEPaperTests",
            dependencies: ["EZSignEPaper"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
