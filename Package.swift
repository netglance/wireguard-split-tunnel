// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SplitTunnel",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "SplitTunnelCore"),
        .executableTarget(name: "SplitTunnel", dependencies: ["SplitTunnelCore"]),
        .testTarget(name: "SplitTunnelCoreTests", dependencies: ["SplitTunnelCore"]),
    ]
)
