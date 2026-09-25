#if Python
import Foundation

/// A fluent wrapper for the Python interpreter CLI (`python3` by default).
///
/// ``Python`` is for script orchestration, not embedded Python interop. It
/// models common interpreter modes such as `-m`, `-c`, and script execution.
///
/// ```swift
/// try await Python()
///     .module("http.server")
///     .argument("8080")
///     .run()
/// ```
public struct Python: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a Python command family bound to a shell context.
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

    /// Returns a copy that prints Python version information with `--version`.
    public func version() -> Self {
        modified(self) {
            $0.state.mode = .version
            $0.state.arguments = []
        }
    }

    /// Returns a copy that runs a module with `-m <name>`.
    public func module(_ name: String) -> Self {
        modified(self) {
            $0.state.mode = .module(name)
            $0.state.arguments = []
        }
    }

    /// Returns a copy that runs code with `-c <code>`.
    public func commandString(_ code: String) -> Self {
        modified(self) {
            $0.state.mode = .command(code)
            $0.state.arguments = []
        }
    }

    /// Returns a copy that runs a Python script path.
    public func script(_ path: String) -> Self {
        modified(self) {
            $0.state.mode = .script(path)
            $0.state.arguments = []
        }
    }

    /// Returns a copy that passes `-I` for isolated mode.
    public func isolated(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isolatedEnabled = enabled } }

    /// Returns a copy that passes `-u` for unbuffered binary stdout and stderr.
    public func unbuffered(_ enabled: Bool = true) -> Self { modified(self) { $0.state.unbufferedEnabled = enabled } }

    /// Returns a copy that passes `-B` to avoid writing `.pyc` files.
    public func dontWriteBytecode(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.dontWriteBytecodeEnabled = enabled }
    }

    /// Returns a copy that appends `-O` optimization flags.
    public func optimize(_ level: Int = 1) -> Self { modified(self) { $0.state.optimizationLevel = level } }

    /// Returns a copy that appends a raw interpreter option before the mode.
    public func option(_ value: String) -> Self { modified(self) { $0.state.extraOptions += [value] } }

    /// Returns a copy that appends raw interpreter options before the mode.
    public func options(_ values: [String]) -> Self { modified(self) { $0.state.extraOptions += values } }

    /// Returns a copy that appends an argument for the selected module, command, or script.
    public func argument(_ value: String) -> Self { modified(self) { $0.state.arguments += [value] } }

    /// Returns a copy that appends arguments for the selected module, command, or script.
    public func arguments(_ values: [String]) -> Self { modified(self) { $0.state.arguments += values } }

    /// Builds the raw `python3` command represented by the current builder state.
    public func command() -> Command {
        var arguments: [String] = []
        if state.isolatedEnabled { arguments.append("-I") }
        if state.unbufferedEnabled { arguments.append("-u") }
        if state.dontWriteBytecodeEnabled { arguments.append("-B") }
        for _ in 0..<max(0, state.optimizationLevel) { arguments.append("-O") }
        arguments += state.extraOptions
        switch state.mode {
        case .version: arguments.append("--version")
        case let .module(name): arguments += ["-m", name]
        case let .command(code): arguments += ["-c", code]
        case let .script(path): arguments.append(path)
        }
        arguments += state.arguments
        let base = Command("python3").args(arguments).stdout(state.stdoutDestination).stderr(state.stderrDestination)
        return state.config.apply(to: base)
    }
}

private enum Mode: Sendable {
    case version
    case module(String)
    case command(String)
    case script(String)
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var mode: Mode = .version
    var isolatedEnabled: Bool = false
    var unbufferedEnabled: Bool = false
    var dontWriteBytecodeEnabled: Bool = false
    var optimizationLevel: Int = 0
    var extraOptions: [String] = []
    var arguments: [String] = []
}
#endif
