#if Bun
import Foundation

/// The top-level Bun command to invoke.
public enum BunSubcommand: String, Sendable, Equatable, Hashable {
    /// `bun run` — run a package script or JavaScript/TypeScript file.
    case run
    /// `bun test` — run Bun's test runner.
    case test
    /// `bun install` — install project dependencies.
    case install
    /// `bun add` — add dependencies to a project.
    case add
    /// `bun remove` — remove dependencies from a project.
    case remove
    /// `bun build` — bundle source files.
    case build
    /// `bun x` — execute a package binary.
    case x
    /// `bun pm` — run package-manager maintenance commands.
    case pm
    /// `bun upgrade` — upgrade the Bun executable.
    case upgrade
}

/// A fluent wrapper for the Bun runtime and package manager CLI.
///
/// ``Bun`` covers common script execution, testing, dependency management, and
/// bundling entry points while preserving access to raw Bun options.
///
/// ```swift
/// try await Bun()
///     .runScript("dev")
///     .watch()
///     .run()
/// ```
public struct Bun: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Bun command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) { self.state = state }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that selects a Bun subcommand.
    public func subcommand(_ value: BunSubcommand) -> Self { copy(subcommand: value.rawValue, scriptName: nil) }

    /// Returns a copy that selects a raw Bun subcommand.
    public func subcommand(_ value: String) -> Self { copy(subcommand: value, scriptName: nil) }

    /// Returns a copy configured for `bun install`.
    public func install() -> Self { subcommand(.install) }

    /// Returns a copy configured for `bun add <packages>`.
    public func add(_ packages: String...) -> Self { add(packages) }

    /// Returns a copy configured for `bun add <packages>`.
    public func add(_ packages: [String]) -> Self { copy(subcommand: "add", scriptName: nil, positionals: packages) }

    /// Returns a copy configured for `bun remove <packages>`.
    public func remove(_ packages: String...) -> Self { remove(packages) }

    /// Returns a copy configured for `bun remove <packages>`.
    public func remove(_ packages: [String]) -> Self {
        copy(subcommand: "remove", scriptName: nil, positionals: packages)
    }

    /// Returns a copy configured for `bun test`.
    public func test() -> Self { subcommand(.test) }

    /// Returns a copy configured for `bun build <entrypoints>`.
    public func build(_ entrypoints: String...) -> Self { build(entrypoints) }

    /// Returns a copy configured for `bun build <entrypoints>`.
    public func build(_ entrypoints: [String]) -> Self {
        copy(subcommand: "build", scriptName: nil, buildEntrypoints: entrypoints, positionals: [])
    }

    /// Returns a copy configured for `bun x <binary>`.
    public func x(_ binary: String? = nil) -> Self {
        copy(subcommand: "x", scriptName: nil, positionals: binary.map { [$0] } ?? [])
    }

    /// Returns a copy configured for `bun run <name>`.
    public func runScript(_ name: String) -> Self { copy(subcommand: "run", scriptName: name, positionals: []) }

    /// Returns a copy that passes `--cwd <path>`.
    public func cwd(_ path: String) -> Self { copy(cwdPath: path) }

    /// Returns a copy that passes `--watch`.
    public func watch(_ enabled: Bool = true) -> Self { copy(watches: enabled) }

    /// Returns a copy that passes `--hot`.
    public func hot(_ enabled: Bool = true) -> Self { copy(usesHotReload: enabled) }

    /// Returns a copy that passes `--production`.
    public func production(_ enabled: Bool = true) -> Self { copy(isProduction: enabled) }

    /// Returns a copy that passes `--frozen-lockfile`.
    public func frozenLockfile(_ enabled: Bool = true) -> Self { copy(usesFrozenLockfile: enabled) }

    /// Returns a copy that appends a raw option before positional arguments.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw options before positional arguments.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends a positional package, binary, or script argument.
    public func positionalArgument(_ value: String) -> Self { copy(positionals: state.positionals + [value]) }

    /// Returns a copy that appends positional package, binary, or script arguments.
    public func positionalArguments(_ values: [String]) -> Self { copy(positionals: state.positionals + values) }

    /// Builds the raw `bun` command represented by the current builder state.
    public func command() -> Command {
        var arguments = [state.subcommand]
        appendOption("--cwd", state.cwdPath, to: &arguments)
        if state.subcommand == BunSubcommand.build.rawValue {
            arguments += state.buildEntrypoints
        }
        if state.watches { arguments.append("--watch") }
        if state.usesHotReload { arguments.append("--hot") }
        if state.isProduction { arguments.append("--production") }
        if state.usesFrozenLockfile { arguments.append("--frozen-lockfile") }
        arguments += state.extraArguments
        if let scriptName = state.scriptName { arguments.append(scriptName) }
        arguments += state.positionals

        let base = Command("bun").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: String? = nil,
        scriptName: String?? = nil,
        cwdPath: String?? = nil,
        watches: Bool? = nil,
        usesHotReload: Bool? = nil,
        isProduction: Bool? = nil,
        usesFrozenLockfile: Bool? = nil,
        extraArguments: [String]? = nil,
        buildEntrypoints: [String]? = nil,
        positionals: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                scriptName: scriptName ?? state.scriptName,
                cwdPath: cwdPath ?? state.cwdPath,
                watches: watches ?? state.watches,
                usesHotReload: usesHotReload ?? state.usesHotReload,
                isProduction: isProduction ?? state.isProduction,
                usesFrozenLockfile: usesFrozenLockfile ?? state.usesFrozenLockfile,
                extraArguments: extraArguments ?? state.extraArguments,
                buildEntrypoints: buildEntrypoints ?? state.buildEntrypoints,
                positionals: positionals ?? state.positionals
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let subcommand: String
    let scriptName: String?
    let cwdPath: String?
    let watches: Bool
    let usesHotReload: Bool
    let isProduction: Bool
    let usesFrozenLockfile: Bool
    let extraArguments: [String]
    let buildEntrypoints: [String]
    let positionals: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        subcommand: String = "--version",
        scriptName: String? = nil,
        cwdPath: String? = nil,
        watches: Bool = false,
        usesHotReload: Bool = false,
        isProduction: Bool = false,
        usesFrozenLockfile: Bool = false,
        extraArguments: [String] = [],
        buildEntrypoints: [String] = [],
        positionals: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.subcommand = subcommand
        self.scriptName = scriptName
        self.cwdPath = cwdPath
        self.watches = watches
        self.usesHotReload = usesHotReload
        self.isProduction = isProduction
        self.usesFrozenLockfile = usesFrozenLockfile
        self.extraArguments = extraArguments
        self.buildEntrypoints = buildEntrypoints
        self.positionals = positionals
    }
}
#endif
