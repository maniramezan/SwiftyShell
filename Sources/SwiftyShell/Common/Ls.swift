#if Ls
import Foundation

/// A fluent wrapper for the `ls` command.
///
/// Use ``Ls`` when you need a typed builder for directory listings. The command returns raw
/// ``ShellOutput``; read `stdout` to display or parse the listing.
///
/// ```swift
/// let output = try await Ls(context: context)
///     .all()              // Include hidden files.
///     .longFormat()       // Include permissions, owner, size, and timestamps.
///     .humanReadable()    // Format sizes with units such as K, M, or G.
///     .path("/tmp")
///     .run()
///
/// print(output.stdout)
/// ```
public struct Ls: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates an `ls` command family bound to a shell context.
    ///
    /// All builder state starts empty. With no paths configured, `ls` lists the current working
    /// directory; supply paths with ``path(_:)`` or ``paths(_:)`` to override.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = State(config: ToolConfiguration(context: context))
    }

    private init(state: State) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Ls`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `ls` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Stdout is the listing itself, so this is the
    /// stream most callers will inspect.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Ls`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `ls` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `ls` writes diagnostics here when a path
    /// cannot be read.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Ls`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that includes hidden entries (those whose names start with `.`) in the
    /// listing.
    ///
    /// Maps to the `-a` flag.
    ///
    /// - Parameter enabled: `true` to add `-a`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func all(_ enabled: Bool = true) -> Self {
        copy(showsAllFiles: enabled)
    }

    /// Returns a copy that uses the long listing format (permissions, owner, size, timestamps).
    ///
    /// Maps to the `-l` flag. Pair with ``humanReadable(_:)`` to format sizes with K/M/G suffixes.
    ///
    /// - Parameter enabled: `true` to add `-l`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func longFormat(_ enabled: Bool = true) -> Self {
        copy(usesLongFormat: enabled)
    }

    /// Returns a copy that formats sizes in the long listing format with unit suffixes.
    ///
    /// Maps to the `-h` flag. Has no visible effect unless combined with ``longFormat(_:)``.
    ///
    /// - Parameter enabled: `true` to add `-h`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func humanReadable(_ enabled: Bool = true) -> Self {
        copy(usesHumanReadableSizes: enabled)
    }

    /// Returns a copy that lists directory contents recursively.
    ///
    /// Maps to the `-R` flag. Output may be very large for deep trees; consider combining with
    /// ``outputLimit(_:)`` or routing stdout to ``OutputDestination/file(path:append:)``.
    ///
    /// - Parameter enabled: `true` to add `-R`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
    }

    /// Returns a copy that treats directory paths as plain entries instead of listing their
    /// contents.
    ///
    /// Maps to the `-d` flag. Useful when you want metadata about the directory itself rather
    /// than its children.
    ///
    /// - Parameter enabled: `true` to add `-d`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func directoryAsFile(_ enabled: Bool = true) -> Self {
        copy(treatsDirectoriesAsFiles: enabled)
    }

    /// Returns a copy with one additional path appended for listing.
    ///
    /// Each path becomes a separate argument; with no paths configured, `ls` lists the current
    /// working directory.
    ///
    /// - Parameter value: The directory or file path to list.
    /// - Returns: A new ``Ls`` value with the path appended.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Returns a copy with multiple paths appended for listing.
    ///
    /// - Parameter values: The paths to append, in order.
    /// - Returns: A new ``Ls`` value with the paths appended.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Builds the raw `ls` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: flags (`-a`, `-l`, `-h`, `-R`, `-d`), then paths. The
    /// shared ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
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

        if !state.paths.isEmpty { arguments.append("--") }
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
