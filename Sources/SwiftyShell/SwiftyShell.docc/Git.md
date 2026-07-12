# ``Git``

A typed entry point for common git workflows.

## Submodule

Use ``submodule()`` when a repository needs to inspect, initialize, update, or
manage git submodules without dropping down to a raw ``Command``. The fluent
methods mirror `git submodule` flags, while typed workflows such as
``GitSubmodule/statusEntries()`` turn command output into Swift values.

### Inspect Submodule State

``GitSubmodule/statusEntries()`` runs `git submodule status` and returns parsed
``GitSubmoduleStatusEntry`` values. The leading git status marker is converted
to ``GitSubmoduleStatusState`` so callers can distinguish initialized,
uninitialized, out-of-sync, and conflicted submodules.

Use ``GitSubmodule/recursive(_:)`` when you also want nested submodules. The
result is an array of entries, one per submodule path, that you can branch on
without parsing stdout yourself.

Typed git workflows always capture their parser input, even if the fluent command
was previously configured to redirect stdout. Structured diff results use git's
NUL-delimited format so spaces, tabs, newlines, and rename or copy paths are
preserved exactly. Malformed structured output throws
``ShellError/parsingError(command:reason:)`` rather than being treated as an
empty result or clean repository.

```swift
let entries = try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .recursive()        // Include submodules inside submodules.
    .statusEntries()    // Parse `git submodule status` into Swift values.
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

### Initialize and Update

For the common clone bootstrap flow, run `git submodule update --init
--recursive`. This checks out the submodule commits recorded by the
superproject, initializes missing working directories, and also updates nested
submodules. ``GitSubmodule/jobs(_:)`` lets git fetch multiple submodules in
parallel when the installed git version supports it.

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .update()                // Select `git submodule update`.
    .initializeOnUpdate()    // Add `--init` for missing submodules.
    .recursive()             // Add `--recursive` for nested submodules.
    .jobs(4)                 // Add `--jobs 4` for parallel fetches.
    .run()
```

This example returns ``ShellOutput``. On success the repository's submodule
working directories are present and checked out to the commits referenced by the
current superproject commit.

To track submodule remotes instead of the commit recorded by the superproject,
use ``GitSubmodule/remote(_:)`` and choose an update strategy. This maps to
`git submodule update --remote --merge --recursive`, so each submodule moves to
the configured remote-tracking branch and merges that result into the submodule
working tree.

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .update()
    .remote()                  // Follow each submodule's configured remote branch.
    .updateStrategy(.merge)    // Merge remote updates instead of detached checkout.
    .recursive()
    .run()
```

### Add and Configure a Submodule

`add(_:path:)` records a repository in `.gitmodules` and stages it for the next
commit. Additional fluent options map to the documented `git submodule add`
flags. After this succeeds, `.gitmodules` and the submodule gitlink are ready to
be committed to the superproject.

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

### Sync, Summarize, and Iterate

The wrapper also covers maintenance commands that are useful in repository
automation. `sync` copies changed URLs from `.gitmodules` into each submodule's
local git config. `summary` returns raw ``ShellOutput`` describing commit ranges.
`foreach` runs the provided shell command from each submodule working directory.

```swift
try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .sync()         // Apply .gitmodules URL changes to local submodule config.
    .recursive()    // Include nested submodules.
    .run()

let summary = try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .summary()             // Show submodule commit differences.
    .cached()              // Compare against the index instead of the worktree.
    .summaryLimit(10)      // Limit commit lines per submodule.
    .run()

let foreachOutput = try await Git(context: context)
    .workingDirectory(repoPath)
    .submodule()
    .foreach("git status --short")    // Run this command in each submodule.
    .recursive()                       // Also visit nested submodules.
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
