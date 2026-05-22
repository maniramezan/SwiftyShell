# ``Rsync``

A fluent wrapper for the `rsync` file synchronization command.

``Rsync`` covers the copy and synchronization options most useful in automation: archive or
recursive transfer, dry runs, deletion, filters, SSH transport configuration, bandwidth limits,
and source and destination operands. It preserves rsync's native path semantics, including the
important trailing slash behavior for directory sources.

Mirror a project directory to a remote host while deleting stale destination files:

```swift
try await Rsync(context: context)
    .archive()
    .compress()
    .delete()
    .exclude(".build")
    .source("/path/to/project/")
    .destination("deploy@example.com:/srv/project/")
    .run()
```

Preview a local synchronization before applying it:

```swift
let output = try await Rsync(context: context)
    .archive()
    .dryRun()
    .itemizeChanges()
    .source("assets/")
    .destination("public/assets/")
    .run()
```

Use a specific SSH command when pushing to a remote host:

```swift
try await Rsync(context: context)
    .archive()
    .remoteShell("ssh -i ~/.ssh/deploy_key")
    .source("dist/")
    .destination("deploy@example.com:/var/www/app/")
    .run()
```

Use ``option(_:)`` or ``options(_:)`` for less common rsync flags that are not modeled yet.

## Topics

### Transfer Mode

- ``archive(_:)``
- ``recursive(_:)``
- ``compress(_:)``
- ``dryRun(_:)``
- ``checksum(_:)``
- ``update(_:)``

### Operands

- ``source(_:)``
- ``sources(_:)``
- ``destination(_:)``

### Deletion And Existing Files

- ``delete(_:)``
- ``deleteExcluded(_:)``
- ``existing(_:)``
- ``ignoreExisting(_:)``
- ``removeSourceFiles(_:)``

### Metadata Preservation

- ``links(_:)``
- ``copyLinks(_:)``
- ``permissions(_:)``
- ``times(_:)``
- ``owner(_:)``
- ``group(_:)``
- ``hardLinks(_:)``
- ``sparse(_:)``
- ``oneFileSystem(_:)``

### Filtering

- ``exclude(_:)``
- ``excludes(_:)``
- ``include(_:)``
- ``includes(_:)``
- ``filter(_:)``
- ``filters(_:)``
- ``excludeFrom(_:)``
- ``includeFrom(_:)``
- ``filesFrom(_:)``
- ``from0(_:)``

### Remote And Limits

- ``remoteShell(_:)``
- ``remoteRsyncPath(_:)``
- ``port(_:)``
- ``bandwidthLimit(_:)``
- ``maxSize(_:)``
- ``minSize(_:)``
- ``ioTimeout(_:)``

### Output

- ``verbose(_:)``
- ``quiet(_:)``
- ``itemizeChanges(_:)``
- ``humanReadable(_:)``
- ``progress(_:)``
- ``partial(_:)``

### Raw Options

- ``option(_:)``
- ``options(_:)``

### Running

- ``init(context:)``
- ``command()``
