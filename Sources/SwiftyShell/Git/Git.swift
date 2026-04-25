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
    public let config: ToolConfiguration

    /// The shell context used when running git workflows.
    public var context: ShellContext { config.context }

    /// Creates a git client bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.config = ToolConfiguration(context: context)
    }

    private init(config: ToolConfiguration) {
        self.config = config
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        Self(config: update(config))
    }

    /// Builds a workflow that fetches and parses `git status --porcelain=v2 --branch`.
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
    public func branch() -> GitBranch {
        GitBranch(git: self)
    }

    /// Returns a typed wrapper for `git stash`.
    public func stash() -> GitStash {
        GitStash(git: self)
    }

    /// Returns a typed wrapper for `git worktree`.
    public func worktree() -> GitWorktree {
        GitWorktree(git: self)
    }

    /// Returns a typed wrapper for `git submodule`.
    public func submodule() -> GitSubmodule {
        GitSubmodule(git: self)
    }

    /// Returns a typed wrapper for `git diff`.
    public func diff() -> GitDiff {
        GitDiff(git: self)
    }

    /// Returns a typed wrapper for `git log`.
    public func log() -> GitLog {
        GitLog(git: self)
    }

    /// Returns a typed wrapper for `git config`.
    public func gitConfig() -> GitConfigCommand {
        GitConfigCommand(git: self)
    }

    /// Returns a typed wrapper for `git config`.
    public func configuration() -> GitConfigCommand {
        gitConfig()
    }

    /// Returns a typed wrapper for `git merge`.
    public func merge() -> GitMerge {
        GitMerge(git: self)
    }

    /// Returns a typed wrapper for `git commit`.
    public func commit() -> GitCommit {
        GitCommit(git: self)
    }

    /// Returns a typed wrapper for `git rebase`.
    public func rebase() -> GitRebase {
        GitRebase(git: self)
    }

    /// Builds a workflow that runs `git pull` and returns the resulting branch state.
    public func pull() -> Workflow<GitPullResult> {
        Workflow {
            _ = try await makeCommand("pull").run(in: context)
            let status = try await status().run()
            return GitPullResult(branch: status.branch ?? "HEAD", upstream: status.upstream)
        }
    }

    /// Builds a workflow that runs `git fetch` against the preferred remote.
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
