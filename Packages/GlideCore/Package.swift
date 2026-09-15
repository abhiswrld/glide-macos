// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlideCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "GlideCore", targets: ["GlideCore"])
    ],
    targets: [
        .target(name: "GlideCore")
    ]
)
