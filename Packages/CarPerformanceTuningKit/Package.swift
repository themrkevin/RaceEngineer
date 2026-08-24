// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CarPerformanceTuningKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "CarPerformanceTuningKit",
            targets: ["CarPerformanceTuningKit"]),
    ],
    dependencies: [
        .package(path: "../TelemetryKit"),
    ],
    targets: [
        .target(
            name: "CarPerformanceTuningKit",
            dependencies: [
                .product(name: "TelemetryKit", package: "TelemetryKit"),
            ],
            path: "Sources/CarPerformanceTuningKit"
        ),
        .testTarget(
            name: "CarPerformanceTuningKitTests",
            dependencies: ["CarPerformanceTuningKit"],
            path: "Tests/CarPerformanceTuningKitTests"
        ),
    ]
)
