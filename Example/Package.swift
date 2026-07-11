// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Example",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        // SwiftyShell ships with all command families OFF by default.
        // Opt into the families this example actually uses via `traits:`.
        // Add more here (e.g. "Git", "Grep", or the "All" umbrella) as needed.
        .package(name: "swiftyshell", path: "..", traits: ["Ls"]),
    ],
    targets: [
        .executableTarget(
            name: "Example",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftyShell", package: "swiftyshell"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
