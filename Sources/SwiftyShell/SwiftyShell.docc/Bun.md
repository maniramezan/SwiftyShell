# ``Bun``

A fluent wrapper for the Bun runtime and package manager CLI.

## Overview

Use ``Bun`` for script execution, testing, dependency management, package binary
execution, and bundling through Bun's CLI.

```swift
try await Bun()
    .runScript("dev")
    .watch()
    .run()
```

The wrapper exposes common automation flags and keeps raw options available for
newer Bun features.

```swift
let output = try await Bun()
    .build("src/index.ts")
    .argument("--outdir")
    .positionalArgument("dist")
    .run()
```

## Topics

### Subcommands

- ``BunSubcommand``
- ``subcommand(_:)-(BunSubcommand)``
- ``subcommand(_:)-(String)``
- ``install()``

### Running Code

- ``Bun/runScript(_:)``
- ``Bun/test()``
- ``Bun/x(_:)``

### Building

- ``build(_:)-(String...)``
- ``build(_:)-([String])``

### Options

- ``cwd(_:)``
- ``watch(_:)``
- ``hot(_:)``
- ``production(_:)``
- ``frozenLockfile(_:)``

### Arguments

- ``argument(_:)``
- ``arguments(_:)``
- ``positionalArgument(_:)``
- ``positionalArguments(_:)``
