#if Zip
import Foundation

/// The compression strength applied by ``Zip`` when packing entries.
///
/// Maps to the `-0` … `-9` numeric flags accepted by Info-ZIP's `zip` binary. ``store`` produces
/// an uncompressed archive (fastest, largest output); ``best`` applies maximum DEFLATE
/// compression (slowest, smallest output). Use ``custom(_:)`` only when you have a specific
/// numeric level in mind — values are clamped to `0…9` when the command is built.
///
/// ```swift
/// try await Zip(context: context)
///     .compressionLevel(.best)
///     .archive("/tmp/release.zip")
///     .path("build/")
///     .recursive()
///     .run()
/// ```
public enum ZipCompressionLevel: Sendable, Equatable, Hashable {
    /// No compression — `-0`. Equivalent to bundling files into a non-compressed container.
    case store
    /// Fastest compression with minimal CPU cost — `-1`.
    case fastest
    /// Info-ZIP's default compression level — `-6`. Balanced speed and ratio.
    case `default`
    /// Maximum compression — `-9`. Slowest, smallest output.
    case best
    /// A specific numeric level. Values outside `0…9` are clamped at command-build time.
    case custom(Int)

    fileprivate var flag: String {
        switch self {
        case .store: return "-0"
        case .fastest: return "-1"
        case .default: return "-6"
        case .best: return "-9"
        case .custom(let raw):
            let clamped = max(0, min(9, raw))
            return "-\(clamped)"
        }
    }
}

/// A fluent wrapper for the Info-ZIP `zip` command.
///
/// Use ``Zip`` to build, update, or modify `.zip` archives with a typed builder. The same API
/// works on macOS (where `zip` ships by default) and on Linux distributions that have the
/// `zip` package installed; flag semantics are identical because both targets ship the Info-ZIP
/// implementation.
///
/// ```swift
/// // Create a recursive archive of a build directory at maximum compression.
/// try await Zip(context: context)
///     .recursive()
///     .compressionLevel(.best)
///     .archive("/tmp/release.zip")
///     .path("build/")
///     .run()
/// ```
///
/// `zip` writes diagnostic progress to stderr by default. Pass ``quiet(_:)`` to suppress it,
/// or redirect via ``stderr(_:)`` and ``stdout(_:)`` from
/// ``OutputRedirectingCommandFamily``.
///
/// > Important: ``password(_:)`` puts the password directly on the subprocess argv, where it
/// > may be visible to other users via `ps`. For ad-hoc use this is acceptable; for sensitive
/// > workloads prefer ``encryptInteractive(_:)`` so `zip` prompts on stdin instead.
public struct Zip: RunnableCommandFamily {
    private var state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a `zip` command family bound to a shell context.
    ///
    /// All builder state starts empty: no archive, no input paths, no flags. Configure the
    /// archive, paths, compression, and any flags before calling ``run()`` or ``command()``.
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
    /// Funnels the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)-(Duration)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new ``Zip`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `zip` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `zip` writes summary progress on stdout when
    /// not in quiet mode.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Zip`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `zip` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `zip` writes warnings (missing files, skipped
    /// entries, encryption prompts) on stderr.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Zip`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that sets the destination archive path.
    ///
    /// Calling this multiple times keeps the last value. The archive path is required for any
    /// non-empty `zip` invocation.
    ///
    /// - Parameter path: The output archive path (typically ending in `.zip`).
    /// - Returns: A new ``Zip`` value with the archive set.
    public func archive(_ path: String) -> Self {
        modified(self) { $0.state.archivePath = path }
    }

    /// Returns a copy with one additional input path appended.
    ///
    /// Inputs are forwarded to `zip` after the archive in declaration order. When packaging a
    /// directory, also enable ``recursive(_:)``.
    ///
    /// - Parameter value: A file or directory path to include in the archive.
    /// - Returns: A new ``Zip`` value with the path appended.
    public func path(_ value: String) -> Self {
        modified(self) { $0.state.paths += [value] }
    }

    /// Returns a copy with multiple input paths appended.
    ///
    /// - Parameter values: The input paths to append, in order.
    /// - Returns: A new ``Zip`` value with the paths appended.
    public func paths(_ values: [String]) -> Self {
        modified(self) { $0.state.paths += values }
    }

    /// Returns a copy that toggles the update mode (`-u`).
    ///
    /// In update mode `zip` adds new entries and replaces existing entries that have a newer
    /// timestamp than the copy in the archive. Update, ``freshen(_:)``, and ``delete(_:)`` are
    /// mutually exclusive; the last one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-u`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func update(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.operation = toggledMode(state.operation, .update, enabled: enabled) }
    }

    /// Returns a copy that toggles the freshen mode (`-f`).
    ///
    /// Freshen mode replaces entries that have a newer timestamp than the archive copy without
    /// adding new files. Mutually exclusive with ``update(_:)`` and ``delete(_:)``; the last one
    /// enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-f`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func freshen(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.operation = toggledMode(state.operation, .freshen, enabled: enabled) }
    }

    /// Returns a copy that toggles the delete mode (`-d`).
    ///
    /// In delete mode the named entries are removed from an existing archive. Mutually exclusive
    /// with ``update(_:)`` and ``freshen(_:)``; the last one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-d`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func delete(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.operation = toggledMode(state.operation, .delete, enabled: enabled) }
    }

    /// Returns a copy that toggles the move mode (`-m`).
    ///
    /// Move mode adds the named files to the archive, then deletes them from the working tree
    /// once the archive has been written successfully.
    ///
    /// - Parameter enabled: `true` to add `-m`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func move(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.modeMove = enabled }
    }

    /// Returns a copy that toggles recursive directory traversal (`-r`).
    ///
    /// Required when any input path is a directory; without it `zip` archives only the
    /// directory entry itself, not its contents.
    ///
    /// - Parameter enabled: `true` to add `-r`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func recursive(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isRecursive = enabled }
    }

    /// Returns a copy that toggles quiet mode (`-q`).
    ///
    /// Suppresses informational messages on stdout/stderr.
    ///
    /// - Parameter enabled: `true` to add `-q`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func quiet(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isQuiet = enabled }
    }

    /// Returns a copy that toggles verbose mode (`-v`).
    ///
    /// Emits per-entry progress lines on stdout.
    ///
    /// - Parameter enabled: `true` to add `-v`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func verbose(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isVerbose = enabled }
    }

    /// Returns a copy that toggles junked paths (`-j`).
    ///
    /// With this flag `zip` records only the file's base name, dropping any directory prefix.
    ///
    /// - Parameter enabled: `true` to add `-j`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func junkPaths(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.junksPaths = enabled }
    }

    /// Returns a copy that toggles symlink storage (`-y`).
    ///
    /// When enabled `zip` stores symlink entries verbatim instead of following them and
    /// archiving the target.
    ///
    /// - Parameter enabled: `true` to add `-y`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func storeSymlinks(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.storesSymlinks = enabled }
    }

    /// Returns a copy that strips nonessential extra fields from archive entries (`-X` / `--no-extra`).
    ///
    /// Info-ZIP retains only the extra fields needed to extract entries, producing a more portable
    /// archive and omitting platform-specific metadata. This does not preserve permissions.
    ///
    /// - Parameter enabled: `true` to add `-X`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func stripExtraFields(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.stripsExtraFields = enabled }
    }

    /// Returns a copy that toggles interactive encryption (`-e`).
    ///
    /// `zip -e` prompts on stdin for a password. SwiftyShell does not feed stdin, so this is
    /// only suitable for terminal-driven flows where the user can answer the prompt directly.
    /// For unattended use see ``password(_:)``.
    ///
    /// - Parameter enabled: `true` to add `-e`. Defaults to `true`.
    /// - Returns: A new ``Zip`` value with the flag applied.
    public func encryptInteractive(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.encryptsInteractively = enabled }
    }

    /// Returns a copy that pins the compression level.
    ///
    /// See ``ZipCompressionLevel`` for the mapping to `zip`'s numeric flags.
    ///
    /// - Parameter level: The desired compression strength.
    /// - Returns: A new ``Zip`` value with the level applied.
    public func compressionLevel(_ level: ZipCompressionLevel) -> Self {
        modified(self) { $0.state.compressionLevel = level }
    }

    /// Returns a copy that splits the archive into chunks of `value` size (`-s <size>`).
    ///
    /// The string is forwarded verbatim to `zip`, which accepts suffixes such as `1m`, `100k`,
    /// `1g`. Chunked output produces files like `archive.z01`, `archive.z02`, …, `archive.zip`.
    ///
    /// - Parameter value: The split size string (e.g. `"100m"`).
    /// - Returns: A new ``Zip`` value with the split size applied.
    public func splitSize(_ value: String) -> Self {
        modified(self) { $0.state.splitSize = value }
    }

    /// Returns a copy that supplies a password on the command line (`-P <password>`).
    ///
    /// > Warning: The password is visible to other users on the system via `ps` because it is
    /// > placed on the subprocess argv. Use ``encryptInteractive(_:)`` when running in a
    /// > context where stdin can answer the prompt.
    ///
    /// - Parameter value: The password string to forward to `zip`.
    /// - Returns: A new ``Zip`` value with the password applied.
    public func password(_ value: String) -> Self {
        modified(self) { $0.state.password = value }
    }

    /// Returns a copy with one include pattern appended (`-i <pattern>`).
    ///
    /// Include patterns are positional and are emitted after the input paths.
    ///
    /// - Parameter pattern: A glob pattern such as `"*.swift"`.
    /// - Returns: A new ``Zip`` value with the include pattern appended.
    public func include(_ pattern: String) -> Self {
        modified(self) { $0.state.includes += [pattern] }
    }

    /// Returns a copy with multiple include patterns appended.
    ///
    /// - Parameter patterns: Glob patterns to append in order.
    /// - Returns: A new ``Zip`` value with the include patterns appended.
    public func includes(_ patterns: [String]) -> Self {
        modified(self) { $0.state.includes += patterns }
    }

    /// Returns a copy with one exclude pattern appended (`-x <pattern>`).
    ///
    /// Exclude patterns are positional and are emitted after include patterns.
    ///
    /// - Parameter pattern: A glob pattern such as `"*.tmp"`.
    /// - Returns: A new ``Zip`` value with the exclude pattern appended.
    public func exclude(_ pattern: String) -> Self {
        modified(self) { $0.state.excludes += [pattern] }
    }

    /// Returns a copy with multiple exclude patterns appended.
    ///
    /// - Parameter patterns: Glob patterns to append in order.
    /// - Returns: A new ``Zip`` value with the exclude patterns appended.
    public func excludes(_ patterns: [String]) -> Self {
        modified(self) { $0.state.excludes += patterns }
    }

    /// Builds the raw `zip` command represented by the current builder state.
    ///
    /// Argv is assembled deterministically as: mode flags → common flags → compression level →
    /// `-s <size>` → `-P <password>` → archive → input paths → `-i <includes>` →
    /// `-x <excludes>`. The shared ``ToolConfiguration`` overrides are merged via
    /// ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if let operation = state.operation { arguments.append(operation.flag) }
        if state.modeMove { arguments.append("-m") }

        if state.isRecursive { arguments.append("-r") }
        if state.isQuiet { arguments.append("-q") }
        if state.isVerbose { arguments.append("-v") }
        if state.junksPaths { arguments.append("-j") }
        if state.storesSymlinks { arguments.append("-y") }
        if state.stripsExtraFields { arguments.append("-X") }
        if state.encryptsInteractively { arguments.append("-e") }

        if let level = state.compressionLevel {
            arguments.append(level.flag)
        }

        if let split = state.splitSize {
            arguments.append("-s")
            arguments.append(split)
        }

        if let password = state.password {
            arguments.append("-P")
            arguments.append(password)
        }

        if let archivePath = state.archivePath {
            arguments.append(archivePath)
        }

        arguments.append(contentsOf: state.paths)

        if !state.includes.isEmpty {
            arguments.append("-i")
            arguments.append(contentsOf: state.includes)
        }

        if !state.excludes.isEmpty {
            arguments.append("-x")
            arguments.append(contentsOf: state.excludes)
        }

        let base = Command("zip")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }
}

/// The mutually exclusive archive operations; `nil` means the default add operation.
private enum ZipOperation: Sendable, Equatable {
    case update
    case freshen
    case delete

    var flag: String {
        switch self {
        case .update: "-u"
        case .freshen: "-f"
        case .delete: "-d"
        }
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var archivePath: String? = nil
    var paths: [String] = []
    var operation: ZipOperation? = nil
    var modeMove: Bool = false
    var isRecursive: Bool = false
    var isQuiet: Bool = false
    var isVerbose: Bool = false
    var junksPaths: Bool = false
    var storesSymlinks: Bool = false
    var stripsExtraFields: Bool = false
    var encryptsInteractively: Bool = false
    var compressionLevel: ZipCompressionLevel? = nil
    var splitSize: String? = nil
    var password: String? = nil
    var includes: [String] = []
    var excludes: [String] = []
}
#endif
