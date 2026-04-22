# ``SwiftyShell``

Type-safe shell support for Swift.

## Overview

SwiftyShell's primary API is a family of typed wrappers — ``Git``, ``Grep``,
``Brew``, ``Ls``, ``Cp``, ``Mkdir``, ``Rm``, ``Mv``, ``Pwd``, ``Jq`` — that
model shell tools as Swift values. The compiler enforces which flags exist,
which arguments are required, and what the result looks like. ``Command`` is
the fluent escape hatch for tools that don't have a typed wrapper yet; it
shares the same builder style so code does not change shape when you fall back
to it.

- **Typed command families** — reach for these first
- **``Workflow``** — composable async operations with `map` and `require` gates
- **``Pipeline``** — chain typed commands (or raw ones) through pipes
- **``Command``** — the escape hatch for arbitrary executables
- **``MockExecutor``** — inject via ``ShellContext`` to test without spawning processes

### Quick Start

```swift
import SwiftyShell

let context = ShellContext()

// Typed: the compiler knows what Git can do
let status = try await Git(context: context)
    .workingDirectory("/path/to/repo")
    .status()
    .require(\.state, equals: .noChanges)
    .pull()
    .run()

// Typed: Brew as a value, not a raw shell string
try await Brew(context: context).install("ripgrep", "fzf").run()

// Escape hatch: run anything not yet modelled
let output = try await Command("echo", "hello").run(in: context)
```

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:BuildingCommandFamilies>

### Core Execution

- ``Command``
- ``Pipeline``
- ``ShellContext``
- ``ShellPlatform``
- ``ShellOutput``
- ``OutputDestination``

### Error Handling

- ``ShellError``
- ``StreamKind``

### Workflows

- ``Workflow``

### Command Family Protocols

- ``ToolConfigurableCommandFamily``
- ``OutputRedirectingCommandFamily``
- ``RunnableCommandFamily``
- ``ToolConfiguration``

### Git

- ``Git``
- ``GitStatusWorkflow``
- ``GitStatus``
- ``GitWorkingTreeState``
- ``GitPullResult``
- ``GitFetchResult``

### Text Search

- ``Grep``
- ``GrepPattern``

### Package Management

- ``Brew``
- ``BrewSubcommand``

### Common File-System Commands

- ``Ls``
- ``Cp``
- ``Mkdir``
- ``Rm``
- ``Mv``
- ``Pwd``

### Data Processing

- ``Jq``
- ``JqArgument``

### Testing

- ``MockExecutor``
- ``CommandExecutor``
