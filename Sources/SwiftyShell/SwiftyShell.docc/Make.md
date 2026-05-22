# ``Make``

A fluent wrapper for the `make` build automation CLI.

``Make`` is useful for project scripts that already expose tasks through a
Makefile. It models common flags such as Makefile selection, directory changes,
parallel jobs, dry runs, and target lists while keeping raw variable and option
arguments available.

Run a repository check target with parallel jobs:

```swift
try await Make(context: context)
    .file("Makefile")
    .jobs(8)
    .target("check")
    .run()
```

Pass Make variables before targets:

```swift
try await Make(context: context)
    .argument("CONFIGURATION=release")
    .targets(["build", "package"])
    .run()
```

## Topics

### Options

- ``file(_:)``
- ``directory(_:)``
- ``jobs(_:)``
- ``keepGoing(_:)``
- ``silent(_:)``
- ``dryRun(_:)``
- ``alwaysMake(_:)``

### Targets And Raw Arguments

- ``argument(_:)``
- ``arguments(_:)``
- ``target(_:)``
- ``targets(_:)``

### Running

- ``init(context:)``
- ``command()``
