# ``Brew``

A fluent wrapper for the Homebrew package manager.

## Topics

### Selecting a Subcommand

- ``install(_:)-(String...)``
- ``install(_:)-([String])``
- ``uninstall(_:)-(String...)``
- ``uninstall(_:)-([String])``
- ``upgrade(_:)-(String...)``
- ``upgrade(_:)-([String])``
- ``update()``
- ``list(_:)-(String...)``
- ``list(_:)-([String])``
- ``info(_:)-(String...)``
- ``info(_:)-([String])``
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
