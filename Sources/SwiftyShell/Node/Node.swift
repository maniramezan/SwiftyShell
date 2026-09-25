#if Node
import Foundation

/// A fluent wrapper for the Node.js runtime CLI (`node`).
///
/// ``Node`` covers common scripting entry points: version checks, inline code
/// evaluation, syntax checks, preload modules, and script execution.
///
/// ```swift
/// let output = try await Node()
///     .eval("console.log(process.version)")
///     .run()
/// ```
public struct Node: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Node command family bound to a shell context.
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

    /// Returns a copy that prints Node.js version information with `--version`.
    ///
    /// Selecting version mode clears any script arguments from a previously selected entry point.
    public func version() -> Self {
        modified(self) {
            $0.state.mode = .version
            $0.state.scriptArguments = []
        }
    }

    /// Returns a copy that evaluates JavaScript with `--eval <code>`.
    public func eval(_ code: String) -> Self {
        modified(self) {
            $0.state.mode = .eval(code)
            $0.state.scriptArguments = []
        }
    }

    /// Returns a copy that prints JavaScript expression output with `--print <code>`.
    public func printExpression(_ code: String) -> Self {
        modified(self) {
            $0.state.mode = .print(code)
            $0.state.scriptArguments = []
        }
    }

    /// Returns a copy that checks a script's syntax with `--check <path>`.
    public func check(_ path: String) -> Self {
        modified(self) {
            $0.state.mode = .check(path)
            $0.state.scriptArguments = []
        }
    }

    /// Returns a copy that runs a JavaScript file.
    public func script(_ path: String) -> Self {
        modified(self) {
            $0.state.mode = .script(path)
            $0.state.scriptArguments = []
        }
    }

    /// Returns a copy that preloads a module with `--require <module>`.
    public func require(_ module: String) -> Self { modified(self) { $0.state.requires += [module] } }

    /// Returns a copy that enables inspector support with `--inspect`.
    public func inspect(_ enabled: Bool = true) -> Self { modified(self) { $0.state.inspects = enabled } }

    /// Returns a copy that enables watch mode with `--watch`.
    public func watch(_ enabled: Bool = true) -> Self { modified(self) { $0.state.watches = enabled } }

    /// Returns a copy that appends a raw Node option before the selected entry point.
    public func argument(_ value: String) -> Self { modified(self) { $0.state.extraArguments += [value] } }

    /// Returns a copy that appends raw Node options before the selected entry point.
    public func arguments(_ values: [String]) -> Self { modified(self) { $0.state.extraArguments += values } }

    /// Returns a copy that appends an argument passed to the selected script or inline program.
    public func scriptArgument(_ value: String) -> Self { modified(self) { $0.state.scriptArguments += [value] } }

    /// Returns a copy that appends arguments passed to the selected script or inline program.
    public func scriptArguments(_ values: [String]) -> Self { modified(self) { $0.state.scriptArguments += values } }

    /// Builds the raw `node` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String] = []
        for module in state.requires { arguments += ["--require", module] }
        if state.inspects { arguments.append("--inspect") }
        if state.watches { arguments.append("--watch") }
        arguments += state.extraArguments
        switch state.mode {
        case .version: arguments.append("--version")
        case let .eval(code): arguments += ["--eval", code]
        case let .print(code): arguments += ["--print", code]
        case let .check(path): arguments += ["--check", path]
        case let .script(path): arguments.append(path)
        }
        arguments += state.scriptArguments

        let base = Command("node").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }
}

private enum Mode: Sendable {
    case version
    case eval(String)
    case print(String)
    case check(String)
    case script(String)
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var mode: Mode = .version
    var requires: [String] = []
    var inspects: Bool = false
    var watches: Bool = false
    var extraArguments: [String] = []
    var scriptArguments: [String] = []
}
#endif
