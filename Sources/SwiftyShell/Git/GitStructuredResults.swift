#if Git
import Foundation

/// A parsed branch entry returned by ``GitBranch/entries()``.
///
/// Use ``GitBranch/entries()`` when automation needs branch names as Swift values instead of
/// parsing `git branch` output. The `.all()` option includes local and remote branches, and each
/// result reports whether it is the currently checked-out branch plus any configured upstream.
///
/// ```swift
/// let branches = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .branch()
///     .all()        // Include local and remote branches.
///     .entries()    // Return [GitBranchEntry] instead of raw stdout.
///     .run()
///
/// for branch in branches where branch.isCurrent {
///     print("Current branch:", branch.name)
/// }
/// ```
public struct GitBranchEntry: Sendable, Equatable {
    /// The short branch or remote-ref name.
    public let name: String

    /// Indicates whether this entry is the current checked-out branch.
    public let isCurrent: Bool

    /// The upstream branch, if one is configured.
    public let upstream: String?

    /// Creates a parsed branch entry.
    public init(name: String, isCurrent: Bool, upstream: String?) {
        self.name = name
        self.isCurrent = isCurrent
        self.upstream = upstream
    }
}

/// A parsed commit entry returned by ``GitLog/entries()``.
///
/// Use ``GitLog/entries()`` when you need commit metadata as structured values. The workflow uses
/// a parser-friendly log format and returns each commit hash, abbreviated hash, author, email, and
/// subject line separately.
///
/// ```swift
/// let commits = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .log()
///     .maxCount(5)    // Limit the history window.
///     .entries()      // Return [GitLogEntry] instead of raw stdout.
///     .run()
///
/// for commit in commits {
///     print(commit.abbreviatedCommitHash, commit.subject)
/// }
/// ```
public struct GitLogEntry: Sendable, Equatable {
    /// The full commit hash.
    public let commitHash: String

    /// The abbreviated commit hash.
    public let abbreviatedCommitHash: String

    /// The author name.
    public let authorName: String

    /// The author email.
    public let authorEmail: String

    /// The commit subject line.
    public let subject: String

    /// Creates a parsed log entry.
    public init(
        commitHash: String,
        abbreviatedCommitHash: String,
        authorName: String,
        authorEmail: String,
        subject: String
    ) {
        self.commitHash = commitHash
        self.abbreviatedCommitHash = abbreviatedCommitHash
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.subject = subject
    }
}

/// The kind of change reported by ``GitDiffFileChange``.
public enum GitDiffChangeKind: Sendable, Equatable {
    /// A file was added.
    case added

    /// A file was modified.
    case modified

    /// A file was deleted.
    case deleted

    /// A file was renamed.
    case renamed

    /// A file was copied.
    case copied

    /// A file has unresolved merge state.
    case unmerged

    /// The file type changed.
    case typeChanged

    /// A git-specific status that is not modeled explicitly.
    case unknown(String)
}

/// A parsed file change returned by ``GitDiff/fileChanges()``.
///
/// Use ``GitDiff/fileChanges()`` when a script needs to route work based on added, modified,
/// deleted, renamed, copied, or unmerged files. The parser preserves git's raw status code while
/// also exposing a typed ``GitDiffChangeKind``.
///
/// ```swift
/// let changes = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .diff()
///     .staged()         // Compare staged changes instead of unstaged changes.
///     .fileChanges()    // Return [GitDiffFileChange] instead of raw stdout.
///     .run()
///
/// for change in changes where change.kind == .deleted {
///     print("Deleted:", change.path)
/// }
/// ```
public struct GitDiffFileChange: Sendable, Equatable {
    /// The kind of change git reported for the file.
    public let kind: GitDiffChangeKind

    /// The primary path for the change.
    public let path: String

    /// The source path for renames and copies.
    public let originalPath: String?

    /// The raw git status code, such as `M`, `A`, or `R100`.
    public let statusCode: String

    /// Creates a parsed diff file change.
    public init(kind: GitDiffChangeKind, path: String, originalPath: String?, statusCode: String) {
        self.kind = kind
        self.path = path
        self.originalPath = originalPath
        self.statusCode = statusCode
    }
}

/// The state prefix reported by `git submodule status` for a submodule entry.
public enum GitSubmoduleStatusState: Sendable, Equatable, Hashable {
    /// The submodule is initialized and checked out at the commit recorded by the superproject.
    case current

    /// The submodule is not initialized.
    case uninitialized

    /// The checked-out submodule commit differs from the commit recorded by the superproject.
    case outOfSync

    /// The submodule has merge conflicts.
    case mergeConflicted

    /// Git reported a state prefix that is not modeled explicitly.
    case unknown(String)
}

/// A parsed submodule status entry returned by ``GitSubmodule/statusEntries()``.
///
/// Each value represents one line from `git submodule status`: the submodule path, the reported
/// commit hash, optional `git describe` text, and a typed state derived from git's leading status
/// marker. Use this when automation needs to decide whether submodules are initialized, current,
/// out of sync with the superproject, or conflicted.
///
/// ```swift
/// let submodules = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .submodule()
///     .recursive()        // Include nested submodules.
///     .statusEntries()    // Return [GitSubmoduleStatusEntry] instead of raw stdout.
///     .run()
///
/// for submodule in submodules where submodule.state != .current {
///     print("\(submodule.path) needs attention")
/// }
/// ```
public struct GitSubmoduleStatusEntry: Sendable, Equatable {
    /// The state reported by the leading status prefix.
    public let state: GitSubmoduleStatusState

    /// The commit hash reported for the submodule.
    public let commitHash: String

    /// The path of the submodule relative to the superproject.
    public let path: String

    /// The optional `git describe` text reported after the path.
    public let description: String?

    /// Creates a parsed submodule status entry.
    public init(state: GitSubmoduleStatusState, commitHash: String, path: String, description: String?) {
        self.state = state
        self.commitHash = commitHash
        self.path = path
        self.description = description
    }
}
#endif
