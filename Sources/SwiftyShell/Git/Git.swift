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
