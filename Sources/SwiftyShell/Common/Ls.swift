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
    private var state: State

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
    /// ``workingDirectory(_:)``, ``timeout(_:)-(Duration)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Ls`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `ls` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Stdout is the listing itself, so this is the
    /// stream most callers will inspect.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Ls`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `ls` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `ls` writes diagnostics here when a path
    /// cannot be read.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Ls`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that includes hidden entries (those whose names start with `.`) in the
    /// listing.
    ///
    /// Maps to the `-a` flag.
    ///
    /// - Parameter enabled: `true` to add `-a`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func all(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.showsAllFiles = enabled }
    }

    /// Returns a copy that uses the long listing format (permissions, owner, size, timestamps).
    ///
    /// Maps to the `-l` flag. Pair with ``humanReadable(_:)`` to format sizes with K/M/G suffixes.
    ///
    /// - Parameter enabled: `true` to add `-l`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func longFormat(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.usesLongFormat = enabled }
    }

    /// Returns a copy that formats sizes in the long listing format with unit suffixes.
    ///
    /// Maps to the `-h` flag. Has no visible effect unless combined with ``longFormat(_:)``.
    ///
    /// - Parameter enabled: `true` to add `-h`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func humanReadable(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.usesHumanReadableSizes = enabled }
    }

    /// Returns a copy that lists directory contents recursively.
    ///
    /// Maps to the `-R` flag. Output may be very large for deep trees; consider combining with
    /// ``outputLimit(_:)`` or routing stdout to ``OutputDestination/file(path:append:)``.
    ///
    /// - Parameter enabled: `true` to add `-R`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Ls`` value with the flag applied.
    public func recursive(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isRecursive = enabled }
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
        modified(self) { $0.state.treatsDirectoriesAsFiles = enabled }
    }

    /// Returns a copy with one additional path appended for listing.
    ///
    /// Each path becomes a separate argument; with no paths configured, `ls` lists the current
    /// working directory.
    ///
    /// - Parameter value: The directory or file path to list.
    /// - Returns: A new ``Ls`` value with the path appended.
    public func path(_ value: String) -> Self {
        modified(self) { $0.state.paths += [value] }
    }

    /// Returns a copy with multiple paths appended for listing.
    ///
    /// - Parameter values: The paths to append, in order.
    /// - Returns: A new ``Ls`` value with the paths appended.
    public func paths(_ values: [String]) -> Self {
        modified(self) { $0.state.paths += values }
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
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var showsAllFiles: Bool = false
    var usesLongFormat: Bool = false
    var usesHumanReadableSizes: Bool = false
    var isRecursive: Bool = false
    var treatsDirectoriesAsFiles: Bool = false
    var paths: [String] = []
}
#endif
