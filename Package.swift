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
        )
    ],
    traits: [
        // Per-family traits. Each gates a single command family's source files.
        .trait(name: "Git", description: "Typed wrapper for the git CLI."),
        .trait(name: "Brew", description: "Typed wrapper for the Homebrew CLI."),
        .trait(name: "Grep", description: "Typed wrapper for grep."),
        .trait(name: "Ls", description: "Typed wrapper for ls."),
        .trait(name: "Cp", description: "Typed wrapper for cp."),
        .trait(name: "Mkdir", description: "Typed wrapper for mkdir."),
        .trait(name: "Chmod", description: "Typed wrapper for chmod."),
        .trait(name: "Rm", description: "Typed wrapper for rm."),
        .trait(name: "Mv", description: "Typed wrapper for mv."),
        .trait(name: "Pwd", description: "Typed wrapper for pwd."),
        .trait(name: "Jq", description: "Typed wrapper for jq."),
        // Convenience umbrella that enables every Common/* utility family.
        .trait(
            name: "CommonUtilities",
            description: "Enables all common file/directory utility families.",
            enabledTraits: ["Ls", "Cp", "Mkdir", "Chmod", "Rm", "Mv", "Pwd", "Jq"]
        ),
        // Convenience umbrella that enables every command family.
        .trait(
            name: "All",
            description: "Enables every command family shipped by SwiftyShell.",
            enabledTraits: ["Git", "Brew", "Grep", "CommonUtilities"]
        ),
        // Default is intentionally empty: consumers opt in to the families they want.
        .default(enabledTraits: []),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5")
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
