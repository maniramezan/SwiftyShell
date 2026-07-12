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
        .trait(name: "Fzf", description: "Typed wrapper for the fzf fuzzy finder."),
        .trait(name: "Rg", description: "Typed wrapper for ripgrep (rg)."),
        .trait(name: "Swift", description: "Typed wrapper for the Swift toolchain CLI."),
        .trait(name: "Gh", description: "Typed wrapper for the GitHub CLI."),
        .trait(name: "Docker", description: "Typed wrapper for the Docker CLI."),
        .trait(name: "Make", description: "Typed wrapper for the make build automation CLI."),
        .trait(name: "Node", description: "Typed wrapper for the Node.js runtime CLI."),
        .trait(name: "Npm", description: "Typed wrapper for the npm package manager CLI."),
        .trait(name: "Yarn", description: "Typed wrapper for the Yarn package manager CLI."),
        .trait(name: "Pnpm", description: "Typed wrapper for the pnpm package manager CLI."),
        .trait(name: "Bun", description: "Typed wrapper for the Bun runtime and package manager CLI."),
        .trait(name: "Terraform", description: "Typed wrapper for the Terraform CLI."),
        .trait(name: "Kubectl", description: "Typed wrapper for the Kubernetes kubectl CLI."),
        .trait(name: "Helm", description: "Typed wrapper for the Helm package manager CLI."),
        .trait(name: "Python", description: "Typed wrapper for the Python interpreter CLI."),
        .trait(name: "Curl", description: "Typed wrapper for curl HTTP transfers."),
        .trait(name: "Ls", description: "Typed wrapper for ls."),
        .trait(name: "Cp", description: "Typed wrapper for cp."),
        .trait(name: "Mkdir", description: "Typed wrapper for mkdir."),
        .trait(name: "Chmod", description: "Typed wrapper for chmod."),
        .trait(name: "Rm", description: "Typed wrapper for rm."),
        .trait(name: "Mv", description: "Typed wrapper for mv."),
        .trait(name: "Pwd", description: "Typed wrapper for pwd."),
        .trait(name: "Jq", description: "Typed wrapper for jq."),
        .trait(name: "Rsync", description: "Typed wrapper for rsync file synchronization."),
        .trait(name: "Tar", description: "Typed wrapper for tar archives."),
        .trait(name: "Zip", description: "Typed wrapper for zip (Info-ZIP)."),
        .trait(name: "Unzip", description: "Typed wrapper for unzip (Info-ZIP)."),
        .trait(name: "Ln", description: "Typed wrapper for ln."),
        .trait(name: "Touch", description: "Typed wrapper for touch."),
        .trait(name: "Env", description: "Typed wrapper for env."),
        .trait(name: "Which", description: "Typed executable lookup with which."),
        // Convenience umbrella that enables every Common/* utility family.
        .trait(
            name: "CommonUtilities",
            description: "Enables all common utility command families.",
            enabledTraits: [
                "Ls", "Cp", "Mkdir", "Chmod", "Rm", "Mv", "Pwd", "Jq", "Rsync", "Tar", "Zip", "Unzip",
                "Ln", "Touch", "Env", "Which",
            ]
        ),
        // Convenience umbrella that enables every command family.
        .trait(
            name: "All",
            description: "Enables every command family shipped by SwiftyShell.",
            enabledTraits: [
                "Git", "Brew", "Grep", "Fzf", "Rg", "Swift", "Gh", "Docker", "Make", "Node", "Npm", "Yarn",
                "Pnpm", "Bun", "Terraform", "Kubectl", "Helm", "Python", "Curl", "CommonUtilities",
            ]
        ),
        // Default is intentionally empty: consumers opt in to the families they want.
        .default(enabledTraits: []),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
        .package(url: "https://github.com/apple/swift-system", from: "1.6.4"),
        // swift-subprocess's `SubprocessFoundation` trait is enabled by default in that
        // package, providing Foundation extensions (e.g. Data-based input/output). SwiftyShell
        // relies on this trait implicitly — OutputCaptureStore and pipeline stage results use
        // Foundation's Data. If swift-subprocess ever changes its default trait set, this
        // dependency should be updated to explicitly enable `SubprocessFoundation` via the
        // `traits:` parameter on `.product(name:package:)`.
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", .upToNextMinor(from: "0.4.0")),
    ],
    targets: [
        .target(
            name: "SwiftyShell",
            dependencies: [
                .product(name: "Subprocess", package: "swift-subprocess"),
                .product(name: "SystemPackage", package: "swift-system"),
            ]
        ),
        .testTarget(
            name: "SwiftyShellTests",
            dependencies: ["SwiftyShell"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
