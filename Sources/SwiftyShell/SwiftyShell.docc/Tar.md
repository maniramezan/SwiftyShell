# ``Tar``

A fluent wrapper for portable `tar` archive operations.

``Tar`` covers the archive operations that are most useful in build, release, and automation
scripts: create, extract, list, append, update, common compression modes, directory changes,
exclude filters, `files-from` inputs, and overwrite behavior. It builds an argv array directly,
so paths and patterns with spaces are passed as single arguments instead of being shell-parsed.

Create a gzip-compressed source archive while excluding build output:

```swift
try await Tar(context: context)
    .create()
    .gzip()
    .file("/tmp/source.tar.gz")
    .directory("/path/to/project")
    .exclude(".build")
    .path("Sources")
    .path("Package.swift")
    .run()
```

Extract into a destination directory without preserving archive owners:

```swift
try await Tar(context: context)
    .extract()
    .file("/tmp/source.tar.gz")
    .directory("/tmp/source")
    .noSameOwner()
    .run()
```

List selected members from an archive:

```swift
let output = try await Tar(context: context)
    .list()
    .file("/tmp/source.tar.gz")
    .path("Sources")
    .run()
```

Use ``option(_:)`` or ``options(_:)`` for implementation-specific flags that are not modeled by
the typed API yet.

## Topics

### Operations

- ``TarOperation``
- ``create()``
- ``extract()``
- ``list()``
- ``append()``
- ``update()``
- ``operation(_:)``

### Archive Inputs

- ``file(_:)``
- ``path(_:)``
- ``paths(_:)``
- ``directory(_:)``
- ``filesFrom(_:)``
- ``nullTerminatedFiles(_:)``

### Compression

- ``TarCompression``
- ``gzip()``
- ``bzip2()``
- ``xz()``
- ``autoCompress()``
- ``compression(_:)``

### Filtering

- ``exclude(_:)``
- ``excludes(_:)``
- ``excludeFrom(_:)``

### Extraction Behavior

- ``stripComponents(_:)``
- ``toStdout(_:)``
- ``preservePermissions(_:)``
- ``sameOwner(_:)``
- ``noSameOwner(_:)``
- ``keepOldFiles(_:)``
- ``skipOldFiles(_:)``
- ``overwrite(_:)``

### Archive Behavior

- ``verbose(_:)``
- ``verify(_:)``
- ``removeFilesAfterAdding(_:)``
- ``dereferenceSymlinks(_:)``
- ``absoluteNames(_:)``
- ``noRecursion(_:)``
- ``oneFileSystem(_:)``

### Raw Options

- ``option(_:)``
- ``options(_:)``

### Running

- ``init(context:)``
- ``command()``
