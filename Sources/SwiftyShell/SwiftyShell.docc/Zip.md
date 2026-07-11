# ``Zip``

A fluent wrapper for creating and modifying `.zip` archives with the Info-ZIP `zip` binary.

``Zip`` works identically on macOS (where `zip` ships by default) and on Linux distributions
that have the `zip` package installed. Successful archive creation usually produces summary
output on stdout; treat completion without ``ShellError/exitFailure(command:output:)`` as the
authoritative result.

Create a recursive archive of a build directory at maximum compression:

```swift
try await Zip(context: context)
    .recursive()
    .compressionLevel(.best)
    .archive("/tmp/release.zip")
    .path("build/")
    .run()
```

Combine ``recursive(_:)`` with ``exclude(_:)`` to skip junk files when packaging a tree:

```swift
try await Zip(context: context)
    .recursive()
    .archive("/tmp/source.zip")
    .path("Sources/")
    .excludes(["*.tmp", "*/.build/*"])
    .run()
```

Use ``update(_:)`` or ``freshen(_:)`` to modify an existing archive instead of overwriting it:

```swift
try await Zip(context: context)
    .update()
    .archive("/tmp/release.zip")
    .path("build/Info.plist")
    .run()
```

> Important: ``password(_:)`` puts the password directly on the subprocess argv where it may be
> visible to other users via `ps`. The current execution API cannot answer the interactive
> password prompt.

## Topics

### Archive Inputs

- ``archive(_:)``
- ``path(_:)``
- ``paths(_:)``

### Mode

- ``update(_:)``
- ``freshen(_:)``
- ``delete(_:)``
- ``move(_:)``

### Behavior Flags

- ``recursive(_:)``
- ``quiet(_:)``
- ``verbose(_:)``
- ``junkPaths(_:)``
- ``storeSymlinks(_:)``
- ``stripExtraFields(_:)``

### Compression

- ``compressionLevel(_:)``
- ``ZipCompressionLevel``
- ``splitSize(_:)``

### Filtering

- ``include(_:)``
- ``includes(_:)``
- ``exclude(_:)``
- ``excludes(_:)``

### Security

- ``password(_:)``
- ``encryptInteractive(_:)``

### Running

- ``init(context:)``
- ``command()``
