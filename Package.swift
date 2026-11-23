// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PebbleCompanion",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PebbleCompanion", targets: ["PebbleCompanion"])
    ],
    targets: [
        .executableTarget(
            name: "PebbleCompanion",
            path: "Sources/PebbleCompanion",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ScreenCaptureKit")
            ]
        )
    ]
)
