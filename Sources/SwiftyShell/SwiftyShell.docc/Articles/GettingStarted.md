# Getting Started with SwiftyShell

Add SwiftyShell to your package, pick a typed command family, and run your first command.

## Overview

SwiftyShell provides typed wrappers for common shell tools — ``Git``, ``Brew``, ``Grep``,
``Make``, ``Npm``, ``Terraform``, ``Kubectl``, ``Python``, and more. The compiler enforces which flags exist, what arguments are required, and what
the result looks like. For the full API reference and per-family guides, see the
<doc:SelectingCommandFamilies> article and the [documentation](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/).

## Installation

Add the package to your `Package.swift` and select only the families you need:

```swift
dependencies: [
    .package(
        url: "https://github.com/maniramezan/SwiftyShell.git",
        from: "0.1.0",
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

try await git.rebase(onto: "origin/main").run()
```

The `require(_:equals:)` gate throws ``ShellError`` before the fetch runs if there are
uncommitted changes, so the automation never silently stomps local work.

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
