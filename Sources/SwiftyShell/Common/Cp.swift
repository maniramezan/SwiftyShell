import Foundation

/// A fluent wrapper for the `cp` command.
///
/// ```swift
/// // Copy a directory recursively
/// try await Cp(context: context)
///     .recursive()
///     .source("/path/to/source")
///     .destination("/path/to/dest")
///     .run()
/// ```
public struct Cp: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates a `cp` command family bound to a shell context.
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

    /// Redirects stdout for the built `cp` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `cp` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Enables recursive copying.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
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

    /// Builds the raw `cp` command.
    public func command() -> Command {
        var arguments: [String] = []

        if state.isRecursive {
            arguments.append("-R")
        }
        if state.forcesReplacement {
            arguments.append("-f")
        }

        arguments.append(contentsOf: state.sources)

        if let destinationPath = state.destinationPath {
            arguments.append(destinationPath)
        }

        let base = Command("cp")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isRecursive: Bool? = nil,
        forcesReplacement: Bool? = nil,
        sources: [String]? = nil,
        destinationPath: String?? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                isRecursive: isRecursive ?? state.isRecursive,
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
    let isRecursive: Bool
    let forcesReplacement: Bool
    let sources: [String]
    let destinationPath: String?

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isRecursive: Bool = false,
        forcesReplacement: Bool = false,
        sources: [String] = [],
        destinationPath: String? = nil
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isRecursive = isRecursive
        self.forcesReplacement = forcesReplacement
        self.sources = sources
        self.destinationPath = destinationPath
    }
}
