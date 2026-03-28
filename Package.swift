// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HocusPocus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HocusPocus",
            path: "Sources/HocusPocus",
            resources: [
                .process("Resources/")
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore")
            ]
        )
    ]
)
