# ``Git``

A typed entry point for common git workflows.

## Submodules

Use ``submodule()`` when a repository needs to inspect, initialize, update, or
manage git submodules without dropping down to a raw ``Command``.

### Inspect Submodule State

``GitSubmodule/statusEntries()`` runs `git submodule status` and returns parsed
``GitSubmoduleStatusEntry`` values. The leading git status marker is converted
to ``GitSubmoduleStatusState`` so callers can distinguish initialized,
uninitialized, out-of-sync, and conflicted submodules.

```swift
let entries = try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .recursive()
    .statusEntries()
    .run()

for entry in entries {
    switch entry.state {
    case .current:
        print("\(entry.path) is at \(entry.commitHash)")
    case .uninitialized:
        print("\(entry.path) needs initialization")
    case .outOfSync:
        print("\(entry.path) does not match the superproject commit")
    case .mergeConflicted:
        print("\(entry.path) has submodule merge conflicts")
    case .unknown(let marker):
        print("\(entry.path) reported unknown marker \(marker)")
    }
}
```

### Initialize And Update

For the common clone bootstrap flow, select `update`, initialize missing
submodules, and recurse into nested modules:

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .update()
    .initializeOnUpdate()
    .recursive()
    .jobs(4)
    .run()
```

To track submodule remotes instead of the commit recorded by the superproject,
use `remote()` and choose an update strategy:

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .update()
    .remote()
    .updateStrategy(.merge)
    .recursive()
    .run()
```

### Add And Configure A Submodule

`add(_:path:)` records a repository in `.gitmodules` and stages it for the next
commit. Additional fluent options map to the documented `git submodule add`
flags.

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .add("https://github.com/example/design-system.git", path: "Vendor/DesignSystem")
    .branch("main")
    .name("design-system")
    .depth(1)
    .run()
```

Change the configured tracking branch or URL later with typed helpers:

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .setBranch("stable", path: "Vendor/DesignSystem")
    .run()

try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .setUrl(path: "Vendor/DesignSystem", to: "https://github.com/example/design-system-v2.git")
    .run()
```

### Sync, Summarize, And Iterate

The wrapper also covers maintenance commands that are useful in repository
automation:

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .sync()
    .recursive()
    .run()

let summary = try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .summary()
    .cached()
    .summaryLimit(10)
    .run()

let foreachOutput = try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .foreach("git status --short")
    .recursive()
    .run()
```

## Topics

### Querying Repository State

- ``status()``

### Updating Branches

- ``pull()``
- ``fetch()``

### Typed Subcommands

- ``branch()``
- ``stash()``
- ``worktree()``
- ``submodule()``
- ``diff()``
- ``log()``
- ``gitConfig()``
- ``configuration()``
- ``merge()``
- ``commit()``
- ``rebase()``

### Tool Configuration

- ``init(context:)``
- ``executable(_:)``
- ``workingDirectory(_:)``
- ``env(_:_:)``
- ``env(_:)``
- ``timeout(_:)``
- ``outputLimit(_:)``

### Related Types

- ``GitStatus``
- ``GitStatusWorkflow``
- ``GitWorkingTreeState``
- ``GitPullResult``
- ``GitFetchResult``
- ``GitBranch``
- ``GitStash``
- ``GitWorktree``
- ``GitSubmodule``
- ``GitSubmoduleUpdateStrategy``
- ``GitSubmoduleStatusEntry``
- ``GitSubmoduleStatusState``
- ``GitDiff``
- ``GitLog``
- ``GitConfigCommand``
- ``GitMerge``
- ``GitCommit``
- ``GitRebase``
- ``GitBranchEntry``
- ``GitLogEntry``
- ``GitDiffFileChange``
- ``GitDiffChangeKind``
- ``GitDiffFormat``
- ``GitLogFormat``
- ``GitConfigFormat``
