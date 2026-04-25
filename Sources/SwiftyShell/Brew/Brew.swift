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
    public var context: ShellContext { state.config.context }

    /// Creates a `brew` command family bound to a shell context.
    ///
    /// The default subcommand is ``BrewSubcommand/list``. Use one of the
    /// subcommand methods (``install(_:)-(String...)``, ``upgrade(_:)-(String...)``,
    /// ``uninstall(_:)-(String...)``, ``update()``, ``info(_:)-(String...)``,
    /// ``search(_:)``, ``outdated()``) to select a different operation.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a new value with updated shared tool configuration.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Redirects stdout for the built `brew` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `brew` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    // MARK: - Subcommand selectors

    /// Selects any Homebrew subcommand modeled by ``BrewSubcommand``.
    public func subcommand(_ value: BrewSubcommand) -> Self {
        copy(subcommand: value)
    }

    /// Selects a Homebrew subcommand by raw command name.
    ///
    /// Use this escape hatch for external Homebrew commands or newly added Homebrew
    /// commands before SwiftyShell adds a dedicated ``BrewSubcommand`` case.
    public func subcommand(_ value: String) -> Self {
        subcommand(.custom(value))
    }

    /// Selects the ``BrewSubcommand/install`` subcommand and appends the given formulae.
    public func install(_ formulae: String...) -> Self {
        install(formulae)
    }

    /// Selects the ``BrewSubcommand/install`` subcommand and appends the given formulae.
    public func install(_ formulae: [String]) -> Self {
        copy(subcommand: .install, arguments: state.arguments + formulae)
    }

    /// Selects the ``BrewSubcommand/uninstall`` subcommand and appends the given formulae.
    public func uninstall(_ formulae: String...) -> Self {
        uninstall(formulae)
    }

    /// Selects the ``BrewSubcommand/uninstall`` subcommand and appends the given formulae.
    public func uninstall(_ formulae: [String]) -> Self {
        copy(subcommand: .uninstall, arguments: state.arguments + formulae)
    }

    /// Selects the ``BrewSubcommand/upgrade`` subcommand and appends the given formulae.
    ///
    /// Pass no formulae to upgrade all installed packages.
    public func upgrade(_ formulae: String...) -> Self {
        upgrade(formulae)
    }

    /// Selects the ``BrewSubcommand/upgrade`` subcommand and appends the given formulae.
    public func upgrade(_ formulae: [String]) -> Self {
        copy(subcommand: .upgrade, arguments: state.arguments + formulae)
    }

    /// Selects the ``BrewSubcommand/update`` subcommand.
    public func update() -> Self {
        copy(subcommand: .update)
    }

    /// Selects the ``BrewSubcommand/list`` subcommand and appends the given formulae.
    public func list(_ formulae: String...) -> Self {
        list(formulae)
    }

    /// Selects the ``BrewSubcommand/list`` subcommand and appends the given formulae.
    public func list(_ formulae: [String]) -> Self {
        copy(subcommand: .list, arguments: state.arguments + formulae)
    }

    /// Selects the ``BrewSubcommand/info`` subcommand and appends the given formulae.
    public func info(_ formulae: String...) -> Self {
        info(formulae)
    }

    /// Selects the ``BrewSubcommand/info`` subcommand and appends the given formulae.
    public func info(_ formulae: [String]) -> Self {
        copy(subcommand: .info, arguments: state.arguments + formulae)
    }

    /// Selects the ``BrewSubcommand/search`` subcommand with the given pattern.
    public func search(_ pattern: String) -> Self {
        copy(subcommand: .search, arguments: state.arguments + [pattern])
    }

    /// Selects the ``BrewSubcommand/outdated`` subcommand.
    public func outdated() -> Self {
        copy(subcommand: .outdated)
    }

    /// Appends an arbitrary argument to the selected Homebrew subcommand.
    ///
    /// Use this for command-specific flags that SwiftyShell does not model directly.
    public func arg(_ value: String) -> Self {
        copy(arguments: state.arguments + [value])
    }

    /// Appends arbitrary arguments to the selected Homebrew subcommand.
    ///
    /// Use this for command-specific flags that SwiftyShell does not model directly.
    public func args(_ values: [String]) -> Self {
        copy(arguments: state.arguments + values)
    }

    /// Appends an additional positional formula or cask name.
    public func formula(_ name: String) -> Self {
        copy(arguments: state.arguments + [name])
    }

    /// Appends additional positional formula or cask names.
    public func formulae(_ names: [String]) -> Self {
        copy(arguments: state.arguments + names)
    }

    // MARK: - Flags

    /// Treats the named packages as casks (`--cask`).
    public func cask(_ enabled: Bool = true) -> Self {
        copy(usesCaskFlag: enabled)
    }

    /// Treats the named packages as formulae (`--formula`).
    public func formulaFlag(_ enabled: Bool = true) -> Self {
        copy(usesFormulaFlag: enabled)
    }

    /// Forces the operation (`--force`).
    public func force(_ enabled: Bool = true) -> Self {
        copy(isForce: enabled)
    }

    /// Suppresses non-essential output (`--quiet`).
    public func quiet(_ enabled: Bool = true) -> Self {
        copy(isQuiet: enabled)
    }

    /// Emits verbose output (`--verbose`).
    public func verbose(_ enabled: Bool = true) -> Self {
        copy(isVerbose: enabled)
    }

    /// Describes what would be done without running the operation (`--dry-run`).
    public func dryRun(_ enabled: Bool = true) -> Self {
        copy(isDryRun: enabled)
    }

    /// Includes casks with auto-updates when reporting or upgrading (`--greedy`).
    public func greedy(_ enabled: Bool = true) -> Self {
        copy(isGreedy: enabled)
    }

    /// Builds the raw `brew` command.
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
