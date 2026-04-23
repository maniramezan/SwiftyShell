#if Git
import Foundation

/// A parsed branch entry returned by ``GitBranch/entries()``.
///
/// ```swift
/// let branches = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .branch()
///     .all()
///     .entries()
///     .run()
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
/// ```swift
/// let commits = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .log()
///     .maxCount(5)
///     .entries()
///     .run()
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
/// ```swift
/// let changes = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .diff()
///     .staged()
///     .fileChanges()
///     .run()
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
#endif
