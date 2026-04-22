import Foundation

/// The subcommand selected for a ``Brew`` invocation.
public enum BrewSubcommand: Sendable, Equatable, Hashable {
    /// `brew install` — install one or more formulae or casks.
    case install
    /// `brew uninstall` — uninstall one or more formulae or casks.
    case uninstall
    /// `brew upgrade` — upgrade installed formulae or casks.
    case upgrade
    /// `brew update` — update Homebrew itself and the local formula database.
    case update
    /// `brew list` — list installed formulae or casks.
    case list
    /// `brew info` — show information about a formula or cask.
    case info
    /// `brew search` — search for a formula or cask by name or pattern.
    case search
    /// `brew outdated` — list outdated formulae or casks.
    case outdated

    fileprivate var argument: String {
        switch self {
        case .install: "install"
        case .uninstall: "uninstall"
        case .upgrade: "upgrade"
        case .update: "update"
        case .list: "list"
        case .info: "info"
        case .search: "search"
        case .outdated: "outdated"
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
/// ```swift
/// // Install formulae
/// try await Brew(context: context)
///     .install("ripgrep", "fzf")
///     .run()
///
/// // Install a cask
/// try await Brew(context: context)
///     .install("firefox")
///     .cask()
///     .run()
///
/// // List outdated packages (greedy includes casks with auto-updates)
/// let outdated = try await Brew(context: context)
///     .outdated()
///     .greedy()
///     .run()
/// print(outdated.stdout)
///
/// // Search for a formula
/// let matches = try await Brew(context: context)
///     .search("ripgrep")
///     .run()
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
