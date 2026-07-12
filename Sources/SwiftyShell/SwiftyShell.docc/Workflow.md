# ``Workflow``

A reusable asynchronous workflow that can be transformed and composed.

## Overview

A ``Workflow`` wraps an `async` operation that produces a single value of type
`Value`. The wrapped work is **lazy** — nothing executes until you call
``run()``. Compose new behavior by chaining ``map(_:)-((Value)->T)``,
``flatMap(_:)``, ``then(_:)``, and the ``require(_:else:)-swift.method`` /
``require(_:equals:else:)`` gates, then await ``run()`` once at the end.

Typed command families return ``Workflow`` values from operations that produce
structured results — ``Git/status()`` is the canonical example. Build up the
gate, transform, and follow-up actions, then run once:

```swift
let branch = try await Git(context: context)
    .workingDirectory(repoPath)
    .status()                                // Workflow<GitStatus>
    .require(\.state, equals: .noChanges)    // abort if working tree is dirty
    .map(\.branch)                           // Workflow<String?>
    .run()

print(branch ?? "detached HEAD")
```

Use ``flatMap(_:)`` to switch into a different workflow once the first one
succeeds. Here we read the status, gate on a clean tree, then run a `pull` and
return its result:

```swift
let pullResult = try await Git(context: context)
    .workingDirectory(repoPath)
    .status()
    .require(\.state, equals: .noChanges)
    .pull()                                  // returns Workflow<GitPullResult>
    .run()
```

To wrap arbitrary `async` work, construct a ``Workflow`` directly:

```swift
let count = Workflow {
    let output = try await Command("git", arguments: "rev-list", "--count", "HEAD").run(in: context)
    return Int(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
}

let total = try await count.run()
```

Although ``run()`` is a `consuming` method, ``Workflow`` is a copyable value that stores a reusable closure. Calling it again, or running a copy, starts the described work again. Avoid repetition or concurrency when the underlying operation has side effects that make that unsafe.

## Topics

### Running

- ``run()``

### Transforming

- ``map(_:)-((Value)->T)``
- ``map(_:)-(KeyPath<Value,T>)``
- ``flatMap(_:)``
- ``then(_:)``

### Gating

- ``require(_:else:)-swift.method``
- ``require(_:equals:else:)``

### Creating

- ``init(_:)``
