// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HiFrame",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HiFrame", targets: ["HiFrame"])
    ],
    targets: [
        .executableTarget(
            name: "HiFrame",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "HiFrameTests",
            dependencies: ["HiFrame"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
