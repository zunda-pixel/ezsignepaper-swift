// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EZSignEPaper",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
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
            dependencies: []
        ),
        .testTarget(
            name: "EZSignEPaperTests",
            dependencies: ["EZSignEPaper"]
        ),
    ]
)
