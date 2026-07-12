# ``Env``

Print an environment or invoke a utility with controlled variables.

``Env`` supports the portable clean-environment and assignment behavior, plus `-u`, which is
available in both macOS/BSD and GNU implementations. ``command(_:arguments:)`` keeps every
argument as a separate argv value and does not invoke a shell.

```swift
let output = try await Env(context: context)
    .clean()
    .set("LANG", "C")
    .unset("HOME")
    .command("printenv", arguments: ["LANG"])
    .run()
```

Omit the invoked command to print the resulting environment:

```swift
let output = try await Env().clean().set("MODE", "test").run()
```

## Topics

### Environment

- ``init(context:)``
- ``clean(_:)``
- ``set(_:_:)-(String,String)``
- ``set(_:)-([String:String])``
- ``unset(_:)``
- ``command(_:arguments:)``
- ``command()``
