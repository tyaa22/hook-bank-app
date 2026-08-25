// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HookBank",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]
        ),
        .library(
            name: "Features",
            targets: ["Features"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Core",
            dependencies: [],
            path: "Core"
        ),
        .target(
            name: "Features",
            dependencies: ["Core"],
            path: "Features"
        )
    ]
)
