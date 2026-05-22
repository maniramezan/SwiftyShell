# ``Npm``

A fluent wrapper for the npm package manager CLI.

``Npm`` covers common package automation: lockfile installs, running package
scripts, tests, package execution, and shared npm flags such as `--prefix`,
`--if-present`, `--production`, and `--json`.

Run a package script:

```swift
try await Npm(context: context)
    .runScript("build")
    .prefix("Example")
    .ifPresent()
    .run()
```

Install dependencies in CI:

```swift
try await Npm(context: context)
    .ci()
    .prefix("Web")
    .run()
```

## Topics

### Subcommands

- ``NpmSubcommand``
- ``subcommand(_:)-(NpmSubcommand)``
- ``subcommand(_:)-(String)``
- ``install()``
- ``ci()``
- ``test()``
- ``exec(_:)``
- ``runScript(_:)``

### Options

- ``prefix(_:)``
- ``global(_:)``
- ``production(_:)``
- ``ifPresent(_:)``
- ``silent(_:)``
- ``json(_:)``

### Arguments

- ``argument(_:)``
- ``arguments(_:)``
- ``positionalArgument(_:)``
- ``positionalArguments(_:)``

### Running

- ``init(context:)``
- ``command()``
