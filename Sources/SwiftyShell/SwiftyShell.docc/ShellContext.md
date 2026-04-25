# ``ShellContext``

Default execution settings shared by commands and pipelines.

## Overview

A ``ShellContext`` carries the executor, search paths, environment,
working directory, default timeout, and default output limit that every
``Command`` or ``Pipeline`` inherits when it runs. Per-command overrides
(``Command/timeout(_:)``, ``Command/workingDirectory(_:)``, …) take priority
over the context's defaults, so a single context can serve a whole program
while individual calls tune themselves where needed.

A fresh context inherits sensible platform defaults — the current process's
environment, the platform `PATH`, no working-directory override, no timeout,
and a 10 MB output cap:

```swift
import SwiftyShell

let context = ShellContext()
let output = try await Command("uname", "-a").run(in: context)
```

For longer-running scripts, set program-wide defaults at construction time so
every call inherits them:

```swift
let buildContext = ShellContext(
    workingDirectory: "/var/app",
    defaultTimeout: 120,
    defaultOutputLimit: 50_000_000   // 50 MB for verbose build output
)

try await Command("swift", "build", "--verbose").run(in: buildContext)
```

When tools live outside the standard `PATH` — common with Homebrew on Apple
Silicon — extend ``defaultSearchPaths`` instead of patching every call:

```swift
let context = ShellContext(
    searchPaths: ShellContext.defaultSearchPaths + ["/opt/homebrew/bin"]
)
```

To take the executor seam in tests, swap ``SubprocessExecutor`` (the default)
for a ``MockExecutor``. Every typed family or raw ``Command`` that uses the
context now goes through the mock:

```swift
let mock = MockExecutor(stdout: "on main\n")
let context = ShellContext(executor: mock)

let status = try await Git(context: context).status().run()
```

## Topics

### Creating a Context

- ``init(executor:searchPaths:environment:workingDirectory:defaultTimeout:defaultOutputLimit:)``

### Resolving Search Paths

- ``defaultSearchPaths``
- ``defaultSearchPaths(environment:platform:)``

### Inspecting a Context

- ``executor``
- ``searchPaths``
- ``environment``
- ``workingDirectory``
- ``defaultTimeout``
- ``defaultOutputLimit``

### Related Types

- ``ShellPlatform``
- ``CommandExecutor``
- ``SubprocessExecutor``
- ``MockExecutor``
