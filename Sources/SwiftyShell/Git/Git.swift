#if Git
import Foundation

/// A typed entry point for common git workflows.
///
/// ``Git`` wraps common `git` operations and returns strongly-typed results.
/// Use the fluent builder to configure the git executable, working directory,
/// environment, and other execution parameters before running a workflow:
///
/// ```swift
/// let context = ShellContext()
///
/// // Query repository status
/// let status = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .run()
/// print(status.branch ?? "detached HEAD", status.state)
///
/// // Require the working tree to be clean before pulling
/// try await Git(context: context)
///     .workingDirectory(repoPath)
///     .status()
///     .require(\.state, equals: .noChanges, else: MyError.dirtyTree)
///     .pull()
///     .run()
///
/// // Concurrent fetch across multiple repos
/// let git = Git(context: context)
/// try await withThrowingTaskGroup(of: GitFetchResult.self) { group in
///     for path in repoPaths {
///         group.addTask { try await git.workingDirectory(path).fetch().run() }
///     }
///     for try await result in group {
///         print("Fetched from", result.remote)
///     }
/// }
///
/// // Inspect recent commits in one-line format
/// let commits = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .log()
///     .format(.oneline)
///     .maxCount(5)
///     .run()
/// print(commits.stdout)
/// ```
public struct Git: ToolConfigurableCommandFamily {
    /// Shared configuration applied to commands produced by this client.
    ///
    /// Holds the executor, environment, working-directory, timeout, and output-limit overrides
    /// that get merged onto every `git` command this client builds. Mutated through the
    /// protocol-provided helpers (``executable(_:)``, ``env(_:_:)``, ``workingDirectory(_:)``,
    /// ``timeout(_:)``, ``outputLimit(_:)``).
    public let config: ToolConfiguration

    /// The shell context used when running git workflows.
    ///
    /// Forwarded from ``config`` so commands and workflows produced by this client share the
    /// same executor and defaults.
    public var context: ShellContext { config.context }

    /// Creates a git client bound to a shell context.
    ///
    /// The default executable is `git` resolved through the context's ``ShellContext/searchPaths``.
    /// Override with ``executable(_:)`` to point at a specific git binary.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.config = ToolConfiguration(context: context)
    }

    private init(config: ToolConfiguration) {
        self.config = config
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers. Most callers should use the typed helpers
    /// (``workingDirectory(_:)``, ``env(_:_:)``, etc.) rather than calling this directly.
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Git`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        Self(config: update(config))
    }

    /// Builds a workflow that runs `git status --porcelain=v2 --branch` and parses the output.
    ///
    /// The returned ``GitStatusWorkflow`` carries the git client reference, so follow-up calls
    /// like ``GitStatusWorkflow/pull()``, ``GitStatusWorkflow/fetch()``, and
    /// ``GitStatusWorkflow/require(_:else:)`` remain available without losing typing.
    ///
    /// ```swift
    /// let status = try await Git(context: context)
    ///     .workingDirectory(repoPath)
    ///     .status()
    ///     .run()
    /// ```
    ///
    /// - Returns: A ``GitStatusWorkflow`` that produces a ``GitStatus`` when run.
    public func status() -> GitStatusWorkflow {
        GitStatusWorkflow(
            git: self,
            workflow: Workflow {
                let output = try await makeCommand("status", "--porcelain=v2", "--branch").run(in: context)
                return try GitParsers.parseStatus(output.stdout)
            }
        )
    }

    /// Returns a typed wrapper for `git branch`.
    ///
    /// Use the returned ``GitBranch`` to list, create, rename, and delete branches.
    ///
    /// - Returns: A ``GitBranch`` bound to this client.
    public func branch() -> GitBranch {
        GitBranch(git: self)
    }

    /// Returns a typed wrapper for `git stash`.
    ///
    /// Use the returned ``GitStash`` to push, pop, list, and drop stash entries.
    ///
    /// - Returns: A ``GitStash`` bound to this client.
    public func stash() -> GitStash {
        GitStash(git: self)
    }

    /// Returns a typed wrapper for `git worktree`.
    ///
    /// Use the returned ``GitWorktree`` to add, list, and remove linked worktrees.
    ///
    /// - Returns: A ``GitWorktree`` bound to this client.
    public func worktree() -> GitWorktree {
        GitWorktree(git: self)
    }

    /// Returns a typed wrapper for `git submodule`.
    ///
    /// Use the returned ``GitSubmodule`` to update, init, sync, and inspect submodules.
    ///
    /// - Returns: A ``GitSubmodule`` bound to this client.
    public func submodule() -> GitSubmodule {
        GitSubmodule(git: self)
    }

    /// Returns a typed wrapper for `git diff`.
    ///
    /// Use the returned ``GitDiff`` to compare working tree, index, and arbitrary refs.
    ///
    /// - Returns: A ``GitDiff`` bound to this client.
    public func diff() -> GitDiff {
        GitDiff(git: self)
    }

    /// Returns a typed wrapper for `git log`.
    ///
    /// Use the returned ``GitLog`` to inspect commit history with formatting and filtering.
    ///
    /// - Returns: A ``GitLog`` bound to this client.
    public func log() -> GitLog {
        GitLog(git: self)
    }

    /// Returns a typed wrapper for `git config`.
    ///
    /// Reads, sets, unsets, and lists git configuration entries at the system, global, or
    /// local scope.
    ///
    /// - Returns: A ``GitConfigCommand`` bound to this client.
    public func gitConfig() -> GitConfigCommand {
        GitConfigCommand(git: self)
    }

    /// Returns a typed wrapper for `git config`.
    ///
    /// Alias for ``gitConfig()`` that reads more naturally at call sites
    /// (`git.configuration().get(...)`).
    ///
    /// - Returns: A ``GitConfigCommand`` bound to this client.
    public func configuration() -> GitConfigCommand {
        gitConfig()
    }

    /// Returns a typed wrapper for `git merge`.
    ///
    /// Use the returned ``GitMerge`` to merge refs with fast-forward, no-ff, and squash modes.
    ///
    /// - Returns: A ``GitMerge`` bound to this client.
    public func merge() -> GitMerge {
        GitMerge(git: self)
    }

    /// Returns a typed wrapper for `git commit`.
    ///
    /// Use the returned ``GitCommit`` to compose commits with message, amend, and signing
    /// options.
    ///
    /// - Returns: A ``GitCommit`` bound to this client.
    public func commit() -> GitCommit {
        GitCommit(git: self)
    }

    /// Returns a typed wrapper for `git rebase`.
    ///
    /// Use the returned ``GitRebase`` to rebase branches onto refs with continue/abort/skip
    /// support.
    ///
    /// - Returns: A ``GitRebase`` bound to this client.
    public func rebase() -> GitRebase {
        GitRebase(git: self)
    }

    /// Builds a workflow that runs `git pull` and reports the resulting branch state.
    ///
    /// After the pull, the workflow runs `git status --porcelain=v2 --branch` to resolve the
    /// current branch and upstream so the returned ``GitPullResult`` reflects post-pull state.
    /// `git pull` itself uses the repository's configured remote and branch — set them via
    /// repo configuration rather than here.
    ///
    /// - Returns: A ``Workflow`` producing a ``GitPullResult``.
    public func pull() -> Workflow<GitPullResult> {
        Workflow {
            _ = try await makeCommand("pull").run(in: context)
            let status = try await status().run()
            return GitPullResult(branch: status.branch ?? "HEAD", upstream: status.upstream)
        }
    }

    /// Builds a workflow that runs `git fetch` against the preferred remote.
    ///
    /// Remote selection: `origin` when present, otherwise the first remote returned by
    /// `git remote`, otherwise `origin` as a final fallback (which lets `git fetch` produce
    /// its own diagnostic if no remote is configured).
    ///
    /// - Returns: A ``Workflow`` producing a ``GitFetchResult`` describing the
    ///   fetched remote.
    public func fetch() -> Workflow<GitFetchResult> {
        Workflow {
            let remote = try await preferredRemote()
            _ = try await makeCommand("fetch", remote).run(in: context)
            return GitFetchResult(remote: remote)
        }
    }

    internal func makeCommand(_ arguments: String...) -> Command {
        config.apply(to: Command("git").args(arguments))
    }

    internal func makeCommand(_ arguments: [String]) -> Command {
        config.apply(to: Command("git").args(arguments))
    }

    internal func workflow(_ arguments: [String]) -> Workflow<ShellOutput> {
        Workflow {
            try await makeCommand(arguments).run(in: context)
        }
    }

    private func preferredRemote() async throws -> String {
        let output = try await makeCommand("remote").run(in: context)
        let remotes = output.stdout
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
        if remotes.contains("origin") {
            return "origin"
        }
        if let first = remotes.first {
            return first
        }
        return "origin"
    }
}
#endif
