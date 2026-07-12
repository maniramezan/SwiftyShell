# Getting Started with SwiftyShell

Add SwiftyShell to your package, pick a typed command family, and run your first command.

## Overview

SwiftyShell provides typed wrappers for common shell tools — ``Git``, ``Brew``, ``Grep``,
``Make``, ``Npm``, ``Yarn``, ``Pnpm``, ``Bun``, ``Terraform``, ``Kubectl``, ``Helm``, ``Python``, and more. These APIs make modeled options discoverable and provide structured results where available; raw option and argument escape hatches still require caller validation. For the full API reference and per-family guides, see the
<doc:SelectingCommandFamilies> article and the [documentation](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/).

## Installation

Add the package to your `Package.swift` and select only the families you need:

```swift
dependencies: [
    .package(
        url: "https://github.com/maniramezan/SwiftyShell.git",
        from: "0.3.0",
        traits: ["Git", "Brew"]   // pick only what you need
    ),
],
targets: [
    .target(
        name: "MyTool",
        dependencies: [
            .product(name: "SwiftyShell", package: "SwiftyShell")
        ]
    ),
]
```

Use the `All` trait to enable every command family, or `CommonUtilities` for the full
set of file-system utilities. See <doc:SelectingCommandFamilies> for the complete list.

## Example: Keep a Branch Up to Date with Main

A common automation task: fetch the latest changes from the remote, then rebase your
branch on top of `main` — but only if the working tree is clean:

```swift
import SwiftyShell

let context = ShellContext()
let git = Git(context: context).workingDirectory("/path/to/repo")

// Gate on a clean tree, then fetch + rebase
try await git
    .status()
    .require(\.state, equals: .noChanges)
    .fetch()
    .run()

try await git.rebase().onto("origin/main").run()
```

The `require(_:equals:)` gate throws ``ShellError`` before the fetch runs if there are
uncommitted changes, so the automation never silently stomps local work.

## Run the Example Package

The repository includes a standalone package under `Example/` that depends on the local checkout:

```sh
swift run --package-path Example
```

Use it as a small executable starting point without changing the library target.

## Secure Usage

``Command`` passes each argument as a separate argv entry and does not invoke a shell by default. This avoids shell splitting of values such as paths with spaces, but it does not validate an executable's own syntax. Do not interpolate untrusted input into `sh -c`, `python -c`, templates, expressions, environment variables, executable overrides, or output paths without tool-specific validation. Prefer fixed executable names or absolute paths and allowlisted options for privileged automation.

## Example: Install a Homebrew Package

```swift
import SwiftyShell

let context = ShellContext()

try await Brew(context: context)
    .install("ripgrep", "fzf")
    .run()
```

For cask installs, add `.cask()`:

```swift
try await Brew(context: context)
    .install("font-fira-code")
    .cask()
    .run()
```

## Next Steps

- <doc:SelectingCommandFamilies> — full trait list and how to mix families
- <doc:BuildingCommandFamilies> — add a typed wrapper for any tool not yet modelled
