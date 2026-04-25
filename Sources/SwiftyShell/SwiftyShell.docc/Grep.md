# ``Grep``

A fluent wrapper for searching text with `grep`.

Use ``Grep`` for literal searches, ``regex(_:context:)`` for extended regular
expressions, and ``command()`` when `grep` should be used as a pipeline stage.
Each run returns ``ShellOutput`` with matching lines in `stdout`.

This searches every file under `Sources`, includes line numbers, and leaves the
matching lines in `todos.stdout`:

```swift
let todos = try await Grep("TODO", context: context)
    .recursive()
    .lineNumbers()
    .file("Sources")
    .run()
```

Use ``regex(_:context:)`` when the pattern should be interpreted as a regular
expression instead of as literal text:

```swift
let imports = try await Grep.regex("^import\\s+Foundation", context: context)
    .ignoreCase()
    .file("Sources/SwiftyShell")
    .run()
```

When composing pipelines, build a ``Command`` from the typed family and pass it
to ``Command/pipe(to:)``:

```swift
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
