// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Graffiti",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Graffiti",
            path: "Sources/Graffiti",
            swiftSettings: [.unsafeFlags(["-Osize"])]
        )
    ]
)
