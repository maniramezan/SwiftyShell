# ``Unzip``

A fluent wrapper for extracting, listing, and validating `.zip` archives with the Info-ZIP
`unzip` binary.

``Unzip`` works identically on macOS (where `unzip` ships by default) and on Linux
distributions that have the `unzip` package installed.

Extract an archive into a destination directory, overwriting existing files:

```swift
try await Unzip(context: context)
    .archive("/tmp/release.zip")
    .destination("/tmp/release")
    .overwrite()
    .run()
```

List entries with a typed result instead of parsing raw `unzip -l` output yourself:

```swift
let entries = try await Unzip(context: context)
    .archive("/tmp/release.zip")
    .entries()
    .run()

for entry in entries where entry.path.hasSuffix(".swift") {
    print("\(entry.path) — \(entry.size) bytes")
}
```

Validate archive integrity with ``test(_:)`` and pipe a single entry to stdout with
``printToStdout(_:)``:

```swift
try await Unzip(context: context).archive("/tmp/release.zip").test().run()

let scriptOutput = try await Unzip(context: context)
    .archive("/tmp/scripts.zip")
    .printToStdout()
    .member("install.sh")
    .run()
```

> Important: SwiftyShell does not feed stdin to spawned processes. Pass ``overwrite(_:)`` or
> ``neverOverwrite(_:)`` when extracting to avoid `unzip`'s interactive overwrite prompt
> hanging the call. ``password(_:)`` puts the password on the subprocess argv where other
> users may observe it via `ps`.

## Topics

### Archive Selection

- ``archive(_:)``
- ``member(_:)``
- ``members(_:)``
- ``exclude(_:)``
- ``excludes(_:)``

### Mode

- ``list(_:)``
- ``test(_:)``
- ``printToStdout(_:)``
- ``freshen(_:)``
- ``updateOnly(_:)``

### Behavior Flags

- ``destination(_:)``
- ``overwrite(_:)``
- ``neverOverwrite(_:)``
- ``quiet(_:)``
- ``junkPaths(_:)``
- ``preserveCase(_:)``

### Listing

- ``entries()``
- ``UnzipEntry``

### Security

- ``password(_:)``

### Running

- ``init(context:)``
- ``command()``
