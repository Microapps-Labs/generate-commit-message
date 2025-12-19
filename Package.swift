// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gcm",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "gcm", targets: ["gcm"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "gcm",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "gcmTests",
            dependencies: ["gcm"]
        )
    ]
)
