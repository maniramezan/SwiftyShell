#if Git
import Foundation

/// The output format used by ``GitDiff``.
///
/// Selects which `--*` flag is added to `git diff`. Use ``GitDiff/format(_:)`` to apply a value.
public enum GitDiffFormat: Sendable, Equatable, Hashable {
    /// The standard patch format (no extra flag — git's default).
    case patch

    /// A compact summary of changed files (`--stat`).
    case stat

    /// A list of changed file paths (`--name-only`).
    case nameOnly

    /// A list of changed files with status letters (`--name-status`).
    ///
    /// This is also the format ``GitDiff/fileChanges()`` uses internally to produce
    /// ``GitDiffFileChange`` values.
    case nameStatus

    fileprivate var arguments: [String] {
        switch self {
        case .patch:
            return []
        case .stat:
            return ["--stat"]
        case .nameOnly:
            return ["--name-only"]
        case .nameStatus:
            return ["--name-status"]
        }
    }
}

/// The output format used by ``GitLog``.
///
/// Selects which `--format`/`--pretty` flag is added to `git log`. Use ``GitLog/format(_:)`` to
/// apply a value.
public enum GitLogFormat: Sendable, Equatable, Hashable {
    /// Git's default multi-line commit format (no extra flag).
    case medium

    /// A single-line summary per commit (`--oneline`).
    case oneline

    /// A short multi-line commit format (`--format=short`).
    case short

    /// A user-provided pretty format string passed as `--pretty=<value>`.
    ///
    /// Useful for emitting commits in a parser-friendly layout. ``GitLog/entries()`` uses this
    /// case internally with a unit-separator-delimited format.
    case pretty(String)

    fileprivate var arguments: [String] {
        switch self {
        case .medium:
            return []
        case .oneline:
            return ["--oneline"]
        case .short:
            return ["--format=short"]
        case let .pretty(value):
            return ["--pretty=\(value)"]
        }
    }
}

/// The output format used by ``GitConfigCommand`` when listing configuration.
///
/// Selects which formatting flag is added to `git config --list`. Use
/// ``GitConfigCommand/format(_:)`` to apply a value.
public enum GitConfigFormat: Sendable, Equatable, Hashable {
    /// Standard `key=value` output (no extra flag).
    case defaultFormat

    /// Null-delimited `key\0value\0` output (`-z`). Useful when values may contain newlines.
    case nullTerminated

    /// Show each config value with its origin file (`--show-origin`).
    case showOrigin

    /// Show each config value with its scope: `system`, `global`, or `local` (`--show-scope`).
    case showScope

    fileprivate var arguments: [String] {
        switch self {
        case .defaultFormat:
            return []
        case .nullTerminated:
            return ["-z"]
        case .showOrigin:
            return ["--show-origin"]
        case .showScope:
            return ["--show-scope"]
        }
    }
}

/// A fluent wrapper for `git branch`.
///
/// Use ``GitBranch`` for branch listing and branch mutations. Calling ``run()`` returns raw
/// ``ShellOutput`` from git, while ``entries()`` parses branch listings into ``GitBranchEntry``
/// values.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .branch()
///     .list()    // Select `git branch --list`.
///     .all()     // Include remote-tracking branches.
///     .run()
///
/// print(output.stdout)
/// ```
public struct GitBranch: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git branch` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git branch` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that lists branches instead of creating one.
    ///
    /// Maps to the `--list` flag. Combine with ``all(_:)`` to also list remote-tracking branches,
    /// or use ``entries()`` for parsed ``GitBranchEntry`` values.
    ///
    /// - Parameter enabled: `true` to add `--list`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``GitBranch`` value with the flag applied.
    public func list(_ enabled: Bool = true) -> Self {
        copy(listsBranches: enabled)
    }

    /// Returns a copy that includes remote-tracking branches when listing.
    ///
    /// Maps to the `--all` flag.
    ///
    /// - Parameter enabled: `true` to add `--all`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``GitBranch`` value with the flag applied.
    public func all(_ enabled: Bool = true) -> Self {
        copy(includesAllBranches: enabled)
    }

    /// Returns a copy that deletes the named branch.
    ///
    /// Maps to `git branch -d <name>`. Use ``forceDelete(_:)`` to force-delete a branch with
    /// unmerged work.
    ///
    /// - Parameter name: The branch to delete.
    /// - Returns: A new ``GitBranch`` value configured to delete the branch.
    public func delete(_ name: String) -> Self {
        copy(deletesBranch: true, forceDeletesBranch: false, branchName: name)
    }

    /// Returns a copy that force-deletes the named branch.
    ///
    /// Maps to `git branch -D <name>`. Bypasses the safety check that prevents deleting an
    /// unmerged branch.
    ///
    /// - Parameter name: The branch to force-delete.
    /// - Returns: A new ``GitBranch`` value configured to force-delete the branch.
    public func forceDelete(_ name: String) -> Self {
        copy(deletesBranch: false, forceDeletesBranch: true, branchName: name)
    }

    /// Returns a copy that sets the branch name for create, move, or delete operations.
    ///
    /// When neither ``delete(_:)``, ``forceDelete(_:)``, nor ``move(to:)`` has been selected,
    /// supplying a name causes git to create the named branch (optionally at the
    /// ``startPoint(_:)`` ref).
    ///
    /// - Parameter name: The branch name.
    /// - Returns: A new ``GitBranch`` value with the name applied.
    public func named(_ name: String) -> Self {
        copy(branchName: name)
    }

    /// Returns a copy that sets the start-point ref used when creating a branch.
    ///
    /// Forwarded to git as a positional argument after the new branch name (e.g.
    /// `git branch new-feature origin/main`).
    ///
    /// - Parameter value: The commit, branch, or tag to start the new branch from.
    /// - Returns: A new ``GitBranch`` value with the start point applied.
    public func startPoint(_ value: String) -> Self {
        copy(startPoint: value)
    }

    /// Returns a copy that renames a branch to the given new name.
    ///
    /// Maps to `git branch -m <old> <new>` when combined with ``named(_:)``, or
    /// `git branch -m <new>` (which renames the current branch) when no name is set.
    ///
    /// - Parameter newName: The new branch name.
    /// - Returns: A new ``GitBranch`` value configured to perform the rename.
    public func move(to newName: String) -> Self {
        copy(movesBranch: true, newBranchName: newName)
    }

    /// Builds the raw `git branch` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["branch"]

        if state.listsBranches {
            arguments.append("--list")
        }
        if state.includesAllBranches {
            arguments.append("--all")
        }
        if state.deletesBranch {
            arguments.append("-d")
        }
        if state.forceDeletesBranch {
            arguments.append("-D")
        }
        if state.movesBranch {
            arguments.append("-m")
        }
        if let branchName = state.branchName {
            arguments.append(branchName)
        }
        if let newBranchName = state.newBranchName {
            arguments.append(newBranchName)
        }
        if let startPoint = state.startPoint {
            arguments.append(startPoint)
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    /// Runs `git branch` with a parser-friendly format and returns typed branch entries.
    ///
    /// Uses `--format=%(HEAD)\t%(refname:short)\t%(upstream:short)` so the parser can recover
    /// the current-branch marker, branch name, and upstream cleanly. Pair with ``all(_:)`` to
    /// include remote-tracking branches.
    ///
    /// ```swift
    /// let entries = try await git.branch().all().entries().run()
    /// for entry in entries where entry.isCurrent {
    ///     print("On", entry.name, "->", entry.upstream ?? "no upstream")
    /// }
    /// ```
    ///
    /// - Returns: A single-use ``Workflow`` producing parsed ``GitBranchEntry`` values.
    public func entries() -> Workflow<[GitBranchEntry]> {
        let git = state.git
        let command = git.makeCommand(
            "branch",
            "--format=%(HEAD)\t%(refname:short)\t%(upstream:short)"
        )
        return Workflow {
            let output = try await command.run(in: git.context)
            return GitParsers.parseBranchEntries(output.stdout)
        }
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        listsBranches: Bool? = nil,
        includesAllBranches: Bool? = nil,
        deletesBranch: Bool? = nil,
        forceDeletesBranch: Bool? = nil,
        movesBranch: Bool? = nil,
        branchName: String?? = nil,
        newBranchName: String?? = nil,
        startPoint: String?? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                listsBranches: listsBranches ?? state.listsBranches,
                includesAllBranches: includesAllBranches ?? state.includesAllBranches,
                deletesBranch: deletesBranch ?? state.deletesBranch,
                forceDeletesBranch: forceDeletesBranch ?? state.forceDeletesBranch,
                movesBranch: movesBranch ?? state.movesBranch,
                branchName: branchName ?? state.branchName,
                newBranchName: newBranchName ?? state.newBranchName,
                startPoint: startPoint ?? state.startPoint
            )
        )
    }
}

/// A fluent wrapper for `git stash`.
///
/// Use ``GitStash`` when automation needs to save, restore, inspect, or delete working-tree
/// changes. This example creates a named stash and includes untracked files; on success, git's
/// confirmation text is available in ``ShellOutput/stdout``.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .stash()
///     .push()                 // Select `git stash push`.
///     .message("checkpoint")    // Label the stash entry.
///     .includeUntracked()     // Also stash untracked files.
///     .run()
///
/// print(output.stdout)
/// ```
public struct GitStash: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git stash` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git stash` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that selects `git stash push`.
    ///
    /// Saves the current working tree state to a new stash entry. Pair with ``message(_:)`` to
    /// label the entry and ``includeUntracked(_:)`` to also stash untracked files.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash push`.
    public func push() -> Self {
        copy(subcommand: .push)
    }

    /// Returns a copy that selects `git stash pop`.
    ///
    /// Applies the most recent (or referenced via ``reference(_:)``) stash entry and removes it
    /// from the stash list.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash pop`.
    public func pop() -> Self {
        copy(subcommand: .pop)
    }

    /// Returns a copy that selects `git stash apply`.
    ///
    /// Applies a stash entry without removing it from the stash list. Use ``pop()`` to apply
    /// and remove in one step.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash apply`.
    public func apply() -> Self {
        copy(subcommand: .apply)
    }

    /// Returns a copy that selects `git stash list`.
    ///
    /// Lists all stash entries. Inspect ``ShellOutput/stdout`` for the result.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash list`.
    public func list() -> Self {
        copy(subcommand: .list)
    }

    /// Returns a copy that selects `git stash show`.
    ///
    /// Inspects a stash entry without applying it. Combine with ``reference(_:)`` to target a
    /// specific entry.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash show`.
    public func show() -> Self {
        copy(subcommand: .show)
    }

    /// Returns a copy that selects `git stash drop`.
    ///
    /// Discards a single stash entry. Use ``clear()`` to discard every entry.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash drop`.
    public func drop() -> Self {
        copy(subcommand: .drop)
    }

    /// Returns a copy that selects `git stash drop`.
    ///
    /// Alias for ``drop()`` that reads more naturally when the calling code uses a generic
    /// "delete" vocabulary.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash drop`.
    public func delete() -> Self {
        drop()
    }

    /// Returns a copy that selects `git stash clear`.
    ///
    /// Removes every entry from the stash list. Cannot be undone.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash clear`.
    public func clear() -> Self {
        copy(subcommand: .clear)
    }

    /// Returns a copy that selects `git stash branch <name>`.
    ///
    /// Creates a new branch named `name` starting from the commit at which the stash was
    /// created, applies the stash to it, and drops the stash.
    ///
    /// - Parameter name: The branch to create.
    /// - Returns: A new ``GitStash`` value configured to run `git stash branch`.
    public func branch(_ name: String) -> Self {
        copy(subcommand: .branch, branchName: name)
    }

    /// Returns a copy that selects `git stash create`.
    ///
    /// Creates a stash entry and writes its commit hash to stdout, but does not store it in
    /// the stash list. Useful for scripted snapshots.
    ///
    /// - Returns: A new ``GitStash`` value configured to run `git stash create`.
    public func create() -> Self {
        copy(subcommand: .create)
    }

    /// Returns a copy that includes untracked files when pushing a stash.
    ///
    /// Maps to the `--include-untracked` flag.
    ///
    /// - Parameter enabled: `true` to add `--include-untracked`; `false` to omit it. Defaults to
    ///   `true`.
    /// - Returns: A new ``GitStash`` value with the flag applied.
    public func includeUntracked(_ enabled: Bool = true) -> Self {
        copy(includesUntracked: enabled)
    }

    /// Returns a copy that sets the stash message used by `git stash push`.
    ///
    /// Maps to the `-m <message>` flag.
    ///
    /// - Parameter value: The stash message.
    /// - Returns: A new ``GitStash`` value with the message applied.
    public func message(_ value: String) -> Self {
        copy(message: value)
    }

    /// Returns a copy that targets a specific stash entry by reference.
    ///
    /// Forwarded as a positional argument so it works with ``apply()``, ``pop()``, ``show()``,
    /// and ``drop()`` (e.g. `"stash@{1}"`).
    ///
    /// - Parameter value: The stash reference.
    /// - Returns: A new ``GitStash`` value with the reference applied.
    public func reference(_ value: String) -> Self {
        copy(reference: value)
    }

    /// Builds the raw `git stash` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["stash"]

        if let subcommand = state.subcommand {
            arguments.append(subcommand.rawValue)
        }
        if let branchName = state.branchName {
            arguments.append(branchName)
        }
        if state.includesUntracked {
            arguments.append("--include-untracked")
        }
        if let message = state.message {
            arguments.append(contentsOf: ["-m", message])
        }
        if let reference = state.reference {
            arguments.append(reference)
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: Subcommand?? = nil,
        branchName: String?? = nil,
        includesUntracked: Bool? = nil,
        message: String?? = nil,
        reference: String?? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                branchName: branchName ?? state.branchName,
                includesUntracked: includesUntracked ?? state.includesUntracked,
                message: message ?? state.message,
                reference: reference ?? state.reference
            )
        )
    }
}

/// A fluent wrapper for `git worktree`.
///
/// Use ``GitWorktree`` to list, add, or remove linked worktrees. This example runs
/// `git worktree list` and leaves git's tabular output in ``ShellOutput/stdout``.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .worktree()
///     .list()    // Select `git worktree list`.
///     .run()
///
/// print(output.stdout)
/// ```
public struct GitWorktree: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git worktree` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git worktree` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that selects `git worktree list`.
    ///
    /// Lists every linked worktree along with its branch and HEAD commit.
    ///
    /// - Returns: A new ``GitWorktree`` value configured to run `git worktree list`.
    public func list() -> Self {
        copy(subcommand: .list)
    }

    /// Returns a copy that selects `git worktree add <path>`.
    ///
    /// Adds a new linked worktree at `path`. Use ``branch(_:)`` to create the worktree from a
    /// new branch.
    ///
    /// - Parameter path: The filesystem path for the new worktree.
    /// - Returns: A new ``GitWorktree`` value configured to run `git worktree add`.
    public func add(_ path: String) -> Self {
        copy(subcommand: .add, path: path)
    }

    /// Returns a copy that selects `git worktree remove <path>`.
    ///
    /// Removes the linked worktree rooted at `path`. The worktree must be clean unless git's
    /// `--force` is added separately via the configuration helpers.
    ///
    /// - Parameter path: The filesystem path of the worktree to remove.
    /// - Returns: A new ``GitWorktree`` value configured to run `git worktree remove`.
    public func remove(_ path: String) -> Self {
        copy(subcommand: .remove, path: path)
    }

    /// Returns a copy that sets the new branch used by `git worktree add`.
    ///
    /// Maps to the `-b <value>` flag, instructing git to create the named branch when adding
    /// the worktree.
    ///
    /// - Parameter value: The branch name to create.
    /// - Returns: A new ``GitWorktree`` value with the branch applied.
    public func branch(_ value: String) -> Self {
        copy(branch: value)
    }

    /// Builds the raw `git worktree` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["worktree"]
        if let subcommand = state.subcommand {
            arguments.append(subcommand.rawValue)
        }
        if let branch = state.branch {
            arguments.append(contentsOf: ["-b", branch])
        }
        if let path = state.path {
            arguments.append(path)
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: Subcommand?? = nil,
        path: String?? = nil,
        branch: String?? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                path: path ?? state.path,
                branch: branch ?? state.branch
            )
        )
    }
}

/// A fluent wrapper for `git diff`.
///
/// Use ``GitDiff`` for raw diff output, stats, or name/status summaries. This example returns a
/// compact list of changed paths and status codes in ``ShellOutput/stdout``; use
/// ``GitDiff/fileChanges()`` when you want parsed ``GitDiffFileChange`` values instead.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .diff()
///     .format(.nameStatus)    // Equivalent to `git diff --name-status`.
///     .run()
///
/// print(output.stdout)
/// ```
public struct GitDiff: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git diff` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git diff` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy with the diff output format applied.
    ///
    /// See ``GitDiffFormat`` for the supported choices. ``GitDiff/fileChanges()`` overrides
    /// this to ``GitDiffFormat/nameStatus`` internally.
    ///
    /// - Parameter value: The desired output format.
    /// - Returns: A new ``GitDiff`` value with the format applied.
    public func format(_ value: GitDiffFormat) -> Self {
        copy(format: value)
    }

    /// Returns a copy that diffs staged changes against `HEAD`.
    ///
    /// Maps to the `--staged` flag (an alias for `--cached`). Without this flag git diffs
    /// unstaged working-tree changes against the index.
    ///
    /// - Parameter enabled: `true` to add `--staged`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``GitDiff`` value with the flag applied.
    public func staged(_ enabled: Bool = true) -> Self {
        copy(staged: enabled)
    }

    /// Returns a copy that targets a specific commit, branch, or revision range.
    ///
    /// Forwarded to git as a positional argument (e.g. `"main..feature"` or `"HEAD~3"`).
    ///
    /// - Parameter value: The commit, branch, or revision range.
    /// - Returns: A new ``GitDiff`` value with the range applied.
    public func range(_ value: String) -> Self {
        copy(range: value)
    }

    /// Returns a copy with one additional path filter appended.
    ///
    /// Paths are appended after `--` so leading-dash arguments are unambiguous.
    ///
    /// - Parameter value: The path filter to append.
    /// - Returns: A new ``GitDiff`` value with the path appended.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Returns a copy with multiple path filters appended.
    ///
    /// Array form of ``path(_:)``.
    ///
    /// - Parameter values: The path filters to append, in order.
    /// - Returns: A new ``GitDiff`` value with the paths appended.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the raw `git diff` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["diff"]
        arguments.append(contentsOf: state.format.arguments)
        if state.staged {
            arguments.append("--staged")
        }
        if let range = state.range {
            arguments.append(range)
        }
        if !state.paths.isEmpty {
            arguments.append("--")
            arguments.append(contentsOf: state.paths)
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    /// Runs `git diff --name-status` and parses the output into typed file changes.
    ///
    /// Forces ``GitDiffFormat/nameStatus`` regardless of any prior ``format(_:)`` call so the
    /// parser can read git's status code plus path columns reliably.
    ///
    /// ```swift
    /// let changes = try await git.diff().staged().fileChanges().run()
    /// for change in changes where change.kind == .deleted {
    ///     print("Deleted:", change.path)
    /// }
    /// ```
    ///
    /// - Returns: A single-use ``Workflow`` producing parsed ``GitDiffFileChange`` values.
    public func fileChanges() -> Workflow<[GitDiffFileChange]> {
        let git = state.git
        let command = self.format(.nameStatus).command()
        return Workflow {
            let output = try await command.run(in: git.context)
            return GitParsers.parseDiffFileChanges(output.stdout)
        }
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        format: GitDiffFormat? = nil,
        staged: Bool? = nil,
        range: String?? = nil,
        paths: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                format: format ?? state.format,
                staged: staged ?? state.staged,
                range: range ?? state.range,
                paths: paths ?? state.paths
            )
        )
    }
}

/// A fluent wrapper for `git log`.
///
/// Use ``GitLog`` when you need commit history. This example returns the last ten commits in git's
/// one-line format as raw text; use ``GitLog/entries()`` when you need structured
/// ``GitLogEntry`` values.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .log()
///     .format(.oneline)    // Use abbreviated hash plus subject.
///     .maxCount(10)        // Limit to the latest ten commits.
///     .run()
///
/// print(output.stdout)
/// ```
public struct GitLog: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git log` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git log` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy with the log output format applied.
    ///
    /// See ``GitLogFormat`` for the supported choices. ``GitLog/entries()`` overrides this with
    /// a unit-separator-delimited pretty format internally.
    ///
    /// - Parameter value: The desired output format.
    /// - Returns: A new ``GitLog`` value with the format applied.
    public func format(_ value: GitLogFormat) -> Self {
        copy(format: value)
    }

    /// Returns a copy that limits the number of commits returned.
    ///
    /// Maps to `-n <value>`.
    ///
    /// - Parameter value: The maximum number of commits.
    /// - Returns: A new ``GitLog`` value with the limit applied.
    public func maxCount(_ value: Int) -> Self {
        copy(maxCount: value)
    }

    /// Returns a copy that targets a specific commit, branch, or revision range.
    ///
    /// Forwarded to git as a positional argument (e.g. `"main"`, `"v1.0..HEAD"`).
    ///
    /// - Parameter value: The commit, branch, or revision range.
    /// - Returns: A new ``GitLog`` value with the range applied.
    public func range(_ value: String) -> Self {
        copy(range: value)
    }

    /// Builds the raw `git log` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["log"]
        arguments.append(contentsOf: state.format.arguments)
        if let maxCount = state.maxCount {
            arguments.append("-n")
            arguments.append(String(maxCount))
        }
        if let range = state.range {
            arguments.append(range)
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    /// Runs `git log` with a parser-friendly format and returns typed commit entries.
    ///
    /// Forces a unit-separator-delimited pretty format
    /// (`%H%x1f%h%x1f%an%x1f%ae%x1f%s`) so the parser can recover the full hash, abbreviated
    /// hash, author name, author email, and subject without ambiguity.
    ///
    /// ```swift
    /// let commits = try await git.log().maxCount(5).entries().run()
    /// for commit in commits {
    ///     print(commit.abbreviatedCommitHash, commit.subject)
    /// }
    /// ```
    ///
    /// - Returns: A single-use ``Workflow`` producing parsed ``GitLogEntry`` values.
    public func entries() -> Workflow<[GitLogEntry]> {
        let git = state.git
        let command = self.format(.pretty("format:%H%x1f%h%x1f%an%x1f%ae%x1f%s")).command()
        return Workflow {
            let output = try await command.run(in: git.context)
            return GitParsers.parseLogEntries(output.stdout)
        }
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        format: GitLogFormat? = nil,
        maxCount: Int?? = nil,
        range: String?? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                format: format ?? state.format,
                maxCount: maxCount ?? state.maxCount,
                range: range ?? state.range
            )
        )
    }
}

/// A fluent wrapper for `git config`.
///
/// Use ``GitConfigCommand`` to read and write git configuration values. This example reads the
/// repository-local `user.name`; the value is returned as raw text in ``ShellOutput/stdout``.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .configuration()
///     .get("user.name")    // Select `git config --get user.name`.
///     .run()
///
/// let userName = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
/// ```
public struct GitConfigCommand: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git config` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git config` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that selects `git config --get <key>`.
    ///
    /// The value, if any, is written to ``ShellOutput/stdout``. Git exits non-zero (which
    /// surfaces as ``ShellError/exitFailure(command:output:)``) when the key is unset.
    ///
    /// - Parameter key: The fully-qualified config key (e.g. `"user.name"`).
    /// - Returns: A new ``GitConfigCommand`` configured to read the key.
    public func get(_ key: String) -> Self {
        copy(action: .get, key: key)
    }

    /// Returns a copy that selects `git config <key> <value>`.
    ///
    /// Sets the key to `value` at the chosen scope (defaults to repository-local).
    ///
    /// - Parameters:
    ///   - key: The config key to set.
    ///   - value: The new value.
    /// - Returns: A new ``GitConfigCommand`` configured to write the key.
    public func set(_ key: String, to value: String) -> Self {
        copy(action: .set, key: key, value: value)
    }

    /// Returns a copy that selects `git config --unset <key>`.
    ///
    /// - Parameter key: The config key to clear.
    /// - Returns: A new ``GitConfigCommand`` configured to unset the key.
    public func unset(_ key: String) -> Self {
        copy(action: .unset, key: key)
    }

    /// Returns a copy that selects `git config --list`.
    ///
    /// Lists every key/value pair visible at the chosen scope. Combine with ``format(_:)`` to
    /// switch to ``GitConfigFormat/showOrigin`` or ``GitConfigFormat/showScope``.
    ///
    /// - Returns: A new ``GitConfigCommand`` configured to list config entries.
    public func list() -> Self {
        copy(action: .list)
    }

    /// Returns a copy that targets the local repository config file.
    ///
    /// Maps to the `--local` flag. Mutually exclusive with ``global(_:)``; passing `false`
    /// clears any previous scope selection.
    ///
    /// - Parameter enabled: `true` to add `--local`; `false` to clear the scope. Defaults to
    ///   `true`.
    /// - Returns: A new ``GitConfigCommand`` value with the scope applied.
    public func local(_ enabled: Bool = true) -> Self {
        copy(scope: enabled ? .local : nil)
    }

    /// Returns a copy that targets the global user config file.
    ///
    /// Maps to the `--global` flag. Mutually exclusive with ``local(_:)``; passing `false`
    /// clears any previous scope selection.
    ///
    /// - Parameter enabled: `true` to add `--global`; `false` to clear the scope. Defaults to
    ///   `true`.
    /// - Returns: A new ``GitConfigCommand`` value with the scope applied.
    public func global(_ enabled: Bool = true) -> Self {
        copy(scope: enabled ? .global : nil)
    }

    /// Returns a copy with the listing output format applied.
    ///
    /// See ``GitConfigFormat`` for the supported choices.
    ///
    /// - Parameter value: The desired output format.
    /// - Returns: A new ``GitConfigCommand`` value with the format applied.
    public func format(_ value: GitConfigFormat) -> Self {
        copy(format: value)
    }

    /// Builds the raw `git config` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["config"]
        if let scope = state.scope {
            arguments.append(scope.rawValue)
        }
        arguments.append(contentsOf: state.format.arguments)

        switch state.action {
        case .get:
            arguments.append("--get")
        case .set:
            break
        case .unset:
            arguments.append("--unset")
        case .list:
            arguments.append("--list")
        }

        if let key = state.key {
            arguments.append(key)
        }
        if let value = state.value {
            arguments.append(value)
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        action: Action? = nil,
        scope: Scope?? = nil,
        format: GitConfigFormat? = nil,
        key: String?? = nil,
        value: String?? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                action: action ?? state.action,
                scope: scope ?? state.scope,
                format: format ?? state.format,
                key: key ?? state.key,
                value: value ?? state.value
            )
        )
    }
}

/// A fluent wrapper for `git merge`.
///
/// Use ``GitMerge`` to merge a branch or commit into the current branch. This example runs
/// `git merge feature`; if git reports a conflict or another non-zero exit, SwiftyShell throws
/// ``ShellError/exitFailure(command:output:)`` with git's diagnostics.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .merge()
///     .branch("feature")    // Merge the feature branch into the current branch.
///     .run()
///
/// print(output.stdout)
/// ```
public struct GitMerge: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git merge` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git merge` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that sets the branch or commit to merge.
    ///
    /// Forwarded to git as a positional argument (e.g. `"feature"`, `"origin/main"`).
    ///
    /// - Parameter value: The branch, tag, or commit to merge.
    /// - Returns: A new ``GitMerge`` value with the target applied.
    public func branch(_ value: String) -> Self {
        copy(branch: value)
    }

    /// Returns a copy that disables fast-forward merges.
    ///
    /// Maps to the `--no-ff` flag, which forces git to create a merge commit even when a
    /// fast-forward would be possible.
    ///
    /// - Parameter enabled: `true` to add `--no-ff`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``GitMerge`` value with the flag applied.
    public func noFastForward(_ enabled: Bool = true) -> Self {
        copy(noFastForward: enabled)
    }

    /// Builds the raw `git merge` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["merge"]
        if state.noFastForward {
            arguments.append("--no-ff")
        }
        if let branch = state.branch {
            arguments.append(branch)
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        branch: String?? = nil,
        noFastForward: Bool? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                branch: branch ?? state.branch,
                noFastForward: noFastForward ?? state.noFastForward
            )
        )
    }
}

/// A fluent wrapper for `git commit`.
///
/// Use ``GitCommit`` to create commits from staged changes or from all tracked changes. This
/// example maps to `git commit --all --message "Record update"`, so modified and deleted tracked
/// files are included without a separate `git add`.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .commit()
///     .message("Record update")    // Pass the commit message.
///     .all()                       // Include all tracked modifications/deletions.
///     .run()
///
/// print(output.stdout)
/// ```
public struct GitCommit: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git commit` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git commit` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that sets the commit message.
    ///
    /// Maps to the `-m <value>` flag.
    ///
    /// - Parameter value: The commit message.
    /// - Returns: A new ``GitCommit`` value with the message applied.
    public func message(_ value: String) -> Self {
        copy(message: value)
    }

    /// Returns a copy that stages tracked-file modifications and deletions before committing.
    ///
    /// Maps to the `--all` flag. Untracked files are not included — those still require an
    /// explicit `git add`.
    ///
    /// - Parameter enabled: `true` to add `--all`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``GitCommit`` value with the flag applied.
    public func all(_ enabled: Bool = true) -> Self {
        copy(commitsAllTrackedChanges: enabled)
    }

    /// Builds the raw `git commit` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["commit"]
        if state.commitsAllTrackedChanges {
            arguments.append("--all")
        }
        if let message = state.message {
            arguments.append(contentsOf: ["-m", message])
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        message: String?? = nil,
        commitsAllTrackedChanges: Bool? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                message: message ?? state.message,
                commitsAllTrackedChanges: commitsAllTrackedChanges ?? state.commitsAllTrackedChanges
            )
        )
    }
}

/// A fluent wrapper for `git rebase`.
///
/// Use ``GitRebase`` to replay the current branch onto another branch or commit. This example
/// runs `git rebase --onto main`; rebase conflicts surface as
/// ``ShellError/exitFailure(command:output:)`` with git's stderr attached.
///
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .rebase()
///     .onto("main")    // Rebase the current branch onto main.
///     .run()
///
/// print(output.stdout)
/// ```
public struct GitRebase: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``Git`` client so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Returns a copy that routes the built `git rebase` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `git rebase` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that sets the branch or commit to rebase onto.
    ///
    /// Forwarded as a positional argument (e.g. `"main"`, `"origin/main"`).
    ///
    /// - Parameter value: The target ref to rebase onto.
    /// - Returns: A new ``GitRebase`` value with the target applied.
    public func onto(_ value: String) -> Self {
        copy(target: value)
    }

    /// Returns a copy that selects `git rebase --continue`.
    ///
    /// Use after resolving rebase conflicts.
    ///
    /// - Returns: A new ``GitRebase`` value configured to continue an in-progress rebase.
    public func `continue`() -> Self {
        copy(mode: .continue)
    }

    /// Returns a copy that selects `git rebase --abort`.
    ///
    /// Cancels an in-progress rebase and restores the working tree to its prior state.
    ///
    /// - Returns: A new ``GitRebase`` value configured to abort an in-progress rebase.
    public func abort() -> Self {
        copy(mode: .abort)
    }

    /// Builds the raw `git rebase` command represented by the current builder state.
    ///
    /// The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["rebase"]

        switch state.mode {
        case .start:
            if let target = state.target {
                arguments.append(target)
            }
        case .continue:
            arguments.append("--continue")
        case .abort:
            arguments.append("--abort")
        }

        return state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        target: String?? = nil,
        mode: Mode? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                target: target ?? state.target,
                mode: mode ?? state.mode
            )
        )
    }
}

private extension GitBranch {
    init(state: State) {
        self.state = state
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let listsBranches: Bool
        let includesAllBranches: Bool
        let deletesBranch: Bool
        let forceDeletesBranch: Bool
        let movesBranch: Bool
        let branchName: String?
        let newBranchName: String?
        let startPoint: String?

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            listsBranches: Bool = false,
            includesAllBranches: Bool = false,
            deletesBranch: Bool = false,
            forceDeletesBranch: Bool = false,
            movesBranch: Bool = false,
            branchName: String? = nil,
            newBranchName: String? = nil,
            startPoint: String? = nil
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.listsBranches = listsBranches
            self.includesAllBranches = includesAllBranches
            self.deletesBranch = deletesBranch
            self.forceDeletesBranch = forceDeletesBranch
            self.movesBranch = movesBranch
            self.branchName = branchName
            self.newBranchName = newBranchName
            self.startPoint = startPoint
        }
    }
}

private extension GitStash {
    init(state: State) {
        self.state = state
    }

    enum Subcommand: String, Sendable {
        case push
        case pop
        case apply
        case list
        case show
        case drop
        case clear
        case branch
        case create
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let subcommand: Subcommand?
        let branchName: String?
        let includesUntracked: Bool
        let message: String?
        let reference: String?

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            subcommand: Subcommand? = nil,
            branchName: String? = nil,
            includesUntracked: Bool = false,
            message: String? = nil,
            reference: String? = nil
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.subcommand = subcommand
            self.branchName = branchName
            self.includesUntracked = includesUntracked
            self.message = message
            self.reference = reference
        }
    }
}

private extension GitWorktree {
    init(state: State) {
        self.state = state
    }

    enum Subcommand: String, Sendable {
        case list
        case add
        case remove
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let subcommand: Subcommand?
        let path: String?
        let branch: String?

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            subcommand: Subcommand? = nil,
            path: String? = nil,
            branch: String? = nil
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.subcommand = subcommand
            self.path = path
            self.branch = branch
        }
    }
}

private extension GitDiff {
    init(state: State) {
        self.state = state
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let format: GitDiffFormat
        let staged: Bool
        let range: String?
        let paths: [String]

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            format: GitDiffFormat = .patch,
            staged: Bool = false,
            range: String? = nil,
            paths: [String] = []
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.format = format
            self.staged = staged
            self.range = range
            self.paths = paths
        }
    }
}

private extension GitLog {
    init(state: State) {
        self.state = state
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let format: GitLogFormat
        let maxCount: Int?
        let range: String?

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            format: GitLogFormat = .medium,
            maxCount: Int? = nil,
            range: String? = nil
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.format = format
            self.maxCount = maxCount
            self.range = range
        }
    }
}

private extension GitConfigCommand {
    init(state: State) {
        self.state = state
    }

    enum Action: Sendable {
        case get
        case set
        case unset
        case list
    }

    enum Scope: String, Sendable {
        case local = "--local"
        case global = "--global"
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let action: Action
        let scope: Scope?
        let format: GitConfigFormat
        let key: String?
        let value: String?

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            action: Action = .list,
            scope: Scope? = nil,
            format: GitConfigFormat = .defaultFormat,
            key: String? = nil,
            value: String? = nil
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.action = action
            self.scope = scope
            self.format = format
            self.key = key
            self.value = value
        }
    }
}

private extension GitMerge {
    init(state: State) {
        self.state = state
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let branch: String?
        let noFastForward: Bool

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            branch: String? = nil,
            noFastForward: Bool = false
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.branch = branch
            self.noFastForward = noFastForward
        }
    }
}

private extension GitCommit {
    init(state: State) {
        self.state = state
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let message: String?
        let commitsAllTrackedChanges: Bool

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            message: String? = nil,
            commitsAllTrackedChanges: Bool = false
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.message = message
            self.commitsAllTrackedChanges = commitsAllTrackedChanges
        }
    }
}

private extension GitRebase {
    init(state: State) {
        self.state = state
    }

    enum Mode: Sendable {
        case start
        case `continue`
        case abort
    }

    struct State: Sendable {
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let target: String?
        let mode: Mode

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            target: String? = nil,
            mode: Mode = .start
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.target = target
            self.mode = mode
        }
    }
}
#endif
