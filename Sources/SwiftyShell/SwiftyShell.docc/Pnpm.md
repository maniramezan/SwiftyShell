# ``Pnpm``

A fluent wrapper for the pnpm package manager CLI.

## Overview

Use ``Pnpm`` for deterministic installs, workspace filtering, recursive script
runs, and package binary execution.

```swift
try await Pnpm()
    .runScript("build")
    .recursive()
    .filter("./packages/app")
    .run()
```

Raw options and positional arguments keep the wrapper usable for less common
pnpm commands without dropping to ``Command``.

```swift
let output = try await Pnpm()
    .subcommand(.audit)
    .json()
    .run()
```

## Topics

### Subcommands

- ``PnpmSubcommand``
- ``subcommand(_:)-(PnpmSubcommand)``
- ``subcommand(_:)-(String)``
- ``install()``

### Running Scripts

- ``Pnpm/runScript(_:)``
- ``Pnpm/test()``
- ``Pnpm/exec(_:)``
- ``Pnpm/dlx(_:)``

### Workspaces

- ``Pnpm/filter(_:)``
- ``Pnpm/recursive(_:)``

### Options

- ``directory(_:)``
- ``ifPresent(_:)``
- ``frozenLockfile(_:)``
- ``production(_:)``
- ``json(_:)``

### Arguments

- ``argument(_:)``
- ``arguments(_:)``
- ``positionalArgument(_:)``
- ``positionalArguments(_:)``
