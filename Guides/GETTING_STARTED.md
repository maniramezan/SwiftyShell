# Getting started

Add SwiftyShell to a Swift package, choose the typed command families you need, and run a command.

## Install

SwiftyShell uses SwiftPM package traits. The default trait set is empty, so the core API (`Command`, `Pipeline`, `Workflow`, and `ShellContext`) is available without enabling a command family.

Add the package and select traits on the dependency:

```swift
dependencies: [
    .package(
        url: "https://github.com/maniramezan/SwiftyShell.git",
        from: "0.3.0",
        traits: ["Git", "Grep"]
    )
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SwiftyShell", package: "SwiftyShell")
        ]
    )
]
```

Use `All` to enable every command family or `CommonUtilities` to enable all common file, directory, archive, data, and lookup utilities. The [supported commands guide](SUPPORTED_COMMANDS.md) lists every trait.

## Run a command

```swift
import SwiftyShell

let output = try await Command("echo", arguments: "hello").run()
print(output.stdout)
```

Arguments are separate argv entries. SwiftyShell does not ask a shell to split or reinterpret them.

## Use a typed family

With the `Git` trait enabled, a clean-tree check can gate the next operation:

```swift
import SwiftyShell

try await Git()
    .workingDirectory("/path/to/repo")
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()
```

For more examples and detail, see the DocC [Getting Started tutorial](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/gettingstarted) and [Selecting Command Families](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/selectingcommandfamilies).

## Run the example package

The repository includes a standalone package that depends on the local checkout:

```sh
swift run --package-path Example
```

## Secure usage

Separate argv entries prevent shell word splitting, but they do not validate the invoked tool's syntax. Validate untrusted values before using them as raw options, executable names, paths, environment values, or input to interpreters such as `sh -c` and `python -c`. Prefer fixed executable paths and allowlisted options in privileged automation.

For more, see the DocC tutorials on [core concepts](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/coreconcepts), [error handling](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/errorhandling), and [spawning processes](https://maniramezan.github.io/SwiftyShell/documentation/swiftyshell/spawningprocesses).
