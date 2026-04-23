#if Ls
import Foundation

/// A fluent wrapper for the `ls` command.
///
/// ```swift
/// // List all files including hidden ones, in long format
/// let output = try await Ls(context: context)
///     .all()
///     .longFormat()
///     .humanReadable()
///     .path("/tmp")
///     .run()
/// print(output.stdout)
/// ```
public struct Ls: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    public var context: ShellContext { state.config.context }

    /// Creates an `ls` command family bound to a shell context.
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

    /// Redirects stdout for the built `ls` command.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Redirects stderr for the built `ls` command.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Includes hidden files in the listing.
    public func all(_ enabled: Bool = true) -> Self {
        copy(showsAllFiles: enabled)
    }

    /// Uses long listing format.
    public func longFormat(_ enabled: Bool = true) -> Self {
        copy(usesLongFormat: enabled)
    }

    /// Uses human-readable file sizes.
    public func humanReadable(_ enabled: Bool = true) -> Self {
        copy(usesHumanReadableSizes: enabled)
    }

    /// Lists directory contents recursively.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
    }

    /// Treats directories as plain entries instead of listing their contents.
    public func directoryAsFile(_ enabled: Bool = true) -> Self {
        copy(treatsDirectoriesAsFiles: enabled)
    }

    /// Appends a path to list.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Appends multiple paths to list.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the raw `ls` command.
    public func command() -> Command {
        var arguments: [String] = []

        if state.showsAllFiles {
            arguments.append("-a")
        }
        if state.usesLongFormat {
            arguments.append("-l")
        }
        if state.usesHumanReadableSizes {
            arguments.append("-h")
        }
        if state.isRecursive {
            arguments.append("-R")
        }
        if state.treatsDirectoriesAsFiles {
            arguments.append("-d")
        }

        arguments.append(contentsOf: state.paths)

        let base = Command("ls")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        showsAllFiles: Bool? = nil,
        usesLongFormat: Bool? = nil,
        usesHumanReadableSizes: Bool? = nil,
        isRecursive: Bool? = nil,
        treatsDirectoriesAsFiles: Bool? = nil,
        paths: [String]? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                showsAllFiles: showsAllFiles ?? state.showsAllFiles,
                usesLongFormat: usesLongFormat ?? state.usesLongFormat,
                usesHumanReadableSizes: usesHumanReadableSizes ?? state.usesHumanReadableSizes,
                isRecursive: isRecursive ?? state.isRecursive,
                treatsDirectoriesAsFiles: treatsDirectoriesAsFiles ?? state.treatsDirectoriesAsFiles,
                paths: paths ?? state.paths
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let showsAllFiles: Bool
    let usesLongFormat: Bool
    let usesHumanReadableSizes: Bool
    let isRecursive: Bool
    let treatsDirectoriesAsFiles: Bool
    let paths: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        showsAllFiles: Bool = false,
        usesLongFormat: Bool = false,
        usesHumanReadableSizes: Bool = false,
        isRecursive: Bool = false,
        treatsDirectoriesAsFiles: Bool = false,
        paths: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.showsAllFiles = showsAllFiles
        self.usesLongFormat = usesLongFormat
        self.usesHumanReadableSizes = usesHumanReadableSizes
        self.isRecursive = isRecursive
        self.treatsDirectoriesAsFiles = treatsDirectoriesAsFiles
        self.paths = paths
    }
}
#endif
