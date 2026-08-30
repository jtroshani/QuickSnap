// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuickSnap",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "QuickSnap",
            path: "Sources/QuickSnap"
        )
    ]
)
