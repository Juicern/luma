// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumaMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LumaMac", targets: ["LumaMac"])
    ],
    targets: [
        .executableTarget(
            name: "LumaMac",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)
