// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SteadyFrame",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SteadyFrame", targets: ["SteadyFrame"])
    ],
    targets: [
        .executableTarget(
            name: "SteadyFrame",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("IOKit"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .testTarget(
            name: "SteadyFrameTests",
            dependencies: ["SteadyFrame"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
