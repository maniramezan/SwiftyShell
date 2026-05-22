#if Npm
import Foundation

/// The top-level npm command to invoke.
public enum NpmSubcommand: String, Sendable, Equatable, Hashable {
    /// `npm install` — install package dependencies.
    case install
    /// `npm ci` — install dependencies from a lockfile for CI.
    case ci
    /// `npm run` — run a package script.
    case run
    /// `npm test` — run package tests.
    case test
    /// `npm publish` — publish a package.
    case publish
    /// `npm exec` — execute a package binary.
    case exec
    /// `npm outdated` — check for outdated dependencies.
    case outdated
    /// `npm audit` — audit dependency vulnerabilities.
    case audit
    /// `npm version` — manage package versioning.
    case version
}

/// A fluent wrapper for the npm package manager CLI.
///
/// ``Npm`` focuses on script automation, CI installs, package execution, and
/// common npm global flags.
///
/// ```swift
/// try await Npm()
///     .runScript("build")
///     .ifPresent()
///     .run()
/// ```
public struct Npm: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates an npm command family bound to a shell context.
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

    /// Returns a copy that selects an npm subcommand.
    public func subcommand(_ value: NpmSubcommand) -> Self { copy(subcommand: value.rawValue, scriptName: nil) }

    /// Returns a copy that selects a raw npm subcommand.
    public func subcommand(_ value: String) -> Self { copy(subcommand: value, scriptName: nil) }

    /// Returns a copy configured for `npm install`.
    public func install() -> Self { subcommand(.install) }

    /// Returns a copy configured for `npm ci`.
    public func ci() -> Self { subcommand(.ci) }

    /// Returns a copy configured for `npm test`.
    public func test() -> Self { subcommand(.test) }

    /// Returns a copy configured for `npm exec <binary>`.
    public func exec(_ binary: String? = nil) -> Self {
        copy(subcommand: "exec", scriptName: nil, positionals: binary.map { [$0] } ?? [])
    }

    /// Returns a copy configured for `npm run <name>`.
    public func runScript(_ name: String) -> Self { copy(subcommand: "run", scriptName: name, positionals: []) }

    /// Returns a copy that passes `--prefix <path>`.
    public func prefix(_ path: String) -> Self { copy(prefixPath: path) }

    /// Returns a copy that passes `--global`.
    ///
    /// Combining this with ``prefix(_:)`` mirrors npm's permissive CLI behavior,
    /// but npm treats global installs as outside the project prefix workflow.
    public func global(_ enabled: Bool = true) -> Self { copy(isGlobal: enabled) }

    /// Returns a copy that passes `--production`.
    public func production(_ enabled: Bool = true) -> Self { copy(isProduction: enabled) }

    /// Returns a copy that passes `--if-present`.
    public func ifPresent(_ enabled: Bool = true) -> Self { copy(ifPresentEnabled: enabled) }

    /// Returns a copy that passes `--silent`.
    public func silent(_ enabled: Bool = true) -> Self { copy(isSilent: enabled) }

    /// Returns a copy that passes `--json`.
    public func json(_ enabled: Bool = true) -> Self { copy(outputsJSON: enabled) }

    /// Returns a copy that appends a raw option before positional arguments.
    public func argument(_ value: String) -> Self { copy(extraArguments: state.extraArguments + [value]) }

    /// Returns a copy that appends raw options before positional arguments.
    public func arguments(_ values: [String]) -> Self { copy(extraArguments: state.extraArguments + values) }

    /// Returns a copy that appends a positional package, binary, or script argument.
    public func positionalArgument(_ value: String) -> Self { copy(positionals: state.positionals + [value]) }

    /// Returns a copy that appends positional package, binary, or script arguments.
    public func positionalArguments(_ values: [String]) -> Self { copy(positionals: state.positionals + values) }

    /// Builds the raw `npm` command represented by the current builder state.
    public func command() -> Command {
        var arguments = [state.subcommand]
        appendOption("--prefix", state.prefixPath, to: &arguments)
        if state.isGlobal { arguments.append("--global") }
        if state.isProduction { arguments.append("--production") }
        if state.ifPresentEnabled { arguments.append("--if-present") }
        if state.isSilent { arguments.append("--silent") }
        if state.outputsJSON { arguments.append("--json") }
        arguments += state.extraArguments
        if let scriptName = state.scriptName { arguments.append(scriptName) }
        arguments += state.positionals
        let base = Command("npm").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        subcommand: String? = nil,
        scriptName: String?? = nil,
        prefixPath: String?? = nil,
        isGlobal: Bool? = nil,
        isProduction: Bool? = nil,
        ifPresentEnabled: Bool? = nil,
        isSilent: Bool? = nil,
        outputsJSON: Bool? = nil,
        extraArguments: [String]? = nil,
        positionals: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                subcommand: subcommand ?? state.subcommand,
                scriptName: scriptName ?? state.scriptName,
                prefixPath: prefixPath ?? state.prefixPath,
                isGlobal: isGlobal ?? state.isGlobal,
                isProduction: isProduction ?? state.isProduction,
                ifPresentEnabled: ifPresentEnabled ?? state.ifPresentEnabled,
                isSilent: isSilent ?? state.isSilent,
                outputsJSON: outputsJSON ?? state.outputsJSON,
                extraArguments: extraArguments ?? state.extraArguments,
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
    let prefixPath: String?
    let isGlobal: Bool
    let isProduction: Bool
    let ifPresentEnabled: Bool
    let isSilent: Bool
    let outputsJSON: Bool
    let extraArguments: [String]
    let positionals: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        subcommand: String = "--version",
        scriptName: String? = nil,
        prefixPath: String? = nil,
        isGlobal: Bool = false,
        isProduction: Bool = false,
        ifPresentEnabled: Bool = false,
        isSilent: Bool = false,
        outputsJSON: Bool = false,
        extraArguments: [String] = [],
        positionals: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.subcommand = subcommand
        self.scriptName = scriptName
        self.prefixPath = prefixPath
        self.isGlobal = isGlobal
        self.isProduction = isProduction
        self.ifPresentEnabled = ifPresentEnabled
        self.isSilent = isSilent
        self.outputsJSON = outputsJSON
        self.extraArguments = extraArguments
        self.positionals = positionals
    }
}
#endif
