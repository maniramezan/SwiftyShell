#if Git
import Foundation

/// The update strategy used by ``GitSubmodule`` when running `git submodule update`.
public enum GitSubmoduleUpdateStrategy: Sendable, Equatable, Hashable {
    /// Checks out the commit recorded by the superproject, usually leaving the submodule in detached `HEAD`.
    case checkout

    /// Rebases the current submodule branch onto the commit recorded by the superproject.
    case rebase

    /// Merges the commit recorded by the superproject into the current submodule branch.
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

    /// Redirects stdout for the built `git submodule` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `git submodule` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Selects `git submodule add <repository> [path]`.
    public func add(_ repository: String, path: String? = nil) -> Self {
        copy(subcommand: .add, repository: repository, paths: path.map { [$0] } ?? [])
    }

    /// Selects `git submodule status`.
    public func status() -> Self {
        copy(subcommand: .status)
    }

    /// Selects `git submodule init`.
    public func initialize() -> Self {
        copy(subcommand: .initialize)
    }

    /// Selects `git submodule deinit`.
    public func deinitialize() -> Self {
        copy(subcommand: .deinitialize)
    }

    /// Selects `git submodule update`.
    public func update() -> Self {
        copy(subcommand: .update)
    }

    /// Selects `git submodule set-branch --branch <branch> -- <path>`.
    public func setBranch(_ branch: String, path: String) -> Self {
        copy(subcommand: .setBranch, branch: branch, usesDefaultBranch: false, paths: [path])
    }

    /// Selects `git submodule set-branch --default -- <path>`.
    public func resetBranch(path: String) -> Self {
        copy(subcommand: .setBranch, branch: .some(nil), usesDefaultBranch: true, paths: [path])
    }

    /// Selects `git submodule set-url -- <path> <newurl>`.
    public func setUrl(path: String, to newURL: String) -> Self {
        copy(subcommand: .setURL, newURL: newURL, paths: [path])
    }

    /// Selects `git submodule summary`.
    public func summary() -> Self {
        copy(subcommand: .summary)
    }

    /// Selects `git submodule foreach <command>`.
    public func foreach(_ command: String) -> Self {
        copy(subcommand: .foreach, foreachCommand: command)
    }

    /// Selects `git submodule sync`.
    public func sync() -> Self {
        copy(subcommand: .sync)
    }

    /// Selects `git submodule absorbgitdirs`.
    public func absorbGitDirectories() -> Self {
        copy(subcommand: .absorbGitDirectories)
    }

    /// Suppresses non-error output where supported by `git submodule`.
    public func quiet(_ enabled: Bool = true) -> Self {
        copy(quiet: enabled)
    }

    /// Uses the index instead of `HEAD` for `status` or `summary`.
    public func cached(_ enabled: Bool = true) -> Self {
        copy(cached: enabled)
    }

    /// Traverses nested submodules for commands that support recursive operation.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(recursive: enabled)
    }

    /// Forces `add`, `deinit`, or `update` to proceed where git would otherwise stop.
    public func force(_ enabled: Bool = true) -> Self {
        copy(force: enabled)
    }

    /// Reports progress from `add` or `update` even when stderr is not attached to a terminal.
    public func progress(_ enabled: Bool = true) -> Self {
        copy(progress: enabled)
    }

    /// Applies `deinit` to all submodules.
    public func all(_ enabled: Bool = true) -> Self {
        copy(all: enabled)
    }

    /// Sets the branch used by `add` or `set-branch`.
    public func branch(_ value: String) -> Self {
        copy(branch: value, usesDefaultBranch: false)
    }

    /// Sets the logical name used by `add`.
    public func name(_ value: String) -> Self {
        copy(name: value)
    }

    /// Sets the reference repository used by `add` or `update`.
    public func reference(_ repository: String) -> Self {
        copy(reference: repository)
    }

    /// Stops borrowing objects from a reference repository after cloning.
    public func dissociate(_ enabled: Bool = true) -> Self {
        copy(dissociate: enabled)
    }

    /// Sets the ref storage format used when cloning submodules.
    public func refFormat(_ value: String) -> Self {
        copy(refFormat: value)
    }

    /// Sets the shallow clone depth used by `add` or `update`.
    public func depth(_ value: Int) -> Self {
        copy(depth: value)
    }

    /// Initializes missing submodules before running `git submodule update`.
    public func initializeOnUpdate(_ enabled: Bool = true) -> Self {
        copy(initializesOnUpdate: enabled)
    }

    /// Uses the submodule remote-tracking branch when running `git submodule update`.
    public func remote(_ enabled: Bool = true) -> Self {
        copy(remote: enabled)
    }

    /// Skips fetching from submodule remotes when running `git submodule update --remote`.
    public func noFetch(_ enabled: Bool = true) -> Self {
        copy(noFetch: enabled)
    }

    /// Sets the checkout strategy used by `git submodule update`.
    public func updateStrategy(_ value: GitSubmoduleUpdateStrategy) -> Self {
        copy(updateStrategy: value)
    }

    /// Limits parallel submodule clone jobs when running `git submodule update`.
    public func jobs(_ value: Int) -> Self {
        copy(jobs: value)
    }

    /// Clones only one branch when running `git submodule update`.
    public func singleBranch(_ enabled: Bool = true) -> Self {
        copy(singleBranch: enabled, noSingleBranch: enabled ? false : state.noSingleBranch)
    }

    /// Allows cloning more than one branch when running `git submodule update`.
    public func noSingleBranch(_ enabled: Bool = true) -> Self {
        copy(singleBranch: enabled ? false : state.singleBranch, noSingleBranch: enabled)
    }

    /// Uses `.gitmodules` shallow-clone recommendations when updating submodules.
    public func recommendShallow(_ enabled: Bool = true) -> Self {
        copy(recommendShallow: enabled, noRecommendShallow: enabled ? false : state.noRecommendShallow)
    }

    /// Ignores `.gitmodules` shallow-clone recommendations when updating submodules.
    public func noRecommendShallow(_ enabled: Bool = true) -> Self {
        copy(recommendShallow: enabled ? false : state.recommendShallow, noRecommendShallow: enabled)
    }

    /// Applies a partial clone filter when running `git submodule update`.
    public func filter(_ value: String) -> Self {
        copy(filter: value)
    }

    /// Compares the superproject index to the submodule working tree when running `summary`.
    public func files(_ enabled: Bool = true) -> Self {
        copy(files: enabled)
    }

    /// Sets the total commit limit shown by `git submodule summary`.
    public func summaryLimit(_ value: Int) -> Self {
        copy(summaryLimit: value)
    }

    /// Sets the commit compared by `git submodule summary`.
    public func summaryCommit(_ value: String) -> Self {
        copy(summaryCommit: value)
    }

    /// Restricts the command to one submodule path.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Restricts the command to multiple submodule paths.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the raw `git submodule` command.
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
    public func statusEntries() -> Workflow<[GitSubmoduleStatusEntry]> {
        let git = state.git
        let command = self.status().command()
        return Workflow {
            let output = try await command.run(in: git.context)
            return GitParsers.parseSubmoduleStatusEntries(output.stdout)
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

    private func copy(
        git: Git? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: Subcommand?? = nil,
        quiet: Bool? = nil,
        cached: Bool? = nil,
        recursive: Bool? = nil,
        force: Bool? = nil,
        progress: Bool? = nil,
        all: Bool? = nil,
        branch: String?? = nil,
        usesDefaultBranch: Bool? = nil,
        name: String?? = nil,
        reference: String?? = nil,
        dissociate: Bool? = nil,
        refFormat: String?? = nil,
        depth: Int?? = nil,
        initializesOnUpdate: Bool? = nil,
        remote: Bool? = nil,
        noFetch: Bool? = nil,
        updateStrategy: GitSubmoduleUpdateStrategy?? = nil,
        jobs: Int?? = nil,
        singleBranch: Bool? = nil,
        noSingleBranch: Bool? = nil,
        recommendShallow: Bool? = nil,
        noRecommendShallow: Bool? = nil,
        filter: String?? = nil,
        files: Bool? = nil,
        summaryLimit: Int?? = nil,
        summaryCommit: String?? = nil,
        repository: String?? = nil,
        newURL: String?? = nil,
        foreachCommand: String?? = nil,
        paths: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                git: git ?? state.git,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                quiet: quiet ?? state.quiet,
                cached: cached ?? state.cached,
                recursive: recursive ?? state.recursive,
                force: force ?? state.force,
                progress: progress ?? state.progress,
                all: all ?? state.all,
                branch: branch ?? state.branch,
                usesDefaultBranch: usesDefaultBranch ?? state.usesDefaultBranch,
                name: name ?? state.name,
                reference: reference ?? state.reference,
                dissociate: dissociate ?? state.dissociate,
                refFormat: refFormat ?? state.refFormat,
                depth: depth ?? state.depth,
                initializesOnUpdate: initializesOnUpdate ?? state.initializesOnUpdate,
                remote: remote ?? state.remote,
                noFetch: noFetch ?? state.noFetch,
                updateStrategy: updateStrategy ?? state.updateStrategy,
                jobs: jobs ?? state.jobs,
                singleBranch: singleBranch ?? state.singleBranch,
                noSingleBranch: noSingleBranch ?? state.noSingleBranch,
                recommendShallow: recommendShallow ?? state.recommendShallow,
                noRecommendShallow: noRecommendShallow ?? state.noRecommendShallow,
                filter: filter ?? state.filter,
                files: files ?? state.files,
                summaryLimit: summaryLimit ?? state.summaryLimit,
                summaryCommit: summaryCommit ?? state.summaryCommit,
                repository: repository ?? state.repository,
                newURL: newURL ?? state.newURL,
                foreachCommand: foreachCommand ?? state.foreachCommand,
                paths: paths ?? state.paths
            )
        )
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
        let git: Git
        let stdoutDestination: OutputDestination
        let stderrDestination: OutputDestination
        let subcommand: Subcommand?
        let quiet: Bool
        let cached: Bool
        let recursive: Bool
        let force: Bool
        let progress: Bool
        let all: Bool
        let branch: String?
        let usesDefaultBranch: Bool
        let name: String?
        let reference: String?
        let dissociate: Bool
        let refFormat: String?
        let depth: Int?
        let initializesOnUpdate: Bool
        let remote: Bool
        let noFetch: Bool
        let updateStrategy: GitSubmoduleUpdateStrategy?
        let jobs: Int?
        let singleBranch: Bool
        let noSingleBranch: Bool
        let recommendShallow: Bool
        let noRecommendShallow: Bool
        let filter: String?
        let files: Bool
        let summaryLimit: Int?
        let summaryCommit: String?
        let repository: String?
        let newURL: String?
        let foreachCommand: String?
        let paths: [String]

        init(
            git: Git,
            stdoutDestination: OutputDestination = .capture,
            stderrDestination: OutputDestination = .capture,
            subcommand: Subcommand? = nil,
            quiet: Bool = false,
            cached: Bool = false,
            recursive: Bool = false,
            force: Bool = false,
            progress: Bool = false,
            all: Bool = false,
            branch: String? = nil,
            usesDefaultBranch: Bool = false,
            name: String? = nil,
            reference: String? = nil,
            dissociate: Bool = false,
            refFormat: String? = nil,
            depth: Int? = nil,
            initializesOnUpdate: Bool = false,
            remote: Bool = false,
            noFetch: Bool = false,
            updateStrategy: GitSubmoduleUpdateStrategy? = nil,
            jobs: Int? = nil,
            singleBranch: Bool = false,
            noSingleBranch: Bool = false,
            recommendShallow: Bool = false,
            noRecommendShallow: Bool = false,
            filter: String? = nil,
            files: Bool = false,
            summaryLimit: Int? = nil,
            summaryCommit: String? = nil,
            repository: String? = nil,
            newURL: String? = nil,
            foreachCommand: String? = nil,
            paths: [String] = []
        ) {
            self.git = git
            self.stdoutDestination = stdoutDestination
            self.stderrDestination = stderrDestination
            self.subcommand = subcommand
            self.quiet = quiet
            self.cached = cached
            self.recursive = recursive
            self.force = force
            self.progress = progress
            self.all = all
            self.branch = branch
            self.usesDefaultBranch = usesDefaultBranch
            self.name = name
            self.reference = reference
            self.dissociate = dissociate
            self.refFormat = refFormat
            self.depth = depth
            self.initializesOnUpdate = initializesOnUpdate
            self.remote = remote
            self.noFetch = noFetch
            self.updateStrategy = updateStrategy
            self.jobs = jobs
            self.singleBranch = singleBranch
            self.noSingleBranch = noSingleBranch
            self.recommendShallow = recommendShallow
            self.noRecommendShallow = noRecommendShallow
            self.filter = filter
            self.files = files
            self.summaryLimit = summaryLimit
            self.summaryCommit = summaryCommit
            self.repository = repository
            self.newURL = newURL
            self.foreachCommand = foreachCommand
            self.paths = paths
        }
    }
}
#endif
