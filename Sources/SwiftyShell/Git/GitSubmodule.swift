#if Git
import Foundation

/// The update strategy used by ``GitSubmodule`` when running `git submodule update`.
///
/// Selects which `--checkout`/`--rebase`/`--merge` flag is added to the command. Use
/// ``GitSubmodule/updateStrategy(_:)`` to apply a value.
public enum GitSubmoduleUpdateStrategy: Sendable, Equatable, Hashable {
    /// Checks out the commit recorded by the superproject (`--checkout`).
    ///
    /// Usually leaves the submodule in detached `HEAD`. This is git's default strategy.
    case checkout

    /// Rebases the current submodule branch onto the commit recorded by the superproject (`--rebase`).
    case rebase

    /// Merges the commit recorded by the superproject into the current submodule branch (`--merge`).
    case merge

    fileprivate var arguments: [String] {
        switch self {
        case .checkout:
            return ["--checkout"]
        case .rebase:
            return ["--rebase"]
        case .merge:
            return ["--merge"]
        }
    }
}

/// A fluent wrapper for `git submodule`.
///
/// Use ``Git/submodule()`` to add, initialize, update, inspect, and synchronize submodules.
///
/// To inspect submodule state, use ``statusEntries()`` instead of parsing stdout. It runs
/// `git submodule status`, converts each output line into ``GitSubmoduleStatusEntry``, and maps
/// git's leading status marker into ``GitSubmoduleStatusState``. Add ``recursive(_:)`` when nested
/// submodules should be included too.
///
/// ```swift
/// let entries = try await Git(context: context)
///     .workingDirectory(repoPath)
///     .submodule()
///     .recursive()        // Include submodules inside submodules.
///     .statusEntries()    // Parse `git submodule status` into Swift values.
///     .run()
/// ```
///
/// `entries` contains one value per submodule path. For example, `.uninitialized` means the
/// submodule working directory has not been created yet, while `.outOfSync` means the checked-out
/// commit differs from the commit recorded by the superproject.
///
/// To bootstrap submodules after cloning a repository, combine ``update()``,
/// ``initializeOnUpdate(_:)``, and ``recursive(_:)``. This maps to
/// `git submodule update --init --recursive`: it initializes missing submodule working directories,
/// checks them out at the commits recorded by the superproject, and repeats that for nested
/// submodules.
///
/// ```swift
/// try await Git(context: context)
///     .workingDirectory(repoPath)
///     .submodule()
///     .update()                // Select `git submodule update`.
///     .initializeOnUpdate()    // Add `--init` for missing submodules.
///     .recursive()             // Add `--recursive` for nested submodules.
///     .run()
/// ```
///
/// On success, the submodule directories exist and are checked out to the revisions referenced by
/// the current superproject commit.
public struct GitSubmodule: RunnableCommandFamily {
    private var state: State

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
    /// ``workingDirectory(_:)``, ``timeout(_:)-(Duration)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``GitSubmodule`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.git = state.git.updatingConfiguration(update) }
    }

    /// Returns a copy that routes the built `git submodule` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``GitSubmodule`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `git submodule` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``GitSubmodule`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Selects `git submodule add <repository> [path]` to register a new submodule.
    ///
    /// Pair with ``branch(_:)``, ``name(_:)``, ``reference(_:)``, ``depth(_:)``, ``force(_:)``,
    /// or ``progress(_:)`` to control how git clones the submodule.
    ///
    /// - Parameters:
    ///   - repository: The URL of the repository to add as a submodule.
    ///   - path: Optional path under the superproject where the submodule should live. When `nil`,
    ///     git derives the path from the repository name.
    /// - Returns: A new ``GitSubmodule`` value targeting the `add` subcommand.
    public func add(_ repository: String, path: String? = nil) -> Self {
        modified(self) {
            $0.state.subcommand = .add
            $0.state.repository = repository
            $0.state.paths = path.map { [$0] } ?? []
        }
    }

    /// Selects `git submodule status` to report the current state of each submodule.
    ///
    /// Combine with ``recursive(_:)``, ``cached(_:)``, or ``path(_:)`` to scope the output. When
    /// you want typed results instead of raw stdout, prefer ``statusEntries()``.
    ///
    /// - Returns: A new ``GitSubmodule`` value targeting the `status` subcommand.
    public func status() -> Self {
        modified(self) { $0.state.subcommand = .status }
    }

    /// Selects `git submodule init` to register submodules in `.git/config` without cloning them.
    ///
    /// Use this when you want to inspect or modify submodule configuration before running
    /// ``update()``. Most callers should prefer ``update()`` with ``initializeOnUpdate(_:)`` instead.
    ///
    /// - Returns: A new ``GitSubmodule`` value targeting the `init` subcommand.
    public func initialize() -> Self {
        modified(self) { $0.state.subcommand = .initialize }
    }

    /// Selects `git submodule deinit` to unregister submodules and remove their working trees.
    ///
    /// Combine with ``all(_:)`` to apply to every submodule, or with ``path(_:)`` / ``paths(_:)``
    /// to target specific entries. Use ``force(_:)`` when local modifications would otherwise
    /// block the operation.
    ///
    /// - Returns: A new ``GitSubmodule`` value targeting the `deinit` subcommand.
    public func deinitialize() -> Self {
        modified(self) { $0.state.subcommand = .deinitialize }
    }

    /// Selects `git submodule update` to check out the commit recorded by the superproject.
    ///
    /// Layer on ``initializeOnUpdate(_:)``, ``recursive(_:)``, ``remote(_:)``,
    /// ``updateStrategy(_:)``, ``jobs(_:)``, ``depth(_:)``, ``singleBranch(_:)``, or
    /// ``recommendShallow(_:)`` to shape the update.
    ///
    /// - Returns: A new ``GitSubmodule`` value targeting the `update` subcommand.
    public func update() -> Self {
        modified(self) { $0.state.subcommand = .update }
    }

    /// Selects `git submodule set-branch --branch <branch> -- <path>` to record a tracking branch.
    ///
    /// Updates `.gitmodules` so future ``update()`` calls with ``remote(_:)`` follow the named
    /// branch on the submodule's remote. Use ``resetBranch(path:)`` to clear the override.
    ///
    /// - Parameters:
    ///   - branch: The branch name to record for the submodule.
    ///   - path: Path of the submodule whose tracking branch should be updated.
    /// - Returns: A new ``GitSubmodule`` value targeting `set-branch` with `--branch`.
    public func setBranch(_ branch: String, path: String) -> Self {
        modified(self) {
            $0.state.subcommand = .setBranch
            $0.state.branch = branch
            $0.state.usesDefaultBranch = false
            $0.state.paths = [path]
        }
    }

    /// Selects `git submodule set-branch --default -- <path>` to clear a recorded tracking branch.
    ///
    /// Reverts the submodule to the default tracking behavior (typically the upstream `HEAD`).
    ///
    /// - Parameter path: Path of the submodule whose tracking branch should be reset.
    /// - Returns: A new ``GitSubmodule`` value targeting `set-branch` with `--default`.
    public func resetBranch(path: String) -> Self {
        modified(self) {
            $0.state.subcommand = .setBranch
            $0.state.branch = nil
            $0.state.usesDefaultBranch = true
            $0.state.paths = [path]
        }
    }

    /// Selects `git submodule set-url -- <path> <newurl>` to update the remote URL of a submodule.
    ///
    /// Rewrites the URL stored in `.gitmodules` so future clones and fetches use `newURL`.
    ///
    /// - Parameters:
    ///   - path: Path of the submodule whose URL should be updated.
    ///   - newURL: The replacement URL for the submodule's remote.
    /// - Returns: A new ``GitSubmodule`` value targeting the `set-url` subcommand.
    public func setUrl(path: String, to newURL: String) -> Self {
        modified(self) {
            $0.state.subcommand = .setURL
            $0.state.newURL = newURL
            $0.state.paths = [path]
        }
    }

    /// Selects `git submodule summary` to show a diff between superproject and submodule commits.
    ///
    /// Combine with ``cached(_:)``, ``files(_:)``, ``summaryLimit(_:)``, or ``summaryCommit(_:)``
    /// to scope the output.
    ///
    /// - Returns: A new ``GitSubmodule`` value targeting the `summary` subcommand.
    public func summary() -> Self {
        modified(self) { $0.state.subcommand = .summary }
    }

    /// Selects `git submodule foreach <command>` to run a shell command in each submodule.
    ///
    /// Pair with ``recursive(_:)`` to descend into nested submodules. The command runs in a shell
    /// inside each submodule's working directory.
    ///
    /// - Parameter command: The shell command to execute inside every submodule.
    /// - Returns: A new ``GitSubmodule`` value targeting the `foreach` subcommand.
    public func foreach(_ command: String) -> Self {
        modified(self) {
            $0.state.subcommand = .foreach
            $0.state.foreachCommand = command
        }
    }

    /// Selects `git submodule sync` to align recorded URLs with `.gitmodules`.
    ///
    /// Useful after ``setUrl(path:to:)`` has rewritten URLs and submodules need their remotes
    /// updated. Pair with ``recursive(_:)`` to reach nested submodules.
    ///
    /// - Returns: A new ``GitSubmodule`` value targeting the `sync` subcommand.
    public func sync() -> Self {
        modified(self) { $0.state.subcommand = .sync }
    }

    /// Selects `git submodule absorbgitdirs` to move embedded `.git` directories into the superproject.
    ///
    /// Migrates legacy submodules that store their git metadata inline so they share the
    /// superproject's `.git/modules/<name>` layout instead.
    ///
    /// - Returns: A new ``GitSubmodule`` value targeting the `absorbgitdirs` subcommand.
    public func absorbGitDirectories() -> Self {
        modified(self) { $0.state.subcommand = .absorbGitDirectories }
    }

    /// Suppresses non-error output where supported by `git submodule`.
    ///
    /// Maps to the `--quiet` flag. Useful in scripts where only failures should surface on stderr.
    ///
    /// - Parameter enabled: When `true`, adds `--quiet`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the quiet flag toggled.
    public func quiet(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.quiet = enabled }
    }

    /// Compares against the index instead of `HEAD` for `status` or `summary`.
    ///
    /// Maps to the `--cached` flag.
    ///
    /// - Parameter enabled: When `true`, adds `--cached`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the cached flag toggled.
    public func cached(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.cached = enabled }
    }

    /// Traverses nested submodules for commands that support recursive operation.
    ///
    /// Maps to the `--recursive` flag. Recognized by `status`, `update`, `foreach`, and `sync`.
    ///
    /// - Parameter enabled: When `true`, adds `--recursive`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the recursive flag toggled.
    public func recursive(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.recursive = enabled }
    }

    /// Forces `add`, `deinit`, or `update` to proceed where git would otherwise stop.
    ///
    /// Maps to the `--force` flag. Use with care — this can discard local changes inside
    /// submodules.
    ///
    /// - Parameter enabled: When `true`, adds `--force`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the force flag toggled.
    public func force(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.force = enabled }
    }

    /// Reports progress from `add` or `update` even when stderr is not attached to a terminal.
    ///
    /// Maps to the `--progress` flag. Helpful in CI logs where progress would otherwise be
    /// suppressed.
    ///
    /// - Parameter enabled: When `true`, adds `--progress`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the progress flag toggled.
    public func progress(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.progress = enabled }
    }

    /// Applies `deinit` to every registered submodule.
    ///
    /// Maps to the `--all` flag. When enabled, any explicit pathspec set via ``path(_:)`` /
    /// ``paths(_:)`` is omitted because git rejects mixing `--all` with paths.
    ///
    /// - Parameter enabled: When `true`, adds `--all`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the all flag toggled.
    public func all(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.all = enabled }
    }

    /// Sets the branch used by `add` or `set-branch`.
    ///
    /// Maps to the `--branch <value>` option. For `set-branch`, also clears the `--default` flag
    /// so the command takes a concrete branch instead of resetting to the default.
    ///
    /// - Parameter value: The branch name to record or check out.
    /// - Returns: A new ``GitSubmodule`` value with the branch option applied.
    public func branch(_ value: String) -> Self {
        modified(self) {
            $0.state.branch = value
            $0.state.usesDefaultBranch = false
        }
    }

    /// Sets the logical name used by `add`.
    ///
    /// Maps to the `--name <value>` option. Controls the entry name written to `.gitmodules`,
    /// which is otherwise derived from the path.
    ///
    /// - Parameter value: The submodule name to record.
    /// - Returns: A new ``GitSubmodule`` value with the name option applied.
    public func name(_ value: String) -> Self {
        modified(self) { $0.state.name = value }
    }

    /// Sets the reference repository used by `add` or `update`.
    ///
    /// Maps to the `--reference <repository>` option, which lets git borrow objects from a local
    /// alternate to speed up cloning.
    ///
    /// - Parameter repository: Path or URL of the reference repository to borrow from.
    /// - Returns: A new ``GitSubmodule`` value with the reference option applied.
    public func reference(_ repository: String) -> Self {
        modified(self) { $0.state.reference = repository }
    }

    /// Stops borrowing objects from a reference repository after cloning.
    ///
    /// Maps to the `--dissociate` flag. Typically paired with ``reference(_:)`` so the resulting
    /// submodule clone is self-contained.
    ///
    /// - Parameter enabled: When `true`, adds `--dissociate`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the dissociate flag toggled.
    public func dissociate(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.dissociate = enabled }
    }

    /// Sets the ref storage format used when cloning submodules.
    ///
    /// Maps to the `--ref-format <value>` option (e.g. `files`, `reftable`).
    ///
    /// - Parameter value: The ref storage format to request from `git clone`.
    /// - Returns: A new ``GitSubmodule`` value with the ref format option applied.
    public func refFormat(_ value: String) -> Self {
        modified(self) { $0.state.refFormat = value }
    }

    /// Sets the shallow clone depth used by `add` or `update`.
    ///
    /// Maps to the `--depth <value>` option. A smaller depth produces a smaller clone but limits
    /// available history.
    ///
    /// - Parameter value: Number of commits of history to fetch.
    /// - Returns: A new ``GitSubmodule`` value with the depth option applied.
    public func depth(_ value: Int) -> Self {
        modified(self) { $0.state.depth = value }
    }

    /// Initializes missing submodules before running `git submodule update`.
    ///
    /// Maps to the `--init` flag. Combine with ``recursive(_:)`` to bootstrap nested submodules
    /// after a fresh clone.
    ///
    /// - Parameter enabled: When `true`, adds `--init`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the init-on-update flag toggled.
    public func initializeOnUpdate(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.initializesOnUpdate = enabled }
    }

    /// Uses the submodule's remote-tracking branch when running `git submodule update`.
    ///
    /// Maps to the `--remote` flag. Together with ``setBranch(_:path:)`` this advances submodules
    /// past the commit recorded in the superproject.
    ///
    /// - Parameter enabled: When `true`, adds `--remote`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the remote flag toggled.
    public func remote(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.remote = enabled }
    }

    /// Skips fetching from submodule remotes when running `git submodule update --remote`.
    ///
    /// Maps to the `--no-fetch` flag. Useful when the local clone is already up to date or when
    /// network access is unavailable.
    ///
    /// - Parameter enabled: When `true`, adds `--no-fetch`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the no-fetch flag toggled.
    public func noFetch(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.noFetch = enabled }
    }

    /// Sets the checkout strategy used by `git submodule update`.
    ///
    /// Maps to one of `--checkout`, `--rebase`, or `--merge` based on the supplied
    /// ``GitSubmoduleUpdateStrategy``.
    ///
    /// - Parameter value: The strategy git should apply when updating each submodule.
    /// - Returns: A new ``GitSubmodule`` value with the update strategy applied.
    public func updateStrategy(_ value: GitSubmoduleUpdateStrategy) -> Self {
        modified(self) { $0.state.updateStrategy = value }
    }

    /// Limits parallel submodule clone jobs when running `git submodule update`.
    ///
    /// Maps to the `--jobs <value>` option.
    ///
    /// - Parameter value: Maximum number of concurrent clone or fetch jobs.
    /// - Returns: A new ``GitSubmodule`` value with the jobs option applied.
    public func jobs(_ value: Int) -> Self {
        modified(self) { $0.state.jobs = value }
    }

    /// Clones only one branch when running `git submodule update`.
    ///
    /// Maps to the `--single-branch` flag. Mutually exclusive with ``noSingleBranch(_:)`` —
    /// enabling one clears the other.
    ///
    /// - Parameter enabled: When `true`, adds `--single-branch`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the single-branch flag toggled.
    public func singleBranch(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.singleBranch = enabled
            $0.state.noSingleBranch = enabled ? false : state.noSingleBranch
        }
    }

    /// Allows cloning more than one branch when running `git submodule update`.
    ///
    /// Maps to the `--no-single-branch` flag. Mutually exclusive with ``singleBranch(_:)`` —
    /// enabling one clears the other.
    ///
    /// - Parameter enabled: When `true`, adds `--no-single-branch`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the no-single-branch flag toggled.
    public func noSingleBranch(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.singleBranch = enabled ? false : state.singleBranch
            $0.state.noSingleBranch = enabled
        }
    }

    /// Honors `.gitmodules` shallow-clone recommendations when updating submodules.
    ///
    /// Maps to the `--recommend-shallow` flag. Mutually exclusive with
    /// ``noRecommendShallow(_:)`` — enabling one clears the other.
    ///
    /// - Parameter enabled: When `true`, adds `--recommend-shallow`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the recommend-shallow flag toggled.
    public func recommendShallow(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.recommendShallow = enabled
            $0.state.noRecommendShallow = enabled ? false : state.noRecommendShallow
        }
    }

    /// Ignores `.gitmodules` shallow-clone recommendations when updating submodules.
    ///
    /// Maps to the `--no-recommend-shallow` flag. Mutually exclusive with
    /// ``recommendShallow(_:)`` — enabling one clears the other.
    ///
    /// - Parameter enabled: When `true`, adds `--no-recommend-shallow`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the no-recommend-shallow flag toggled.
    public func noRecommendShallow(_ enabled: Bool = true) -> Self {
        modified(self) {
            $0.state.recommendShallow = enabled ? false : state.recommendShallow
            $0.state.noRecommendShallow = enabled
        }
    }

    /// Applies a partial clone filter when running `git submodule update`.
    ///
    /// Maps to the `--filter <value>` option (e.g. `blob:none` or `tree:0`).
    ///
    /// - Parameter value: The partial-clone filter spec to forward to git.
    /// - Returns: A new ``GitSubmodule`` value with the filter option applied.
    public func filter(_ value: String) -> Self {
        modified(self) { $0.state.filter = value }
    }

    /// Compares the superproject index to the submodule working tree when running `summary`.
    ///
    /// Maps to the `--files` flag. Without this flag, `summary` compares against the commit
    /// recorded in the superproject.
    ///
    /// - Parameter enabled: When `true`, adds `--files`. Defaults to `true`.
    /// - Returns: A new ``GitSubmodule`` value with the files flag toggled.
    public func files(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.files = enabled }
    }

    /// Sets the total commit limit shown by `git submodule summary`.
    ///
    /// Maps to the `--summary-limit <value>` option. A value of `0` suppresses the per-submodule
    /// commit list entirely.
    ///
    /// - Parameter value: Maximum number of commits to display per submodule.
    /// - Returns: A new ``GitSubmodule`` value with the summary-limit option applied.
    public func summaryLimit(_ value: Int) -> Self {
        modified(self) { $0.state.summaryLimit = value }
    }

    /// Sets the commit compared by `git submodule summary`.
    ///
    /// Provides the optional positional commit argument that follows the `summary` flags.
    ///
    /// - Parameter value: The commit reference to compare against.
    /// - Returns: A new ``GitSubmodule`` value with the summary commit applied.
    public func summaryCommit(_ value: String) -> Self {
        modified(self) { $0.state.summaryCommit = value }
    }

    /// Restricts the command to one submodule path.
    ///
    /// Appends the path to the existing pathspec list. Use ``paths(_:)`` for bulk updates.
    ///
    /// - Parameter value: A single submodule path to include.
    /// - Returns: A new ``GitSubmodule`` value with the path appended.
    public func path(_ value: String) -> Self {
        modified(self) { $0.state.paths += [value] }
    }

    /// Restricts the command to multiple submodule paths.
    ///
    /// Appends each value to the existing pathspec list rather than replacing it.
    ///
    /// - Parameter values: The submodule paths to include.
    /// - Returns: A new ``GitSubmodule`` value with the paths appended.
    public func paths(_ values: [String]) -> Self {
        modified(self) { $0.state.paths += values }
    }

    /// Builds the raw `git submodule` command represented by the current builder state.
    ///
    /// Argv layout depends on the selected subcommand: each subcommand pulls only the flags
    /// that apply to it (e.g. `--init` and `--remote` are only emitted for `update`). The
    /// shared ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments = ["submodule"]
        if state.quiet {
            arguments.append("--quiet")
        }
        guard let subcommand = state.subcommand else {
            appendStatusOptions(to: &arguments)
            return buildCommand(arguments)
        }

        arguments.append(subcommand.rawValue)
        switch subcommand {
        case .add:
            appendAddOptions(to: &arguments)
            arguments.append("--")
            if let repository = state.repository {
                arguments.append(repository)
            }
            arguments.append(contentsOf: state.paths)
        case .status:
            appendStatusOptions(to: &arguments)
        case .initialize:
            appendPathspec(to: &arguments)
        case .deinitialize:
            if state.force {
                arguments.append("--force")
            }
            if state.all {
                arguments.append("--all")
            } else {
                appendPathspec(to: &arguments)
            }
        case .update:
            appendUpdateOptions(to: &arguments)
            appendPathspec(to: &arguments)
        case .setBranch:
            if let branch = state.branch {
                arguments.append(contentsOf: ["--branch", branch])
            } else if state.usesDefaultBranch {
                arguments.append("--default")
            }
            appendPathspec(to: &arguments)
        case .setURL:
            appendPathspec(to: &arguments)
            if let newURL = state.newURL {
                arguments.append(newURL)
            }
        case .summary:
            appendSummaryOptions(to: &arguments)
            appendPathspec(to: &arguments)
        case .foreach:
            if state.recursive {
                arguments.append("--recursive")
            }
            if let foreachCommand = state.foreachCommand {
                arguments.append(foreachCommand)
            }
        case .sync:
            if state.recursive {
                arguments.append("--recursive")
            }
            appendPathspec(to: &arguments)
        case .absorbGitDirectories:
            appendPathspec(to: &arguments)
        }

        return buildCommand(arguments)
    }

    /// Runs `git submodule status` and parses the output into typed status entries.
    ///
    /// Each ``GitSubmoduleStatusEntry`` carries the typed ``GitSubmoduleStatusState`` derived
    /// from git's leading status marker (`" "`, `-`, `+`, `U`), plus the commit hash, path,
    /// and optional `git describe` text.
    ///
    /// ```swift
    /// let entries = try await git.submodule().recursive().statusEntries().run()
    /// for entry in entries where entry.state != .current {
    ///     print(entry.path, "needs attention")
    /// }
    /// ```
    ///
    /// - Returns: A ``Workflow`` producing parsed ``GitSubmoduleStatusEntry`` values.
    public func statusEntries() -> Workflow<[GitSubmoduleStatusEntry]> {
        let git = state.git
        let command = self.status().settingStdoutDestination(.capture).command()
        return Workflow {
            let output = try await command.run(in: git.context)
            return try GitParsers.parse(
                try output.validatedStdout(for: command),
                from: command,
                using: GitParsers.parseSubmoduleStatusEntries
            )
        }
    }

    private func appendAddOptions(to arguments: inout [String]) {
        if let branch = state.branch {
            arguments.append(contentsOf: ["--branch", branch])
        }
        if state.force {
            arguments.append("--force")
        }
        if state.progress {
            arguments.append("--progress")
        }
        if let name = state.name {
            arguments.append(contentsOf: ["--name", name])
        }
        if let reference = state.reference {
            arguments.append(contentsOf: ["--reference", reference])
        }
        if state.dissociate {
            arguments.append("--dissociate")
        }
        if let refFormat = state.refFormat {
            arguments.append(contentsOf: ["--ref-format", refFormat])
        }
        if let depth = state.depth {
            arguments.append(contentsOf: ["--depth", String(depth)])
        }
    }

    private func appendStatusOptions(to arguments: inout [String]) {
        if state.cached {
            arguments.append("--cached")
        }
        if state.recursive {
            arguments.append("--recursive")
        }
        appendPathspec(to: &arguments)
    }

    private func appendUpdateOptions(to arguments: inout [String]) {
        if state.initializesOnUpdate {
            arguments.append("--init")
        }
        if state.remote {
            arguments.append("--remote")
        }
        if state.noFetch {
            arguments.append("--no-fetch")
        }
        if state.force {
            arguments.append("--force")
        }
        if state.progress {
            arguments.append("--progress")
        }
        if let updateStrategy = state.updateStrategy {
            arguments.append(contentsOf: updateStrategy.arguments)
        }
        if let reference = state.reference {
            arguments.append(contentsOf: ["--reference", reference])
        }
        if state.dissociate {
            arguments.append("--dissociate")
        }
        if let refFormat = state.refFormat {
            arguments.append(contentsOf: ["--ref-format", refFormat])
        }
        if let depth = state.depth {
            arguments.append(contentsOf: ["--depth", String(depth)])
        }
        if state.recursive {
            arguments.append("--recursive")
        }
        if let jobs = state.jobs {
            arguments.append(contentsOf: ["--jobs", String(jobs)])
        }
        if state.singleBranch {
            arguments.append("--single-branch")
        }
        if state.noSingleBranch {
            arguments.append("--no-single-branch")
        }
        if state.recommendShallow {
            arguments.append("--recommend-shallow")
        }
        if state.noRecommendShallow {
            arguments.append("--no-recommend-shallow")
        }
        if let filter = state.filter {
            arguments.append(contentsOf: ["--filter", filter])
        }
    }

    private func appendSummaryOptions(to arguments: inout [String]) {
        if state.cached {
            arguments.append("--cached")
        }
        if state.files {
            arguments.append("--files")
        }
        if let summaryLimit = state.summaryLimit {
            arguments.append(contentsOf: ["--summary-limit", String(summaryLimit)])
        }
        if let summaryCommit = state.summaryCommit {
            arguments.append(summaryCommit)
        }
    }

    private func appendPathspec(to arguments: inout [String]) {
        guard !state.paths.isEmpty else { return }
        arguments.append("--")
        arguments.append(contentsOf: state.paths)
    }

    private func buildCommand(_ arguments: [String]) -> Command {
        state.git.makeCommand(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)
    }
}

private extension GitSubmodule {
    init(state: State) {
        self.state = state
    }

    enum Subcommand: String, Sendable {
        case add
        case status
        case initialize = "init"
        case deinitialize = "deinit"
        case update
        case setBranch = "set-branch"
        case setURL = "set-url"
        case summary
        case foreach
        case sync
        case absorbGitDirectories = "absorbgitdirs"
    }

    struct State: Sendable {
        var git: Git
        var stdoutDestination: OutputDestination = .capture
        var stderrDestination: OutputDestination = .capture
        var subcommand: Subcommand? = nil
        var quiet: Bool = false
        var cached: Bool = false
        var recursive: Bool = false
        var force: Bool = false
        var progress: Bool = false
        var all: Bool = false
        var branch: String? = nil
        var usesDefaultBranch: Bool = false
        var name: String? = nil
        var reference: String? = nil
        var dissociate: Bool = false
        var refFormat: String? = nil
        var depth: Int? = nil
        var initializesOnUpdate: Bool = false
        var remote: Bool = false
        var noFetch: Bool = false
        var updateStrategy: GitSubmoduleUpdateStrategy? = nil
        var jobs: Int? = nil
        var singleBranch: Bool = false
        var noSingleBranch: Bool = false
        var recommendShallow: Bool = false
        var noRecommendShallow: Bool = false
        var filter: String? = nil
        var files: Bool = false
        var summaryLimit: Int? = nil
        var summaryCommit: String? = nil
        var repository: String? = nil
        var newURL: String? = nil
        var foreachCommand: String? = nil
        var paths: [String] = []
    }
}
#endif
