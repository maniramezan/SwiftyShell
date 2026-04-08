# ``SwiftyShell``

Type-safe shell command execution for Swift.

## Overview

SwiftyShell models shell concepts — commands, arguments, pipelines, redirection, and
workflows — as Swift values rather than raw strings. It provides:

- **``Command``** — a single executable with typed fluent configuration
- **``Pipeline``** — two or more commands connected through pipes
- **Typed command families** — `Git`, `Grep`, `Ls`, `Cp`, `Mkdir`, `Rm`, `Mv`, `Pwd`, `Jq`
- **``Workflow``** — composable async operations with `map`, `require`, and `flatMap`
- **``MockExecutor``** — a test double that never spawns real processes

### Quick Start

```swift
import SwiftyShell

let context = ShellContext()

// Run any command
let output = try await Command("echo", "hello").run(in: context)
print(output.stdout) // "hello\n"

// Use a typed client
let status = try await Git(context: context)
    .workingDirectory("/path/to/repo")
    .status()
    .run()
print(status.branch ?? "detached HEAD")

// Build a pipeline
let result = try await Command("ls", "-la")
    .pipe(to: Grep(".swift").command())
    .run(in: context)
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
