// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TelemetryKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
    ]
)
