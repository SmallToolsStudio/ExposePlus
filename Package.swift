// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExposePlus",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ExposePlusCore",
            path: "Sources/ExposePlusCore"
        ),
        .executableTarget(
            name: "ExposePlus",
            dependencies: ["ExposePlusCore"],
            path: "Sources/ExposePlus"
        ),
    ]
)
