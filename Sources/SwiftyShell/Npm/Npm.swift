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
    private var state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates an npm command family bound to a shell context.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) { self.state = state }

    /// Returns a copy with updated shared tool configuration.
    public func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes stdout to the given destination.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes stderr to the given destination.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that selects an npm subcommand.
    public func subcommand(_ value: NpmSubcommand) -> Self {
        modified(self) {
            $0.state.subcommand = value.rawValue
            $0.state.scriptName = nil
        }
    }

    /// Returns a copy that selects a raw npm subcommand.
    public func subcommand(_ value: String) -> Self {
        modified(self) {
            $0.state.subcommand = value
            $0.state.scriptName = nil
        }
    }

    /// Returns a copy configured for `npm install`.
    public func install() -> Self { subcommand(.install) }

    /// Returns a copy configured for `npm ci`.
    public func ci() -> Self { subcommand(.ci) }

    /// Returns a copy configured for `npm test`.
    public func test() -> Self { subcommand(.test) }

    /// Returns a copy configured for `npm exec <binary>`.
    public func exec(_ binary: String? = nil) -> Self {
        modified(self) {
            $0.state.subcommand = "exec"
            $0.state.scriptName = nil
            $0.state.positionals = binary.map { [$0] } ?? []
        }
    }

    /// Returns a copy configured for `npm run <name>`.
    public func runScript(_ name: String) -> Self {
        modified(self) {
            $0.state.subcommand = "run"
            $0.state.scriptName = name
            $0.state.positionals = []
        }
    }

    /// Returns a copy that passes `--prefix <path>`.
    public func prefix(_ path: String) -> Self { modified(self) { $0.state.prefixPath = path } }

    /// Returns a copy that passes `--global`.
    ///
    /// Combining this with ``prefix(_:)`` mirrors npm's permissive CLI behavior,
    /// but npm treats global installs as outside the project prefix workflow.
    public func global(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isGlobal = enabled } }

    /// Returns a copy that passes `--production`.
    public func production(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isProduction = enabled } }

    /// Returns a copy that passes `--if-present`.
    public func ifPresent(_ enabled: Bool = true) -> Self { modified(self) { $0.state.ifPresentEnabled = enabled } }

    /// Returns a copy that passes `--silent`.
    public func silent(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isSilent = enabled } }

    /// Returns a copy that passes `--json`.
    public func json(_ enabled: Bool = true) -> Self { modified(self) { $0.state.outputsJSON = enabled } }

    /// Returns a copy that appends a raw option before positional arguments.
    public func argument(_ value: String) -> Self { modified(self) { $0.state.extraArguments += [value] } }

    /// Returns a copy that appends raw options before positional arguments.
    public func arguments(_ values: [String]) -> Self { modified(self) { $0.state.extraArguments += values } }

    /// Returns a copy that appends a positional package, binary, or script argument.
    ///
    /// For ``runScript(_:)``, these values are emitted after an automatically inserted `--` so
    /// npm forwards them to the package script.
    public func positionalArgument(_ value: String) -> Self { modified(self) { $0.state.positionals += [value] } }

    /// Returns a copy that appends positional package, binary, or script arguments.
    public func positionalArguments(_ values: [String]) -> Self { modified(self) { $0.state.positionals += values } }

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
        if let scriptName = state.scriptName {
            arguments.append(scriptName)
            if !state.positionals.isEmpty { arguments.append("--") }
        }
        arguments += state.positionals
        let base = Command("npm").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var subcommand: String = "--version"
    var scriptName: String? = nil
    var prefixPath: String? = nil
    var isGlobal: Bool = false
    var isProduction: Bool = false
    var ifPresentEnabled: Bool = false
    var isSilent: Bool = false
    var outputsJSON: Bool = false
    var extraArguments: [String] = []
    var positionals: [String] = []
}
#endif
