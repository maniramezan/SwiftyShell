# ``InputSource``

Where a command's standard input comes from.

## Overview

Every command reads an empty stdin unless you give it an ``InputSource`` with
``Command/stdin(_:)``. An empty stdin means a tool that waits for input sees end
of file immediately instead of hanging.

Feed text, for example JSON into `jq`:

```swift
let name = try await Command("jq", arguments: "-r", ".name")
    .stdin(.string(#"{"name": "SwiftyShell"}"#))
    .run(in: context)
```

Typed command families accept a source directly through
``RunnableCommandFamily/run(stdin:)``:

```swift
let name = try await Jq(".name")
    .rawOutput()
    .run(stdin: .string(#"{"name": "SwiftyShell"}"#))
```

Feed raw bytes, or read a file the way shell `<` redirection does:

```swift
let checksum = try await Command("shasum", arguments: "-a", "256")
    .stdin(.data(archiveData))
    .run(in: context)

let lineCount = try await Command("wc", arguments: "-l")
    .stdin(.file(path: "Package.swift"))
    .run(in: context)
```

Large inputs do not deadlock against large outputs, and a command that exits
without reading all of its input is not an error for the caller. In a ``Pipeline`` only the first stage
may set a source; each later stage reads the previous stage's stdout, and a
source set on a later stage fails with
``ShellError/invalidConfiguration(description:)`` before anything runs.
Spawned processes read their source the same way.

Input sources are fixed values. Writing to a running process's stdin
interactively is not supported yet.

## Topics

### Sources

- ``none``
- ``string(_:)``
- ``data(_:)``
- ``file(path:)``
