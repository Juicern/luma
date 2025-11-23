// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Luma",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Luma", targets: ["LumaMac"])
    ],
    targets: [
        .executableTarget(
            name: "LumaMac",
            path: "Sources",
            resources: [.process("Resources")]
        )
    ]
)
