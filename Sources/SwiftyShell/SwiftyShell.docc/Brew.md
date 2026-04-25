# ``Brew``

A fluent wrapper for the Homebrew package manager.

``Brew`` emits raw ``ShellOutput`` because Homebrew command output is still
tool-defined text. Use the typed methods to choose the subcommand and flags, then
inspect `stdout` or `stderr` when your automation needs the result.

This installs two formulae and throws ``ShellError/exitFailure(command:output:)``
if Homebrew reports an installation failure:

```swift
try await Brew(context: context)
    .install("ripgrep", "fzf")
    .run()
```

Use ``outdated()`` to ask Homebrew for upgrade candidates. The `greedy` flag also
includes casks that auto-update or are marked latest by upstream:

```swift
let outdated = try await Brew(context: context)
    .outdated()
    .greedy()
    .run()
```

The returned ``ShellOutput`` contains Homebrew's text output:

```swift
for package in outdated.stdout.split(whereSeparator: \.isNewline) {
    print("Upgrade available:", package)
}
```

Query package metadata with ``info(_:)-(String...)`` when your tool needs to
display or log the current Homebrew view of a formula:

```swift
let info = try await Brew(context: context)
    .info("swift-format")
    .run()
```

## Topics

### Selecting a Subcommand

- ``subcommand(_:)-(BrewSubcommand)``
- ``subcommand(_:)-(String)``
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

- ``arg(_:)``
- ``args(_:)``
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
