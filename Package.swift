// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PortAuthority",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PortAuthorityKit", targets: ["PortAuthorityKit"]),
        .executable(name: "portauth", targets: ["portauth"]),
        .executable(name: "PortAuthorityApp", targets: ["PortAuthorityApp"]),
    ],
    targets: [
        .target(
            name: "PortAuthorityKit",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "portauth",
            dependencies: ["PortAuthorityKit"]
        ),
        .executableTarget(
            name: "PortAuthorityApp",
            dependencies: ["PortAuthorityKit"]
        ),
    ]
)
