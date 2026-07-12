# ``Cargo``

A fluent wrapper for Cargo package automation.

``Cargo`` covers common Rust build, test, check, run, format, Clippy, and
package operations. Shared selectors model manifests, packages, workspaces,
features, targets, and release builds.

Build an optimized workspace with selected features:

```swift
try await Cargo(context: context)
    .build()
    .workspace()
    .features("serde", "cli")
    .release()
    .run()
```

## Forwarded Arguments

Cargo uses `--` to separate its options from arguments passed to programs,
test harnesses, rustfmt, and Clippy. The dedicated methods insert that boundary
without requiring callers to manage it manually:

```swift
try await Cargo(context: context)
    .runBinary("server")
    .programArguments(["--port", "8080"])
    .run()

try await Cargo(context: context)
    .test("parser::")
    .testArgument("--nocapture")
    .run()

try await Cargo(context: context)
    .clippy()
    .allTargets()
    .toolArguments(["-D", "warnings"])
    .run()
```

Use ``argument(_:)`` and ``arguments(_:)`` for Cargo options that are not
modeled yet. Those values remain before any forwarded-argument separator.

## Topics

### Operations

- ``CargoSubcommand``
- ``subcommand(_:)-(CargoSubcommand)``
- ``build()``
- ``test(_:)``
- ``check()``
- ``runBinary(_:)``
- ``format()``
- ``clippy()``
- ``package()``
- ``version()``

### Selection

- ``manifestPath(_:)``
- ``package(_:)``
- ``packages(_:)``
- ``workspace(_:)``
- ``features(_:)-([String])``
- ``features(_:)-(String...)``
- ``allFeatures(_:)``
- ``noDefaultFeatures(_:)``
- ``CargoTarget``
- ``target(_:)``
- ``release(_:)``

### Forwarding

- ``programArgument(_:)``
- ``programArguments(_:)``
- ``testArgument(_:)``
- ``testArguments(_:)``
- ``toolArgument(_:)``
- ``toolArguments(_:)``
