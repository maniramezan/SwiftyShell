# ``Swift``

A fluent wrapper for the `swift` toolchain command.

``Swift`` covers common Swift package automation: building, testing, running executable products,
and invoking Swift Package Manager subcommands. It models frequently used SwiftPM options such as
package path, configuration, targets/products, package traits, compiler flag forwarding, code
coverage, and test filtering.

Build a package in release mode with warnings promoted to errors:

```swift
try await Swift(context: context)
    .build()
    .configuration(.release)
    .swiftCompilerFlag("-warnings-as-errors")
    .run()
```

Run tests with all package traits and code coverage:

```swift
try await Swift(context: context)
    .test()
    .enableAllTraits()
    .codeCoverage()
    .run()
```

Invoke a SwiftPM plugin or less common package command with raw arguments:

```swift
try await Swift(context: context)
    .package("generate-documentation")
    .argument("--target")
    .argument("SwiftyShell")
    .run()
```

Use ``argument(_:)`` or ``arguments(_:)`` for newer SwiftPM flags that are not modeled yet.

## Topics

### Subcommands

- ``SwiftSubcommand``
- ``subcommand(_:)-(SwiftSubcommand)``
- ``subcommand(_:)-(String)``
- ``build()``
- ``test()``
- ``runProduct(_:)``
- ``package(_:)``
- ``repl()``
- ``version()``

### Package Options

- ``SwiftBuildConfiguration``
- ``packagePath(_:)``
- ``scratchPath(_:)``
- ``configuration(_:)``
- ``target(_:)``
- ``product(_:)``
- ``traits(_:)-([String])``
- ``traits(_:)-(String...)``
- ``enableAllTraits(_:)``
- ``disableDefaultTraits(_:)``
- ``buildTests(_:)``
- ``codeCoverage(_:)``
- ``jobs(_:)``

### Test Options

- ``skipBuild(_:)``
- ``listTests(_:)``
- ``filter(_:)``
- ``skip(_:)``

### Flag Forwarding And Raw Arguments

- ``swiftCompilerFlag(_:)``
- ``swiftCompilerFlags(_:)``
- ``cCompilerFlag(_:)``
- ``linkerFlag(_:)``
- ``argument(_:)``
- ``arguments(_:)``
- ``positionalArgument(_:)``
- ``positionalArguments(_:)``

### Running

- ``init(context:)``
- ``command()``
