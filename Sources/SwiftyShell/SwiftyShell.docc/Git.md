# ``Git``

A typed entry point for common git workflows.

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
