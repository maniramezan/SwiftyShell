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
    /// The short branch or remote-ref name (e.g. `"main"`, `"origin/main"`).
    public let name: String

    /// Whether this entry is the currently checked-out branch.
    ///
    /// Parsed from the leading `*` marker that `git branch` prints next to HEAD.
    public let isCurrent: Bool

    /// The upstream branch configured for this branch, or `nil` when none is set.
    public let upstream: String?

    /// Creates a parsed branch entry.
    ///
    /// Typically constructed by SwiftyShell's parser; exposed publicly so test fixtures and
    /// callers building synthetic values can do so directly.
    ///
    /// - Parameters:
    ///   - name: The branch or remote-ref name.
    ///   - isCurrent: Whether this entry is the currently checked-out branch.
    ///   - upstream: The configured upstream, or `nil` when none.
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
    /// The full commit hash (e.g. `"a1b2c3d4e5..."`).
    public let commitHash: String

    /// The abbreviated commit hash as git would print it with `--abbrev-commit`.
    public let abbreviatedCommitHash: String

    /// The author's name as recorded on the commit.
    public let authorName: String

    /// The author's email as recorded on the commit.
    public let authorEmail: String

    /// The commit subject line — the first line of the commit message.
    public let subject: String

    /// Creates a parsed log entry.
    ///
    /// Typically constructed by SwiftyShell's parser from a unit-separator-delimited
    /// `git log --format=...` line. Exposed publicly so test fixtures and callers building
    /// synthetic values can do so directly.
    ///
    /// - Parameters:
    ///   - commitHash: The full commit hash.
    ///   - abbreviatedCommitHash: The abbreviated commit hash.
    ///   - authorName: The commit author's name.
    ///   - authorEmail: The commit author's email.
    ///   - subject: The commit subject line.
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
///
/// Derived from git's leading status code (e.g. `M`, `A`, `D`, `R100`). Use this enum for
/// pattern matching in routing logic; consult ``GitDiffFileChange/statusCode`` when you also
/// need the raw code (rename/copy similarity score, etc.).
public enum GitDiffChangeKind: Sendable, Equatable {
    /// A file was added (status code `A`).
    case added

    /// A file was modified (status code `M`).
    case modified

    /// A file was deleted (status code `D`).
    case deleted

    /// A file was renamed (status code `R` plus an optional similarity index).
    case renamed

    /// A file was copied (status code `C` plus an optional similarity index).
    case copied

    /// A file has unresolved merge state (status code `U`).
    case unmerged

    /// The file's mode/type changed (status code `T`).
    case typeChanged

    /// A git status code that this version of SwiftyShell does not model explicitly.
    ///
    /// Carries the raw status code so callers can still inspect it.
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
    /// The typed change kind derived from the leading character of ``statusCode``.
    public let kind: GitDiffChangeKind

    /// The primary path the change applies to.
    ///
    /// For renames and copies, this is the destination path; the source is reported in
    /// ``originalPath``.
    public let path: String

    /// The source path for renames and copies, or `nil` for non-rename/copy changes.
    public let originalPath: String?

    /// The raw git status code as printed by `git diff --name-status`.
    ///
    /// Examples: `"M"`, `"A"`, `"D"`, `"R100"`, `"C90"`. Renames and copies append a similarity
    /// percentage; the leading character is what feeds ``kind``.
    public let statusCode: String

    /// Creates a parsed diff file change.
    ///
    /// Typically constructed by SwiftyShell's parser; exposed publicly so test fixtures and
    /// callers building synthetic values can do so directly.
    ///
    /// - Parameters:
    ///   - kind: The typed change kind.
    ///   - path: The primary path (destination for renames and copies).
    ///   - originalPath: The source path for renames and copies, otherwise `nil`.
    ///   - statusCode: The raw git status code.
    public init(kind: GitDiffChangeKind, path: String, originalPath: String?, statusCode: String) {
        self.kind = kind
        self.path = path
        self.originalPath = originalPath
        self.statusCode = statusCode
    }
}

/// The state prefix reported by `git submodule status` for a submodule entry.
///
/// `git submodule status` prefixes each line with one character that indicates the submodule's
/// relationship to the superproject. This enum maps those characters to typed states.
public enum GitSubmoduleStatusState: Sendable, Equatable, Hashable {
    /// The submodule is initialized and checked out at the commit recorded by the superproject.
    ///
    /// Reported by git as a leading space character.
    case current

    /// The submodule is not initialized.
    ///
    /// Reported by git as a leading `-` character. Run `git submodule update --init` to
    /// initialize it.
    case uninitialized

    /// The checked-out submodule commit differs from the commit recorded by the superproject.
    ///
    /// Reported by git as a leading `+` character.
    case outOfSync

    /// The submodule has merge conflicts.
    ///
    /// Reported by git as a leading `U` character.
    case mergeConflicted

    /// Git reported a state prefix that this version of SwiftyShell does not model.
    ///
    /// Carries the raw prefix so callers can still inspect it.
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
    /// The state derived from the leading status prefix.
    public let state: GitSubmoduleStatusState

    /// The commit hash reported for the submodule.
    public let commitHash: String

    /// The submodule path relative to the superproject root.
    public let path: String

    /// The optional `git describe` text reported after the path.
    ///
    /// Typically includes the nearest tag (e.g. `"v1.2.3-4-gabcdef"`). `nil` when git did not
    /// emit a description for the entry.
    public let description: String?

    /// Creates a parsed submodule status entry.
    ///
    /// Typically constructed by SwiftyShell's parser; exposed publicly so test fixtures and
    /// callers building synthetic values can do so directly.
    ///
    /// - Parameters:
    ///   - state: The state derived from git's leading status prefix.
    ///   - commitHash: The submodule's commit hash.
    ///   - path: The submodule path relative to the superproject.
    ///   - description: The optional `git describe` text, or `nil` when absent.
    public init(state: GitSubmoduleStatusState, commitHash: String, path: String, description: String?) {
        self.state = state
        self.commitHash = commitHash
        self.path = path
        self.description = description
    }
}
#endif
