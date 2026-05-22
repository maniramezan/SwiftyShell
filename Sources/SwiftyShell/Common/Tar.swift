#if Tar
import Foundation

/// The compression program used by ``Tar`` when reading or writing archives.
///
/// Compression maps to the portable short flags accepted by BSD tar and GNU tar for common
/// formats. Use ``custom(_:)`` for less common programs that should be passed through
/// `--use-compress-program`.
///
/// ```swift
/// try await Tar(context: context)
///     .create()
///     .gzip()
///     .file("release.tar.gz")
///     .path("build")
///     .run()
/// ```
public enum TarCompression: Sendable, Equatable, Hashable {
    /// Use gzip compression (`-z`).
    case gzip
    /// Use bzip2 compression (`-j`).
    case bzip2
    /// Use xz compression (`-J`).
    case xz
    /// Ask tar to infer compression from the archive suffix (`-a`).
    case auto
    /// Use a custom compression program (`--use-compress-program <program>`).
    case custom(String)

    fileprivate var arguments: [String] {
        switch self {
        case .gzip: return ["-z"]
        case .bzip2: return ["-j"]
        case .xz: return ["-J"]
        case .auto: return ["-a"]
        case .custom(let program): return ["--use-compress-program", program]
        }
    }
}

/// The primary tar operation represented by ``Tar``.
///
/// Tar allows one primary operation per invocation. Calling operation helpers such as
/// ``Tar/create()`` or ``Tar/extract()`` replaces any previously selected operation.
public enum TarOperation: String, Sendable, Equatable, Hashable {
    /// Create a new archive (`-c`).
    case create = "-c"
    /// Extract entries from an archive (`-x`).
    case extract = "-x"
    /// List archive entries (`-t`).
    case list = "-t"
    /// Append files to an existing archive (`-r`).
    case append = "-r"
    /// Update an existing archive with newer file copies (`-u`).
    case update = "-u"
}

/// A fluent wrapper for the `tar` archive command.
///
/// ``Tar`` models the portable archive operations most useful for automation: create, extract,
/// list, append, update, compression, directory changes, filters, and overwrite behavior. The
/// builder produces argument-vector commands directly, so paths and patterns are never joined into
/// shell strings.
///
/// ```swift
/// try await Tar(context: context)
///     .create()
///     .gzip()
///     .file("/tmp/source.tar.gz")
///     .directory("/path/to/project")
///     .exclude(".build")
///     .path("Sources")
///     .path("Package.swift")
///     .run()
/// ```
public struct Tar: RunnableCommandFamily {
    private let state: TarState

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates a tar command family bound to a shell context.
    ///
    /// Configure an operation, archive file, paths, and any flags before calling ``run()`` or
    /// ``command()``.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = TarState(config: ToolConfiguration(context: context))
    }

    private init(state: TarState) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnels the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new ``Tar`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `tar` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Use this for list output or `toStdout()`
    /// extraction.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Tar`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `tar` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Tar writes diagnostics and some progress output
    /// on stderr depending on implementation and flags.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Tar`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that creates a new archive (`-c`).
    public func create() -> Self { operation(.create) }

    /// Returns a copy that extracts entries from an archive (`-x`).
    public func extract() -> Self { operation(.extract) }

    /// Returns a copy that lists archive entries (`-t`).
    public func list() -> Self { operation(.list) }

    /// Returns a copy that appends files to an existing archive (`-r`).
    public func append() -> Self { operation(.append) }

    /// Returns a copy that updates archive entries when source files are newer (`-u`).
    public func update() -> Self { operation(.update) }

    /// Returns a copy with the selected primary tar operation.
    ///
    /// - Parameter value: The operation to emit first in argv.
    /// - Returns: A new ``Tar`` value with the operation applied.
    public func operation(_ value: TarOperation) -> Self {
        copy(operation: .some(value))
    }

    /// Returns a copy that sets the archive file (`-f <archive>`).
    ///
    /// Calling this multiple times keeps the last value.
    ///
    /// - Parameter path: The archive path to read or write.
    /// - Returns: A new ``Tar`` value with the archive file set.
    public func file(_ path: String) -> Self {
        copy(archivePath: path)
    }

    /// Returns a copy with one input or member path appended.
    ///
    /// For create-like operations this names files to archive. For extract/list operations this
    /// narrows the archive members to operate on.
    ///
    /// - Parameter value: A filesystem path or archive member name.
    /// - Returns: A new ``Tar`` value with the path appended.
    public func path(_ value: String) -> Self {
        copy(paths: state.paths + [value])
    }

    /// Returns a copy with multiple input or member paths appended.
    ///
    /// - Parameter values: Paths or member names to append in order.
    /// - Returns: A new ``Tar`` value with the paths appended.
    public func paths(_ values: [String]) -> Self {
        copy(paths: state.paths + values)
    }

    /// Returns a copy that changes tar's directory before processing following paths (`-C`).
    ///
    /// Multiple directories are emitted in call order. Tar treats `-C` as position-sensitive
    /// during archive creation, so this builder emits directories before all paths.
    ///
    /// - Parameter path: Directory path to pass after `-C`.
    /// - Returns: A new ``Tar`` value with the directory appended.
    public func directory(_ path: String) -> Self {
        copy(directories: state.directories + [path])
    }

    /// Returns a copy that enables gzip compression (`-z`).
    public func gzip() -> Self { compression(.gzip) }

    /// Returns a copy that enables bzip2 compression (`-j`).
    public func bzip2() -> Self { compression(.bzip2) }

    /// Returns a copy that enables xz compression (`-J`).
    public func xz() -> Self { compression(.xz) }

    /// Returns a copy that asks tar to infer compression from the archive suffix (`-a`).
    public func autoCompress() -> Self { compression(.auto) }

    /// Returns a copy with the selected compression behavior.
    ///
    /// - Parameter value: The compression mode to apply, replacing any previous mode.
    /// - Returns: A new ``Tar`` value with the compression mode applied.
    public func compression(_ value: TarCompression) -> Self {
        copy(compression: .some(value))
    }

    /// Returns a copy that appends an exclude pattern (`--exclude <pattern>`).
    ///
    /// - Parameter pattern: A tar pattern to exclude.
    /// - Returns: A new ``Tar`` value with the exclude pattern appended.
    public func exclude(_ pattern: String) -> Self {
        copy(excludes: state.excludes + [pattern])
    }

    /// Returns a copy that appends multiple exclude patterns.
    ///
    /// - Parameter patterns: Exclude patterns to append in order.
    /// - Returns: A new ``Tar`` value with the exclude patterns appended.
    public func excludes(_ patterns: [String]) -> Self {
        copy(excludes: state.excludes + patterns)
    }

    /// Returns a copy that reads exclude patterns from a file (`-X <file>`).
    ///
    /// - Parameter path: File containing newline-delimited tar patterns.
    /// - Returns: A new ``Tar`` value with the exclude file appended.
    public func excludeFrom(_ path: String) -> Self {
        copy(excludeFiles: state.excludeFiles + [path])
    }

    /// Returns a copy that reads paths or members from a file (`-T <file>`).
    ///
    /// - Parameter path: File containing path names.
    /// - Returns: A new ``Tar`` value with the paths-from file appended.
    public func filesFrom(_ path: String) -> Self {
        copy(filesFrom: state.filesFrom + [path])
    }

    /// Returns a copy that treats `filesFrom` inputs as NUL-terminated (`--null`).
    ///
    /// - Parameter enabled: `true` to add `--null`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func nullTerminatedFiles(_ enabled: Bool = true) -> Self {
        copy(usesNullTerminatedFiles: enabled)
    }

    /// Returns a copy that strips leading path components during extraction (`--strip-components`).
    ///
    /// - Parameter count: Number of leading path components to remove.
    /// - Returns: A new ``Tar`` value with the strip count set.
    public func stripComponents(_ count: Int) -> Self {
        copy(stripComponents: count)
    }

    /// Returns a copy that extracts each member to stdout instead of the filesystem (`-O`).
    ///
    /// - Parameter enabled: `true` to add `-O`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func toStdout(_ enabled: Bool = true) -> Self {
        copy(outputsToStdout: enabled)
    }

    /// Returns a copy that enables verbose output (`-v`).
    ///
    /// - Parameter enabled: `true` to add `-v`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func verbose(_ enabled: Bool = true) -> Self {
        copy(isVerbose: enabled)
    }

    /// Returns a copy that verifies archive writes when creating archives (`-W`).
    ///
    /// - Parameter enabled: `true` to add `-W`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func verify(_ enabled: Bool = true) -> Self {
        copy(verifiesWrites: enabled)
    }

    /// Returns a copy that removes source files after adding them (`--remove-files`).
    ///
    /// - Parameter enabled: `true` to add `--remove-files`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func removeFilesAfterAdding(_ enabled: Bool = true) -> Self {
        copy(removesFilesAfterAdding: enabled)
    }

    /// Returns a copy that follows symlinks when archiving (`-h`).
    ///
    /// - Parameter enabled: `true` to add `-h`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func dereferenceSymlinks(_ enabled: Bool = true) -> Self {
        copy(dereferencesSymlinks: enabled)
    }

    /// Returns a copy that keeps absolute path names (`-P`).
    ///
    /// By default tar strips leading slashes for safety. Use this only when absolute archive
    /// member names are intentional.
    ///
    /// - Parameter enabled: `true` to add `-P`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func absoluteNames(_ enabled: Bool = true) -> Self {
        copy(usesAbsoluteNames: enabled)
    }

    /// Returns a copy that preserves permissions when extracting (`-p`).
    ///
    /// - Parameter enabled: `true` to add `-p`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func preservePermissions(_ enabled: Bool = true) -> Self {
        copy(preservesPermissions: enabled)
    }

    /// Returns a copy that preserves owner when extracting (`--same-owner`).
    ///
    /// - Parameter enabled: `true` to add `--same-owner`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func sameOwner(_ enabled: Bool = true) -> Self {
        copy(preservesOwner: enabled)
    }

    /// Returns a copy that avoids preserving owner when extracting (`--no-same-owner`).
    ///
    /// - Parameter enabled: `true` to add `--no-same-owner`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func noSameOwner(_ enabled: Bool = true) -> Self {
        copy(skipsOwnerPreservation: enabled)
    }

    /// Returns a copy that does not overwrite existing files while extracting (`-k`).
    ///
    /// - Parameter enabled: `true` to add `-k`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func keepOldFiles(_ enabled: Bool = true) -> Self {
        copy(keepsOldFiles: enabled)
    }

    /// Returns a copy that skips existing files while extracting (`--skip-old-files`).
    ///
    /// - Parameter enabled: `true` to add `--skip-old-files`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func skipOldFiles(_ enabled: Bool = true) -> Self {
        copy(skipsOldFiles: enabled)
    }

    /// Returns a copy that overwrites existing files while extracting (`--overwrite`).
    ///
    /// - Parameter enabled: `true` to add `--overwrite`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func overwrite(_ enabled: Bool = true) -> Self {
        copy(overwritesExistingFiles: enabled)
    }

    /// Returns a copy that omits recursion when archiving directories (`--no-recursion`).
    ///
    /// - Parameter enabled: `true` to add `--no-recursion`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func noRecursion(_ enabled: Bool = true) -> Self {
        copy(disablesRecursion: enabled)
    }

    /// Returns a copy that prevents crossing filesystem boundaries (`--one-file-system`).
    ///
    /// - Parameter enabled: `true` to add `--one-file-system`. Defaults to `true`.
    /// - Returns: A new ``Tar`` value with the flag applied.
    public func oneFileSystem(_ enabled: Bool = true) -> Self {
        copy(staysOnOneFileSystem: enabled)
    }

    /// Returns a copy that appends a raw tar option.
    ///
    /// Use this for less common implementation-specific flags while keeping the rest of the
    /// invocation typed.
    ///
    /// - Parameter value: A single argument to append before file and path operands.
    /// - Returns: A new ``Tar`` value with the raw option appended.
    public func option(_ value: String) -> Self {
        copy(extraOptions: state.extraOptions + [value])
    }

    /// Returns a copy that appends raw tar options.
    ///
    /// - Parameter values: Arguments to append before file and path operands.
    /// - Returns: A new ``Tar`` value with the raw options appended.
    public func options(_ values: [String]) -> Self {
        copy(extraOptions: state.extraOptions + values)
    }

    /// Builds the raw `tar` command represented by the current builder state.
    ///
    /// Argv is assembled deterministically as: operation -> behavior/compression/filter flags ->
    /// `-f <archive>` -> `-C <directory>` values -> path operands. Shared configuration is merged
    /// via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if let operation = state.operation {
            arguments.append(operation.rawValue)
        }

        if state.isVerbose { arguments.append("-v") }
        if state.verifiesWrites { arguments.append("-W") }
        if state.removesFilesAfterAdding { arguments.append("--remove-files") }
        if state.dereferencesSymlinks { arguments.append("-h") }
        if state.usesAbsoluteNames { arguments.append("-P") }
        if state.preservesPermissions { arguments.append("-p") }
        if state.preservesOwner { arguments.append("--same-owner") }
        if state.skipsOwnerPreservation { arguments.append("--no-same-owner") }
        if state.keepsOldFiles { arguments.append("-k") }
        if state.skipsOldFiles { arguments.append("--skip-old-files") }
        if state.overwritesExistingFiles { arguments.append("--overwrite") }
        if state.disablesRecursion { arguments.append("--no-recursion") }
        if state.staysOnOneFileSystem { arguments.append("--one-file-system") }
        if state.outputsToStdout { arguments.append("-O") }
        if state.usesNullTerminatedFiles { arguments.append("--null") }

        if let compression = state.compression {
            arguments.append(contentsOf: compression.arguments)
        }

        for pattern in state.excludes {
            arguments.append("--exclude")
            arguments.append(pattern)
        }

        for path in state.excludeFiles {
            arguments.append("-X")
            arguments.append(path)
        }

        for path in state.filesFrom {
            arguments.append("-T")
            arguments.append(path)
        }

        if let count = state.stripComponents {
            arguments.append("--strip-components")
            arguments.append(String(count))
        }

        arguments.append(contentsOf: state.extraOptions)

        if let archivePath = state.archivePath {
            arguments.append("-f")
            arguments.append(archivePath)
        }

        for directory in state.directories {
            arguments.append("-C")
            arguments.append(directory)
        }

        arguments.append(contentsOf: state.paths)

        let base = Command("tar")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        operation: TarOperation?? = nil,
        archivePath: String?? = nil,
        paths: [String]? = nil,
        directories: [String]? = nil,
        compression: TarCompression?? = nil,
        excludes: [String]? = nil,
        excludeFiles: [String]? = nil,
        filesFrom: [String]? = nil,
        stripComponents: Int?? = nil,
        outputsToStdout: Bool? = nil,
        isVerbose: Bool? = nil,
        verifiesWrites: Bool? = nil,
        removesFilesAfterAdding: Bool? = nil,
        dereferencesSymlinks: Bool? = nil,
        usesAbsoluteNames: Bool? = nil,
        preservesPermissions: Bool? = nil,
        preservesOwner: Bool? = nil,
        skipsOwnerPreservation: Bool? = nil,
        keepsOldFiles: Bool? = nil,
        skipsOldFiles: Bool? = nil,
        overwritesExistingFiles: Bool? = nil,
        disablesRecursion: Bool? = nil,
        staysOnOneFileSystem: Bool? = nil,
        usesNullTerminatedFiles: Bool? = nil,
        extraOptions: [String]? = nil
    ) -> Self {
        Self(
            state: TarState(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                operation: operation ?? state.operation,
                archivePath: archivePath ?? state.archivePath,
                paths: paths ?? state.paths,
                directories: directories ?? state.directories,
                compression: compression ?? state.compression,
                excludes: excludes ?? state.excludes,
                excludeFiles: excludeFiles ?? state.excludeFiles,
                filesFrom: filesFrom ?? state.filesFrom,
                stripComponents: stripComponents ?? state.stripComponents,
                outputsToStdout: outputsToStdout ?? state.outputsToStdout,
                isVerbose: isVerbose ?? state.isVerbose,
                verifiesWrites: verifiesWrites ?? state.verifiesWrites,
                removesFilesAfterAdding: removesFilesAfterAdding ?? state.removesFilesAfterAdding,
                dereferencesSymlinks: dereferencesSymlinks ?? state.dereferencesSymlinks,
                usesAbsoluteNames: usesAbsoluteNames ?? state.usesAbsoluteNames,
                preservesPermissions: preservesPermissions ?? state.preservesPermissions,
                preservesOwner: preservesOwner ?? state.preservesOwner,
                skipsOwnerPreservation: skipsOwnerPreservation ?? state.skipsOwnerPreservation,
                keepsOldFiles: keepsOldFiles ?? state.keepsOldFiles,
                skipsOldFiles: skipsOldFiles ?? state.skipsOldFiles,
                overwritesExistingFiles: overwritesExistingFiles ?? state.overwritesExistingFiles,
                disablesRecursion: disablesRecursion ?? state.disablesRecursion,
                staysOnOneFileSystem: staysOnOneFileSystem ?? state.staysOnOneFileSystem,
                usesNullTerminatedFiles: usesNullTerminatedFiles ?? state.usesNullTerminatedFiles,
                extraOptions: extraOptions ?? state.extraOptions
            )
        )
    }
}

private struct TarState: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let operation: TarOperation?
    let archivePath: String?
    let paths: [String]
    let directories: [String]
    let compression: TarCompression?
    let excludes: [String]
    let excludeFiles: [String]
    let filesFrom: [String]
    let stripComponents: Int?
    let outputsToStdout: Bool
    let isVerbose: Bool
    let verifiesWrites: Bool
    let removesFilesAfterAdding: Bool
    let dereferencesSymlinks: Bool
    let usesAbsoluteNames: Bool
    let preservesPermissions: Bool
    let preservesOwner: Bool
    let skipsOwnerPreservation: Bool
    let keepsOldFiles: Bool
    let skipsOldFiles: Bool
    let overwritesExistingFiles: Bool
    let disablesRecursion: Bool
    let staysOnOneFileSystem: Bool
    let usesNullTerminatedFiles: Bool
    let extraOptions: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        operation: TarOperation? = nil,
        archivePath: String? = nil,
        paths: [String] = [],
        directories: [String] = [],
        compression: TarCompression? = nil,
        excludes: [String] = [],
        excludeFiles: [String] = [],
        filesFrom: [String] = [],
        stripComponents: Int? = nil,
        outputsToStdout: Bool = false,
        isVerbose: Bool = false,
        verifiesWrites: Bool = false,
        removesFilesAfterAdding: Bool = false,
        dereferencesSymlinks: Bool = false,
        usesAbsoluteNames: Bool = false,
        preservesPermissions: Bool = false,
        preservesOwner: Bool = false,
        skipsOwnerPreservation: Bool = false,
        keepsOldFiles: Bool = false,
        skipsOldFiles: Bool = false,
        overwritesExistingFiles: Bool = false,
        disablesRecursion: Bool = false,
        staysOnOneFileSystem: Bool = false,
        usesNullTerminatedFiles: Bool = false,
        extraOptions: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.operation = operation
        self.archivePath = archivePath
        self.paths = paths
        self.directories = directories
        self.compression = compression
        self.excludes = excludes
        self.excludeFiles = excludeFiles
        self.filesFrom = filesFrom
        self.stripComponents = stripComponents
        self.outputsToStdout = outputsToStdout
        self.isVerbose = isVerbose
        self.verifiesWrites = verifiesWrites
        self.removesFilesAfterAdding = removesFilesAfterAdding
        self.dereferencesSymlinks = dereferencesSymlinks
        self.usesAbsoluteNames = usesAbsoluteNames
        self.preservesPermissions = preservesPermissions
        self.preservesOwner = preservesOwner
        self.skipsOwnerPreservation = skipsOwnerPreservation
        self.keepsOldFiles = keepsOldFiles
        self.skipsOldFiles = skipsOldFiles
        self.overwritesExistingFiles = overwritesExistingFiles
        self.disablesRecursion = disablesRecursion
        self.staysOnOneFileSystem = staysOnOneFileSystem
        self.usesNullTerminatedFiles = usesNullTerminatedFiles
        self.extraOptions = extraOptions
    }
}
#endif
