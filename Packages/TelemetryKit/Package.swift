// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TelemetryKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "TelemetryKit",
            targets: ["TelemetryKit"]),
    ],
    targets: [
        .target(
            name: "TelemetryKit",
            path: "Sources/TelemetryKit"
        ),
        .testTarget(
            name: "TelemetryKitTests",
            dependencies: ["TelemetryKit"],
            path: "Tests/TelemetryKitTests"
        ),
    ]
)
