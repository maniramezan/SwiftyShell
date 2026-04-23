#if Git
import Foundation

/// The output format used by ``GitDiff``.
public enum GitDiffFormat: Sendable, Equatable, Hashable {
    /// The standard patch format.
    case patch
    /// A compact summary of changed files.
    case stat
    /// A list of changed file paths.
    case nameOnly
    /// A list of changed files with status letters.
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
public enum GitLogFormat: Sendable, Equatable, Hashable {
    /// Git's default multi-line commit format.
    case medium
    /// A single-line summary per commit.
    case oneline
    /// A short commit format.
    case short
    /// A user-provided pretty format string.
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
public enum GitConfigFormat: Sendable, Equatable, Hashable {
    /// Standard `key=value` output.
    case defaultFormat
    /// Null-delimited `key\0value\0` output.
    case nullTerminated
    /// Show each config value with its origin file.
    case showOrigin
    /// Show each config value with its scope.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .branch()
///     .list()
///     .all()
///     .run()
/// ```
public struct GitBranch: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git branch` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git branch` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Lists branches instead of creating one.
    public func list(_ enabled: Bool = true) -> Self {
        copy(listsBranches: enabled)
    }

    /// Includes remote branches when listing.
    public func all(_ enabled: Bool = true) -> Self {
        copy(includesAllBranches: enabled)
    }

    /// Deletes the named branch.
    public func delete(_ name: String) -> Self {
        copy(deletesBranch: true, forceDeletesBranch: false, branchName: name)
    }

    /// Force-deletes the named branch.
    public func forceDelete(_ name: String) -> Self {
        copy(deletesBranch: false, forceDeletesBranch: true, branchName: name)
    }

    /// Sets the branch name for create, move, or delete operations.
    public func named(_ name: String) -> Self {
        copy(branchName: name)
    }

    /// Sets the start point used when creating a branch.
    public func startPoint(_ value: String) -> Self {
        copy(startPoint: value)
    }

    /// Renames the current branch or the named branch.
    public func move(to newName: String) -> Self {
        copy(movesBranch: true, newBranchName: newName)
    }

    /// Builds the raw `git branch` command.
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

    /// Runs `git branch` and parses the output into typed branch entries.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .stash()
///     .push()
///     .message("checkpoint")
///     .includeUntracked()
///     .run()
/// ```
public struct GitStash: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git stash` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git stash` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Selects `git stash push`.
    public func push() -> Self {
        copy(subcommand: .push)
    }

    /// Selects `git stash pop`.
    public func pop() -> Self {
        copy(subcommand: .pop)
    }

    /// Selects `git stash apply`.
    public func apply() -> Self {
        copy(subcommand: .apply)
    }

    /// Selects `git stash list`.
    public func list() -> Self {
        copy(subcommand: .list)
    }

    /// Selects `git stash show` to inspect a stash without applying it.
    public func show() -> Self {
        copy(subcommand: .show)
    }

    /// Selects `git stash drop`.
    public func drop() -> Self {
        copy(subcommand: .drop)
    }

    /// Selects `git stash drop`.
    ///
    /// This is an alias for ``drop()`` to match the more general delete wording.
    public func delete() -> Self {
        drop()
    }

    /// Selects `git stash clear`.
    public func clear() -> Self {
        copy(subcommand: .clear)
    }

    /// Selects `git stash branch <name>`.
    public func branch(_ name: String) -> Self {
        copy(subcommand: .branch, branchName: name)
    }

    /// Selects `git stash create`.
    public func create() -> Self {
        copy(subcommand: .create)
    }

    /// Includes untracked files when pushing a stash.
    public func includeUntracked(_ enabled: Bool = true) -> Self {
        copy(includesUntracked: enabled)
    }

    /// Sets the stash message used by `git stash push`.
    public func message(_ value: String) -> Self {
        copy(message: value)
    }

    /// Selects a stash reference such as `stash@{0}`.
    public func reference(_ value: String) -> Self {
        copy(reference: value)
    }

    /// Builds the raw `git stash` command.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .worktree()
///     .list()
///     .run()
/// ```
public struct GitWorktree: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git worktree` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git worktree` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Selects `git worktree list`.
    public func list() -> Self {
        copy(subcommand: .list)
    }

    /// Selects `git worktree add <path>`.
    public func add(_ path: String) -> Self {
        copy(subcommand: .add, path: path)
    }

    /// Selects `git worktree remove <path>`.
    public func remove(_ path: String) -> Self {
        copy(subcommand: .remove, path: path)
    }

    /// Sets the branch used by `git worktree add`.
    public func branch(_ value: String) -> Self {
        copy(branch: value)
    }

    /// Builds the raw `git worktree` command.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .diff()
///     .format(.nameStatus)
///     .run()
/// ```
public struct GitDiff: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git diff` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git diff` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Chooses the diff output format.
    public func format(_ value: GitDiffFormat) -> Self {
        copy(format: value)
    }

    /// Diffs staged changes against `HEAD`.
    public func staged(_ enabled: Bool = true) -> Self {
        copy(staged: enabled)
    }

    /// Sets the commit, branch, or revision range to diff.
    public func range(_ value: String) -> Self {
        copy(range: value)
    }

    /// Limits the diff to a single path.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Limits the diff to multiple paths.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the raw `git diff` command.
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

    /// Runs `git diff --name-status` and parses the changed files.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .log()
///     .format(.oneline)
///     .maxCount(10)
///     .run()
/// ```
public struct GitLog: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git log` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git log` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Chooses the log output format.
    public func format(_ value: GitLogFormat) -> Self {
        copy(format: value)
    }

    /// Limits the number of commits returned.
    public func maxCount(_ value: Int) -> Self {
        copy(maxCount: value)
    }

    /// Sets the commit, branch, or revision range to inspect.
    public func range(_ value: String) -> Self {
        copy(range: value)
    }

    /// Builds the raw `git log` command.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .configuration()
///     .get("user.name")
///     .run()
/// ```
public struct GitConfigCommand: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git config` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git config` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Selects `git config --get <key>`.
    public func get(_ key: String) -> Self {
        copy(action: .get, key: key)
    }

    /// Selects `git config <key> <value>`.
    public func set(_ key: String, to value: String) -> Self {
        copy(action: .set, key: key, value: value)
    }

    /// Selects `git config --unset <key>`.
    public func unset(_ key: String) -> Self {
        copy(action: .unset, key: key)
    }

    /// Selects `git config --list`.
    public func list() -> Self {
        copy(action: .list)
    }

    /// Targets the local repository config file.
    public func local(_ enabled: Bool = true) -> Self {
        copy(scope: enabled ? .local : nil)
    }

    /// Targets the global user config file.
    public func global(_ enabled: Bool = true) -> Self {
        copy(scope: enabled ? .global : nil)
    }

    /// Chooses the listing output format.
    public func format(_ value: GitConfigFormat) -> Self {
        copy(format: value)
    }

    /// Builds the raw `git config` command.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .merge()
///     .branch("feature")
///     .run()
/// ```
public struct GitMerge: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git merge` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git merge` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Sets the branch or commit to merge.
    public func branch(_ value: String) -> Self {
        copy(branch: value)
    }

    /// Disables fast-forward merges.
    public func noFastForward(_ enabled: Bool = true) -> Self {
        copy(noFastForward: enabled)
    }

    /// Builds the raw `git merge` command.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .commit()
///     .message("Record update")
///     .all()
///     .run()
/// ```
public struct GitCommit: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git commit` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git commit` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Sets the commit message.
    public func message(_ value: String) -> Self {
        copy(message: value)
    }

    /// Stages tracked-file modifications before committing.
    public func all(_ enabled: Bool = true) -> Self {
        copy(commitsAllTrackedChanges: enabled)
    }

    /// Builds the raw `git commit` command.
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
/// ```swift
/// let output = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .rebase()
///     .onto("main")
///     .run()
/// ```
public struct GitRebase: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.git.context }

    init(git: Git) {
        self.state = State(git: git)
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(git: state.git.updatingConfiguration(update))
    }

    /// Redirects stdout for the built `git rebase` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git rebase` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Sets the branch or commit to rebase onto.
    public func onto(_ value: String) -> Self {
        copy(target: value)
    }

    /// Selects `git rebase --continue`.
    public func `continue`() -> Self {
        copy(mode: .continue)
    }

    /// Selects `git rebase --abort`.
    public func abort() -> Self {
        copy(mode: .abort)
    }

    /// Builds the raw `git rebase` command.
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
