import Foundation

/// A typed entry point for common git workflows.
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
