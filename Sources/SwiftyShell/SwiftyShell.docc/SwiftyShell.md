# ``SwiftyShell``

Type-safe shell support for Swift.

## Overview

SwiftyShell's primary API is a family of typed wrappers — ``Git``, ``Grep``, ``Rg``,
``Brew``, ``Fzf``, ``Ls``, ``Cp``, ``Mkdir``, ``Chmod``, ``Rm``, ``Mv``, ``Pwd``, ``Jq``,
``Zip``, ``Unzip`` — that model shell tools as Swift values. The compiler enforces which flags exist,
which arguments are required, and what the result looks like. ``Command`` is
the fluent escape hatch for tools that don't have a typed wrapper yet; it
shares the same builder style so code does not change shape when you fall back
to it.

Every typed family is **opt-in**. Consumers select which ones to compile via
SwiftPM package traits in their own `Package.swift`. By default a fresh
`import SwiftyShell` exposes only the always-on `Core` (commands, pipelines,
contexts, errors). See <doc:SelectingCommandFamilies> for the full list and
recipes.

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
let output = try await Command("echo", arguments: "hello").run(in: context)
```

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:SelectingCommandFamilies>
- <doc:CoreConcepts>
- <doc:SpawningProcesses>
- <doc:ErrorHandling>

### Building Command Families

- <doc:BuildingCommandFamilies>
- <doc:UsingAIAssistants>

### Core Execution

- ``Command``
- ``Pipeline``
- ``SpawnedProcess``
- ``TeardownStrategy``
- ``ProcessTeardownStep``
- ``ProcessSignal``
- ``ShellContext``
- ``ShellPlatform``
- ``ShellOutput``
- ``OutputDestination``
- ``SubprocessExecutor``
- ``FileMode``
- ``FileMode/PermissionSet``
- ``FileMode/SpecialBits``

### Error Handling

- ``ShellError``
- ``StreamKind``

### Workflow

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
- ``GitBranch``
- ``GitBranchEntry``
- ``GitStash``
- ``GitWorktree``
- ``GitSubmodule``
- ``GitSubmoduleUpdateStrategy``
- ``GitSubmoduleStatusEntry``
- ``GitSubmoduleStatusState``
- ``GitDiff``
- ``GitDiffFormat``
- ``GitDiffFileChange``
- ``GitDiffChangeKind``
- ``GitLog``
- ``GitLogFormat``
- ``GitLogEntry``
- ``GitConfigCommand``
- ``GitConfigFormat``
- ``GitMerge``
- ``GitCommit``
- ``GitRebase``

### Text Search

- ``Grep``
- ``GrepPattern``
- ``Rg``
- ``RgEngine``
- ``RgSortKey``
- ``RgColorWhen``

### Fuzzy Finder

- ``Fzf``
- ``FzfScheme``
- ``FzfAlgo``
- ``FzfLayout``
- ``FzfBorderStyle``
- ``FzfInfoStyle``
- ``FzfWrapMode``

### Package Management

- ``Brew``
- ``BrewSubcommand``

### Common File-System Commands

- ``Ls``
- ``Cp``
- ``Mkdir``
- ``Chmod``
- ``Rm``
- ``Mv``
- ``Pwd``

### Archives

- ``Zip``
- ``ZipCompressionLevel``
- ``Unzip``
- ``UnzipEntry``

### Data Processing

- ``Jq``
- ``JqArgument``

### Testing

- ``MockExecutor``
- ``MockSpawnedProcess``
- ``CommandExecutor``
