# ``Brew``

A fluent wrapper for the Homebrew package manager.

## Topics

### Selecting a Subcommand

- ``install(_:)-swift.method``
- ``uninstall(_:)-swift.method``
- ``upgrade(_:)-swift.method``
- ``update()``
- ``list(_:)-swift.method``
- ``info(_:)-swift.method``
- ``search(_:)``
- ``outdated()``

### Adding Formulae and Casks

- ``formula(_:)``
- ``formulae(_:)``

### Flags

- ``cask(_:)``
- ``formulaFlag(_:)``
- ``force(_:)``
- ``quiet(_:)``
- ``verbose(_:)``
- ``dryRun(_:)``
- ``greedy(_:)``

### Tool Configuration

- ``init(context:)``
- ``executable(_:)``
- ``workingDirectory(_:)``
- ``env(_:_:)``
- ``timeout(_:)``
- ``outputLimit(_:)``

### Running

- ``command()``

### Related Types

- ``BrewSubcommand``
