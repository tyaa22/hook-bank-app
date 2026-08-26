// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HookBank",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0")
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
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.18.0")
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [
                .product(name: "FirebaseAILogic", package: "firebase-ios-sdk")
            ],
            path: "Core"
        ),
        .target(
            name: "Features",
            dependencies: ["Core"],
            path: "Features"
        )
    ]
)

