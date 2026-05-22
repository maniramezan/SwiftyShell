# ``Yarn``

A fluent wrapper for the Yarn package manager CLI.

## Overview

Use ``Yarn`` when you want package installs, script execution, or workspace
automation to share SwiftyShell's configuration, redirection, and testing
surface.

```swift
try await Yarn()
    .runScript("build")
    .immutable()
    .run()
```

You can still reach newer or plugin-provided Yarn commands by combining
``subcommand(_:)-(YarnSubcommand)``, raw arguments, and positional arguments.

```swift
let output = try await Yarn()
    .subcommand(.workspaces)
    .positionalArguments(["foreach", "--all", "run", "test"])
    .run()
```

## Topics

### Subcommands

- ``YarnSubcommand``
- ``subcommand(_:)-(YarnSubcommand)``
- ``subcommand(_:)-(String)``
- ``install()``

### Running Scripts

- ``Yarn/runScript(_:)``
- ``Yarn/test()``
- ``Yarn/exec(_:)``
- ``Yarn/dlx(_:)``

### Options

- ``cwd(_:)``
- ``immutable(_:)``
- ``production(_:)``
- ``silent(_:)``
- ``json(_:)``

### Arguments

- ``argument(_:)``
- ``arguments(_:)``
- ``positionalArgument(_:)``
- ``positionalArguments(_:)``
