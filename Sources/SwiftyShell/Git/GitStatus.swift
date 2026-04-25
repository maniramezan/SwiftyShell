#if Git
import Foundation

/// A coarse description of the repository working tree state.
///
/// Returned by ``GitStatus/state``. Use this when an exact change inventory is not required —
/// for example, gating a `pull` on a clean working tree.
///
/// ```swift
/// guard status.state == .noChanges else {
///     throw MyError.workingTreeDirty
/// }
/// ```
public enum GitWorkingTreeState: Sendable, Equatable {
    /// No staged, unstaged, or untracked changes are present.
    ///
    /// Equivalent to `git status --porcelain=v2` producing no per-file entries.
    case noChanges

    /// The working tree contains at least one staged, unstaged, or untracked change.
    case dirty
}

/// Parsed repository status information from `git status --porcelain=v2 --branch`.
///
/// Built by the internal porcelain v2 parser when a ``GitStatusWorkflow`` runs. The fields
/// summarize what the parser observed; consult ``state`` for a coarse clean/dirty check, and
/// the boolean flags (``hasStagedChanges``, ``hasUnstagedChanges``, ``hasUntrackedFiles``) for
/// fine-grained discrimination.
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
    /// The overall working tree state derived from the parsed entries.
    ///
    /// `.noChanges` only when no staged, unstaged, or untracked entries are present.
    public var state: GitWorkingTreeState

    /// The current branch name, or `nil` when HEAD is detached.
    ///
    /// Parsed from the `# branch.head` header. Detached HEAD is reported as `nil`.
    public var branch: String?

    /// The upstream branch name (e.g. `"origin/main"`), or `nil` when no upstream is configured.
    ///
    /// Parsed from the `# branch.upstream` header.
    public var upstream: String?

    /// Whether at least one staged change is present in the index.
    public var hasStagedChanges: Bool

    /// Whether at least one tracked file has unstaged modifications in the working tree.
    public var hasUnstagedChanges: Bool

    /// Whether at least one untracked file is present in the working tree.
    public var hasUntrackedFiles: Bool

    /// Creates a parsed git status value.
    ///
    /// Typically constructed by SwiftyShell's porcelain v2 parser; exposed publicly so test
    /// fixtures and callers building synthetic `GitStatus` values can do so directly.
    ///
    /// - Parameters:
    ///   - state: Coarse clean/dirty summary.
    ///   - branch: Current branch name, or `nil` for detached HEAD.
    ///   - upstream: Upstream branch name, or `nil` when none configured.
    ///   - hasStagedChanges: Whether the index contains staged changes.
    ///   - hasUnstagedChanges: Whether tracked files have unstaged modifications.
    ///   - hasUntrackedFiles: Whether untracked files are present.
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

/// The result returned after a successful `git pull` workflow.
///
/// Built by ``Git/pull()`` after the pull succeeds and a follow-up `status` call resolves the
/// current branch and upstream. Both fields reflect repository state *after* the pull.
///
/// ```swift
/// let result = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .pull()
///     .run()
/// print("Now on", result.branch, "tracking", result.upstream ?? "no upstream")
/// ```
public struct GitPullResult: Sendable, Equatable {
    /// The current branch after pulling. Falls back to `"HEAD"` for detached HEAD.
    public var branch: String

    /// The upstream branch after pulling, or `nil` when no upstream is configured.
    public var upstream: String?

    /// Creates a git pull result.
    ///
    /// - Parameters:
    ///   - branch: The current branch (or `"HEAD"` when detached).
    ///   - upstream: The upstream branch, or `nil` when none configured.
    public init(branch: String, upstream: String?) {
        self.branch = branch
        self.upstream = upstream
    }
}

/// The result returned after a successful `git fetch` workflow.
///
/// Built by ``Git/fetch()``. The ``remote`` field reports the remote SwiftyShell selected to
/// fetch from — `origin` when present, otherwise the first configured remote.
///
/// ```swift
/// let result = try await Git(context: context)
///     .workingDirectory("/path/to/repo")
///     .fetch()
///     .run()
/// print("Fetched from remote:", result.remote)
/// ```
public struct GitFetchResult: Sendable, Equatable {
    /// The remote that was fetched (e.g. `"origin"`).
    public var remote: String

    /// Creates a git fetch result.
    ///
    /// - Parameter remote: The remote that was fetched.
    public init(remote: String) {
        self.remote = remote
    }
}
#endif
