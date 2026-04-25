#if Mv
import Foundation

/// A fluent wrapper for the `mv` command.
///
/// Use ``Mv`` to move or rename files and directories. Successful moves usually produce no output,
/// so completion is the result; multiple sources require the destination to be a directory.
///
/// ```swift
/// try await Mv(context: context)
///     .source("/tmp/output.txt")
///     .destination("/var/logs/output.txt")
///     .run()
/// ```
public struct Mv: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates an `mv` command family bound to a shell context.
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

    /// Redirects stdout for the built `mv` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `mv` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Forces replacement of existing destinations.
    public func force(_ enabled: Bool = true) -> Self {
        copy(forcesReplacement: enabled)
    }

    /// Appends a source path.
    public func source(_ path: String) -> Self {
        copy(sources: state.sources + [path])
    }

    /// Appends multiple source paths.
    public func sources(_ paths: [String]) -> Self {
        copy(sources: state.sources + paths)
    }

    /// Sets the destination path.
    public func destination(_ path: String) -> Self {
        copy(destinationPath: path)
    }

    /// Builds the raw `mv` command.
    public func command() -> Command {
        var arguments: [String] = []

        if state.forcesReplacement {
            arguments.append("-f")
        }

        arguments.append(contentsOf: state.sources)

        if let destinationPath = state.destinationPath {
            arguments.append(destinationPath)
        }

        let base = Command("mv")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        forcesReplacement: Bool? = nil,
        sources: [String]? = nil,
        destinationPath: String?? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                forcesReplacement: forcesReplacement ?? state.forcesReplacement,
                sources: sources ?? state.sources,
                destinationPath: destinationPath ?? state.destinationPath
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let forcesReplacement: Bool
    let sources: [String]
    let destinationPath: String?

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        forcesReplacement: Bool = false,
        sources: [String] = [],
        destinationPath: String? = nil
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.forcesReplacement = forcesReplacement
        self.sources = sources
        self.destinationPath = destinationPath
    }
}
#endif
