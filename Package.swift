// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftyShell",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftyShell",
            targets: ["SwiftyShell"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
    ],
    targets: [
        .target(
            name: "SwiftyShell"
        ),
        .testTarget(
            name: "SwiftyShellTests",
            dependencies: ["SwiftyShell"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
