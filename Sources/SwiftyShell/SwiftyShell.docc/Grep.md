# ``Grep``

A fluent wrapper for searching text with `grep`.

Use ``Grep`` for literal searches, ``regex(_:context:)`` for extended regular
expressions, and ``command()`` when `grep` should be used as a pipeline stage.

```swift
let todos = try await Grep("TODO", context: context)
    .recursive()
    .lineNumbers()
    .file("Sources")
    .run()

let imports = try await Grep.regex("^import\\s+Foundation", context: context)
    .ignoreCase()
    .file("Sources/SwiftyShell")
    .run()

let swiftFiles = try await Command("ls", "Sources")
    .pipe(to: Grep(".swift").command())
    .run(in: context)
```

## Topics

### Creating A Search

- ``init(_:context:)``
- ``regex(_:context:)``

### Matching Options

- ``ignoreCase(_:)``
- ``invertMatch(_:)``
- ``recursive(_:)``
- ``lineNumbers(_:)``
- ``count(_:)``

### Input Paths

- ``file(_:)``
- ``files(_:)``

### Running

- ``command()``

### Related Types

- ``GrepPattern``
