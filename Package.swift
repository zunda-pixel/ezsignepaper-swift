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
        .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "EZSignEPaper",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
            ],
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
