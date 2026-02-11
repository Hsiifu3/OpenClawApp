// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenClaw",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OpenClaw", targets: ["OpenClaw"])
    ],
    targets: [
        .executableTarget(
            name: "OpenClaw",
            path: "Sources/OpenClaw"
        )
    ]
)
