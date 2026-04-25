#if Brew
import Foundation

/// The subcommand selected for a ``Brew`` invocation.
public enum BrewSubcommand: Sendable, Equatable, Hashable {
    /// `brew alias` — show or edit Homebrew command aliases.
    case alias
    /// `brew analytics` — inspect or change Homebrew analytics settings.
    case analytics
    /// `brew autoremove` — remove unneeded dependencies.
    case autoremove
    /// `brew bundle` — manage dependencies from a Brewfile.
    case bundle
    /// `brew casks` — list locally installable casks.
    case casks
    /// `brew cleanup` — remove stale downloads and old installed versions.
    case cleanup
    /// `brew command` — show the file used to implement a brew command.
    case command
    /// `brew commands` — list built-in and external commands.
    case commands
    /// `brew completions` — manage shell completion linking.
    case completions
    /// `brew config` — print Homebrew and system configuration.
    case config
    /// `brew deps` — show dependencies for formulae or casks.
    case deps
    /// `brew desc` — show or search package descriptions.
    case desc
    /// `brew developer` — inspect or change Homebrew developer mode.
    case developer
    /// `brew docs` — open Homebrew documentation.
    case docs
    /// `brew doctor` — check the system for potential Homebrew problems.
    case doctor
    /// `brew fetch` — download source, bottles, or cask artifacts.
    case fetch
    /// `brew formulae` — list locally installable formulae.
    case formulae
    /// `brew gist-logs` — upload build logs to a Gist.
    case gistLogs
    /// `brew help` — show usage information.
    case help
    /// `brew home` — open package or Homebrew homepages.
    case home
    /// `brew install` — install one or more formulae or casks.
    case install
    /// `brew leaves` — list installed formulae that are not dependencies.
    case leaves
    /// `brew link` — symlink installed formula files into Homebrew's prefix.
    case link
    /// `brew list` — list installed formulae or casks.
    case list
    /// `brew log` — show Homebrew or package git logs.
    case log
    /// `brew migrate` — migrate renamed packages to their new names.
    case migrate
    /// `brew missing` — check installed packages for missing dependencies.
    case missing
    /// `brew options` — show install options for formulae.
    case options
    /// `brew info` — show information about a formula or cask.
    case info
    /// `brew outdated` — list outdated formulae or casks.
    case outdated
    /// `brew pin` — prevent formulae from being upgraded.
    case pin
    /// `brew postinstall` — rerun post-install steps for formulae.
    case postinstall
    /// `brew readall` — load all formulae and casks from taps.
    case readall
    /// `brew reinstall` — uninstall and reinstall formulae or casks.
    case reinstall
    /// `brew search` — search for a formula or cask by name or pattern.
    case search
    /// `brew services` — manage background services.
    case services
    /// `brew shellenv` — print shell environment setup commands.
    case shellenv
    /// `brew source` — open a formula's source repository.
    case source
    /// `brew tap` — add or list formula repositories.
    case tap
    /// `brew tap-info` — show information about taps.
    case tapInfo
    /// `brew unalias` — remove Homebrew command aliases.
    case unalias
    /// `brew uninstall` — uninstall one or more formulae or casks.
    case uninstall
    /// `brew unlink` — remove formula symlinks from Homebrew's prefix.
    case unlink
    /// `brew unpin` — allow formulae to be upgraded again.
    case unpin
    /// `brew untap` — remove tapped formula repositories.
    case untap
    /// `brew update` — update Homebrew itself and the local formula database.
    case update
    /// `brew update-if-needed` — update Homebrew only when needed.
    case updateIfNeeded
    /// `brew update-reset` — fetch and reset Homebrew and tap repositories.
    case updateReset
    /// `brew upgrade` — upgrade installed formulae or casks.
    case upgrade
    /// `brew uses` — show formulae and casks that depend on formulae.
    case uses
    /// `brew which-formula` — show which formula provides commands.
    case whichFormula
    /// Any Homebrew subcommand not modeled by a dedicated case.
    case custom(String)

    fileprivate var argument: String {
        switch self {
        case .alias: "alias"
        case .analytics: "analytics"
        case .autoremove: "autoremove"
        case .bundle: "bundle"
        case .casks: "casks"
        case .cleanup: "cleanup"
        case .command: "command"
        case .commands: "commands"
        case .completions: "completions"
        case .config: "config"
        case .deps: "deps"
        case .desc: "desc"
        case .developer: "developer"
        case .docs: "docs"
        case .doctor: "doctor"
        case .fetch: "fetch"
        case .formulae: "formulae"
        case .gistLogs: "gist-logs"
        case .help: "help"
        case .home: "home"
        case .install: "install"
        case .leaves: "leaves"
        case .link: "link"
        case .list: "list"
        case .log: "log"
        case .migrate: "migrate"
        case .missing: "missing"
        case .options: "options"
        case .info: "info"
        case .outdated: "outdated"
        case .pin: "pin"
        case .postinstall: "postinstall"
        case .readall: "readall"
        case .reinstall: "reinstall"
        case .search: "search"
        case .services: "services"
        case .shellenv: "shellenv"
        case .source: "source"
        case .tap: "tap"
        case .tapInfo: "tap-info"
        case .unalias: "unalias"
        case .uninstall: "uninstall"
        case .unlink: "unlink"
        case .unpin: "unpin"
        case .untap: "untap"
        case .update: "update"
        case .updateIfNeeded: "update-if-needed"
        case .updateReset: "update-reset"
        case .upgrade: "upgrade"
        case .uses: "uses"
        case .whichFormula: "which-formula"
        case let .custom(value): value
        }
    }
}

/// A fluent wrapper for the Homebrew (`brew`) package manager.
///
/// ``Brew`` models a single Homebrew subcommand together with its flags and
/// positional arguments. Default subcommand is ``BrewSubcommand/list`` so that
/// `Brew(context: context).run()` safely lists installed formulae without
/// mutating the system.
///
/// Homebrew output is tool-defined text, so ``Brew`` returns raw ``ShellOutput``. Inspect `stdout`
/// for command results and handle ``ShellError/exitFailure(command:output:)`` when Homebrew reports
/// a non-zero exit.
///
/// Install formulae by selecting the `install` subcommand and passing one or more names:
///
/// ```swift
/// try await Brew(context: context)
///     .install("ripgrep", "fzf")
///     .run()
/// ```
///
/// Add ``cask(_:)`` when the install target is a cask instead of a formula:
///
/// ```swift
/// try await Brew(context: context)
///     .install("firefox")
///     .cask()    // Add `--cask`.
///     .run()
/// ```
///
/// Query outdated packages with ``outdated()``. ``greedy(_:)`` includes casks that auto-update or
/// are marked as latest by upstream, and the package list is returned in `stdout`.
///
/// ```swift
/// let outdated = try await Brew(context: context)
///     .outdated()
///     .greedy()    // Include auto-updating/latest casks too.
///     .run()
///
/// print(outdated.stdout)
/// ```
///
/// Search returns Homebrew's matching formulae and casks as text:
///
/// ```swift
/// let matches = try await Brew(context: context)
///     .search("ripgrep")
///     .run()
///
/// print(matches.stdout)
/// ```
///
/// Homebrew is available on macOS and on Linux via
/// [Linuxbrew](https://docs.brew.sh/Homebrew-on-Linux). Real execution requires
/// `brew` to be on ``ShellContext/searchPaths``.
public struct Brew: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the underlying ``ToolConfiguration`` so commands built by ``command()``
    /// and invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a `brew` command family bound to a shell context.
    ///
    /// The default subcommand is ``BrewSubcommand/list`` so a freshly constructed value runs a
    /// safe, read-only `brew list` if invoked immediately. Switch operations with one of the
    /// subcommand selectors below (``install(_:)-(String...)``, ``upgrade(_:)-(String...)``,
    /// ``uninstall(_:)-(String...)``, ``update()``, ``info(_:)-(String...)``, ``search(_:)``,
    /// ``outdated()``), or use ``subcommand(_:)-(BrewSubcommand)`` for any other case.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Brew`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `brew` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Homebrew writes its primary results to stdout
    /// (e.g. `list`, `search`, `outdated` output), so this is the stream most callers inspect.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Brew`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `brew` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Homebrew often emits progress text and
    /// download diagnostics on stderr even on success.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Brew`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    // MARK: - Subcommand selectors

    /// Returns a copy that selects the given Homebrew subcommand.
    ///
    /// Use this when the desired operation is modeled by a ``BrewSubcommand`` case but no
    /// dedicated convenience method exists (e.g. ``BrewSubcommand/cleanup``,
    /// ``BrewSubcommand/doctor``, ``BrewSubcommand/services``).
    ///
    /// - Parameter value: The subcommand to invoke.
    /// - Returns: A new ``Brew`` value with the subcommand applied.
    public func subcommand(_ value: BrewSubcommand) -> Self {
        copy(subcommand: value)
    }

    /// Returns a copy that selects a Homebrew subcommand by raw command name.
    ///
    /// Escape hatch for external Homebrew commands installed via taps and for newly added
    /// Homebrew commands before SwiftyShell ships a dedicated ``BrewSubcommand`` case.
    ///
    /// - Parameter value: The raw subcommand name (e.g. `"bump-formula-pr"`).
    /// - Returns: A new ``Brew`` value with the custom subcommand applied.
    public func subcommand(_ value: String) -> Self {
        subcommand(.custom(value))
    }

    /// Returns a copy that selects ``BrewSubcommand/install`` and appends the given formulae.
    ///
    /// Pair with ``cask(_:)`` to install casks instead of formulae.
    ///
    /// - Parameter formulae: Names of formulae or casks to install.
    /// - Returns: A new ``Brew`` value configured to run `brew install`.
    public func install(_ formulae: String...) -> Self {
        install(formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/install`` and appends the given formulae.
    ///
    /// Array overload of ``install(_:)-(String...)`` for callers building the list dynamically.
    ///
    /// - Parameter formulae: Names of formulae or casks to install.
    /// - Returns: A new ``Brew`` value configured to run `brew install`.
    public func install(_ formulae: [String]) -> Self {
        copy(subcommand: .install, arguments: state.arguments + formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/uninstall`` and appends the given formulae.
    ///
    /// - Parameter formulae: Names of formulae or casks to uninstall.
    /// - Returns: A new ``Brew`` value configured to run `brew uninstall`.
    public func uninstall(_ formulae: String...) -> Self {
        uninstall(formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/uninstall`` and appends the given formulae.
    ///
    /// Array overload of ``uninstall(_:)-(String...)``.
    ///
    /// - Parameter formulae: Names of formulae or casks to uninstall.
    /// - Returns: A new ``Brew`` value configured to run `brew uninstall`.
    public func uninstall(_ formulae: [String]) -> Self {
        copy(subcommand: .uninstall, arguments: state.arguments + formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/upgrade`` and appends the given formulae.
    ///
    /// Pass no formulae to upgrade every installed package.
    ///
    /// - Parameter formulae: Names of formulae or casks to upgrade.
    /// - Returns: A new ``Brew`` value configured to run `brew upgrade`.
    public func upgrade(_ formulae: String...) -> Self {
        upgrade(formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/upgrade`` and appends the given formulae.
    ///
    /// Array overload of ``upgrade(_:)-(String...)``. Pass an empty array to upgrade everything.
    ///
    /// - Parameter formulae: Names of formulae or casks to upgrade.
    /// - Returns: A new ``Brew`` value configured to run `brew upgrade`.
    public func upgrade(_ formulae: [String]) -> Self {
        copy(subcommand: .upgrade, arguments: state.arguments + formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/update``.
    ///
    /// Updates Homebrew itself and the local formula database. Does not upgrade installed
    /// packages — use ``upgrade(_:)-(String...)`` for that.
    ///
    /// - Returns: A new ``Brew`` value configured to run `brew update`.
    public func update() -> Self {
        copy(subcommand: .update)
    }

    /// Returns a copy that selects ``BrewSubcommand/list`` and appends the given formulae.
    ///
    /// Pass no formulae to list every installed package; pass names to inspect the files
    /// installed by specific packages.
    ///
    /// - Parameter formulae: Optional names of installed packages to inspect.
    /// - Returns: A new ``Brew`` value configured to run `brew list`.
    public func list(_ formulae: String...) -> Self {
        list(formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/list`` and appends the given formulae.
    ///
    /// Array overload of ``list(_:)-(String...)``.
    ///
    /// - Parameter formulae: Optional names of installed packages to inspect.
    /// - Returns: A new ``Brew`` value configured to run `brew list`.
    public func list(_ formulae: [String]) -> Self {
        copy(subcommand: .list, arguments: state.arguments + formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/info`` and appends the given formulae.
    ///
    /// - Parameter formulae: Names of formulae or casks to describe.
    /// - Returns: A new ``Brew`` value configured to run `brew info`.
    public func info(_ formulae: String...) -> Self {
        info(formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/info`` and appends the given formulae.
    ///
    /// Array overload of ``info(_:)-(String...)``.
    ///
    /// - Parameter formulae: Names of formulae or casks to describe.
    /// - Returns: A new ``Brew`` value configured to run `brew info`.
    public func info(_ formulae: [String]) -> Self {
        copy(subcommand: .info, arguments: state.arguments + formulae)
    }

    /// Returns a copy that selects ``BrewSubcommand/search`` with the given pattern.
    ///
    /// The pattern is forwarded to Homebrew verbatim. Homebrew accepts plain text and
    /// `/regex/` syntax — see `man brew search` for details.
    ///
    /// - Parameter pattern: The search pattern (literal text or `/regex/`).
    /// - Returns: A new ``Brew`` value configured to run `brew search`.
    public func search(_ pattern: String) -> Self {
        copy(subcommand: .search, arguments: state.arguments + [pattern])
    }

    /// Returns a copy that selects ``BrewSubcommand/outdated``.
    ///
    /// Pair with ``greedy(_:)`` to also list casks that auto-update or are marked latest.
    ///
    /// - Returns: A new ``Brew`` value configured to run `brew outdated`.
    public func outdated() -> Self {
        copy(subcommand: .outdated)
    }

    /// Returns a copy with one additional positional argument or flag appended.
    ///
    /// Escape hatch for command-specific flags that SwiftyShell does not model directly
    /// (e.g. `--HEAD`, `--build-from-source`). Arguments are appended after the modeled
    /// flags in the final argv.
    ///
    /// - Parameter value: The argument or flag to append.
    /// - Returns: A new ``Brew`` value with the argument appended.
    public func arg(_ value: String) -> Self {
        copy(arguments: state.arguments + [value])
    }

    /// Returns a copy with multiple positional arguments or flags appended.
    ///
    /// Array form of ``arg(_:)`` for adding several values at once.
    ///
    /// - Parameter values: The arguments or flags to append, in order.
    /// - Returns: A new ``Brew`` value with the arguments appended.
    public func args(_ values: [String]) -> Self {
        copy(arguments: state.arguments + values)
    }

    /// Returns a copy with one additional positional formula or cask name appended.
    ///
    /// Convenience alias for ``arg(_:)`` that reads as the package name being targeted.
    ///
    /// - Parameter name: The formula or cask name to append.
    /// - Returns: A new ``Brew`` value with the name appended.
    public func formula(_ name: String) -> Self {
        copy(arguments: state.arguments + [name])
    }

    /// Returns a copy with multiple positional formula or cask names appended.
    ///
    /// Convenience alias for ``args(_:)`` that reads as the package names being targeted.
    ///
    /// - Parameter names: The formula or cask names to append, in order.
    /// - Returns: A new ``Brew`` value with the names appended.
    public func formulae(_ names: [String]) -> Self {
        copy(arguments: state.arguments + names)
    }

    // MARK: - Flags

    /// Returns a copy that treats the named packages as casks.
    ///
    /// Maps to the `--cask` flag. Mutually exclusive with ``formulaFlag(_:)`` — supplying both
    /// is an error from `brew`.
    ///
    /// - Parameter enabled: `true` to add `--cask`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Brew`` value with the flag applied.
    public func cask(_ enabled: Bool = true) -> Self {
        copy(usesCaskFlag: enabled)
    }

    /// Returns a copy that treats the named packages as formulae.
    ///
    /// Maps to the `--formula` flag. Mutually exclusive with ``cask(_:)``.
    ///
    /// - Parameter enabled: `true` to add `--formula`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Brew`` value with the flag applied.
    public func formulaFlag(_ enabled: Bool = true) -> Self {
        copy(usesFormulaFlag: enabled)
    }

    /// Returns a copy that forces the operation past safety checks.
    ///
    /// Maps to the `--force` flag. Behavior depends on the subcommand (e.g. force-uninstall
    /// dependencies, force-link).
    ///
    /// - Parameter enabled: `true` to add `--force`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Brew`` value with the flag applied.
    public func force(_ enabled: Bool = true) -> Self {
        copy(isForce: enabled)
    }

    /// Returns a copy that suppresses non-essential Homebrew output.
    ///
    /// Maps to the `--quiet` flag.
    ///
    /// - Parameter enabled: `true` to add `--quiet`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Brew`` value with the flag applied.
    public func quiet(_ enabled: Bool = true) -> Self {
        copy(isQuiet: enabled)
    }

    /// Returns a copy that requests verbose Homebrew output.
    ///
    /// Maps to the `--verbose` flag.
    ///
    /// - Parameter enabled: `true` to add `--verbose`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Brew`` value with the flag applied.
    public func verbose(_ enabled: Bool = true) -> Self {
        copy(isVerbose: enabled)
    }

    /// Returns a copy that describes what would be done without running the operation.
    ///
    /// Maps to the `--dry-run` flag. Useful for previewing destructive operations like
    /// ``BrewSubcommand/uninstall`` or ``BrewSubcommand/cleanup``.
    ///
    /// - Parameter enabled: `true` to add `--dry-run`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Brew`` value with the flag applied.
    public func dryRun(_ enabled: Bool = true) -> Self {
        copy(isDryRun: enabled)
    }

    /// Returns a copy that includes auto-updating casks in reports and upgrades.
    ///
    /// Maps to the `--greedy` flag. Most useful with ``outdated()`` and ``upgrade(_:)-(String...)``,
    /// where Homebrew normally hides casks that update themselves.
    ///
    /// - Parameter enabled: `true` to add `--greedy`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Brew`` value with the flag applied.
    public func greedy(_ enabled: Bool = true) -> Self {
        copy(isGreedy: enabled)
    }

    /// Builds the raw `brew` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: subcommand, then modeled flags (`--cask`, `--formula`,
    /// `--force`, `--quiet`, `--verbose`, `--dry-run`, `--greedy`), then any positional
    /// arguments accumulated via ``arg(_:)``/``args(_:)``/``formula(_:)``/``formulae(_:)`` or
    /// the subcommand selectors. The shared ``ToolConfiguration`` overrides are merged in via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = [state.subcommand.argument]

        if state.usesCaskFlag {
            arguments.append("--cask")
        }
        if state.usesFormulaFlag {
            arguments.append("--formula")
        }
        if state.isForce {
            arguments.append("--force")
        }
        if state.isQuiet {
            arguments.append("--quiet")
        }
        if state.isVerbose {
            arguments.append("--verbose")
        }
        if state.isDryRun {
            arguments.append("--dry-run")
        }
        if state.isGreedy {
            arguments.append("--greedy")
        }

        arguments.append(contentsOf: state.arguments)

        let base = Command("brew")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: BrewSubcommand? = nil,
        arguments: [String]? = nil,
        usesCaskFlag: Bool? = nil,
        usesFormulaFlag: Bool? = nil,
        isForce: Bool? = nil,
        isQuiet: Bool? = nil,
        isVerbose: Bool? = nil,
        isDryRun: Bool? = nil,
        isGreedy: Bool? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                arguments: arguments ?? state.arguments,
                usesCaskFlag: usesCaskFlag ?? state.usesCaskFlag,
                usesFormulaFlag: usesFormulaFlag ?? state.usesFormulaFlag,
                isForce: isForce ?? state.isForce,
                isQuiet: isQuiet ?? state.isQuiet,
                isVerbose: isVerbose ?? state.isVerbose,
                isDryRun: isDryRun ?? state.isDryRun,
                isGreedy: isGreedy ?? state.isGreedy
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let subcommand: BrewSubcommand
    let arguments: [String]
    let usesCaskFlag: Bool
    let usesFormulaFlag: Bool
    let isForce: Bool
    let isQuiet: Bool
    let isVerbose: Bool
    let isDryRun: Bool
    let isGreedy: Bool

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        subcommand: BrewSubcommand = .list,
        arguments: [String] = [],
        usesCaskFlag: Bool = false,
        usesFormulaFlag: Bool = false,
        isForce: Bool = false,
        isQuiet: Bool = false,
        isVerbose: Bool = false,
        isDryRun: Bool = false,
        isGreedy: Bool = false
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.subcommand = subcommand
        self.arguments = arguments
        self.usesCaskFlag = usesCaskFlag
        self.usesFormulaFlag = usesFormulaFlag
        self.isForce = isForce
        self.isQuiet = isQuiet
        self.isVerbose = isVerbose
        self.isDryRun = isDryRun
        self.isGreedy = isGreedy
    }
}
#endif
