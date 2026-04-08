import Foundation

/// A coarse description of the repository working tree state.
public enum GitWorkingTreeState: Sendable, Equatable {
    /// No staged, unstaged, or untracked changes are present.
    case noChanges
    /// The working tree contains changes.
    case dirty
}

/// Parsed repository status information from `git status --porcelain=v2 --branch`.
///
/// Obtain a ``GitStatus`` by running a ``GitStatusWorkflow``:
///
/// ```swift
/// let status = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .status()
///     .run()
///
/// print("Branch:", status.branch ?? "detached HEAD")
/// print("Clean:", status.state == .noChanges)
/// if status.hasStagedChanges {
///     print("There are staged changes ready to commit")
/// }
/// ```
public struct GitStatus: Sendable, Equatable {
    /// The overall working tree state.
    public var state: GitWorkingTreeState
    /// The current branch name, if available.
    public var branch: String?
    /// The upstream branch name, if available.
    public var upstream: String?
    /// Indicates whether staged changes are present.
    public var hasStagedChanges: Bool
    /// Indicates whether unstaged changes are present.
    public var hasUnstagedChanges: Bool
    /// Indicates whether untracked files are present.
    public var hasUntrackedFiles: Bool

    /// Creates a parsed git status value.
    public init(
        state: GitWorkingTreeState,
        branch: String?,
        upstream: String?,
        hasStagedChanges: Bool,
        hasUnstagedChanges: Bool,
        hasUntrackedFiles: Bool
    ) {
        self.state = state
        self.branch = branch
        self.upstream = upstream
        self.hasStagedChanges = hasStagedChanges
        self.hasUnstagedChanges = hasUnstagedChanges
        self.hasUntrackedFiles = hasUntrackedFiles
    }
}

/// The result returned after a successful git pull workflow.
public struct GitPullResult: Sendable, Equatable {
    /// The current branch after pulling.
    public var branch: String
    /// The upstream branch, if one is configured.
    public var upstream: String?

    /// Creates a git pull result.
    public init(branch: String, upstream: String?) {
        self.branch = branch
        self.upstream = upstream
    }
}

/// The result returned after a successful git fetch workflow.
public struct GitFetchResult: Sendable, Equatable {
    /// The remote that was fetched.
    public var remote: String

    /// Creates a git fetch result.
    public init(remote: String) {
        self.remote = remote
    }
}
