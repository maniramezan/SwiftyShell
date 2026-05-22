#if Rsync
import Foundation

/// A fluent wrapper for the `rsync` file synchronization command.
///
/// ``Rsync`` models common local and remote synchronization workflows: archive or recursive
/// copies, dry runs, deletion, filters, SSH transport configuration, bandwidth limits, and source
/// and destination operands. It builds argv directly, so paths and remote specs are passed as
/// individual arguments instead of being interpolated into a shell command.
///
/// ```swift
/// try await Rsync(context: context)
///     .archive()
///     .compress()
///     .delete()
///     .exclude(".build")
///     .source("/path/to/project/")
///     .destination("deploy@example.com:/srv/project/")
///     .run()
/// ```
public struct Rsync: RunnableCommandFamily {
    private let state: RsyncState

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates an rsync command family bound to a shell context.
    ///
    /// Configure sources, destination, and flags before calling ``run()`` or ``command()``.
    ///
    /// - Parameter context: The shell context whose executor, search paths, environment, and
    ///   defaults will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(context: ShellContext = .init()) {
        self.state = RsyncState(config: ToolConfiguration(context: context))
    }

    private init(state: RsyncState) {
        self.state = state
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnels the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new ``Rsync`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `rsync` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Rsync writes itemized changes, progress, and
    /// list output to stdout depending on the selected flags.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Rsync`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `rsync` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Rsync`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that enables archive mode (`-a`).
    public func archive(_ enabled: Bool = true) -> Self { copy(isArchive: enabled) }

    /// Returns a copy that enables recursive directory traversal (`-r`).
    public func recursive(_ enabled: Bool = true) -> Self { copy(isRecursive: enabled) }

    /// Returns a copy that enables compression during transfer (`-z`).
    public func compress(_ enabled: Bool = true) -> Self { copy(usesCompression: enabled) }

    /// Returns a copy that increases verbosity (`-v`).
    public func verbose(_ enabled: Bool = true) -> Self { copy(isVerbose: enabled) }

    /// Returns a copy that suppresses non-error messages (`-q`).
    public func quiet(_ enabled: Bool = true) -> Self { copy(isQuiet: enabled) }

    /// Returns a copy that performs a trial run without changing files (`-n`).
    public func dryRun(_ enabled: Bool = true) -> Self { copy(isDryRun: enabled) }

    /// Returns a copy that skips based on checksum instead of size and modification time (`-c`).
    public func checksum(_ enabled: Bool = true) -> Self { copy(usesChecksum: enabled) }

    /// Returns a copy that skips files newer on the receiver (`-u`).
    public func update(_ enabled: Bool = true) -> Self { copy(updatesOnlyOlderFiles: enabled) }

    /// Returns a copy that deletes extraneous destination files (`--delete`).
    public func delete(_ enabled: Bool = true) -> Self { copy(deletesExtraneousFiles: enabled) }

    /// Returns a copy that also deletes excluded files from destination directories.
    public func deleteExcluded(_ enabled: Bool = true) -> Self { copy(deletesExcludedFiles: enabled) }

    /// Returns a copy that preserves symbolic links as symbolic links (`-l`).
    public func links(_ enabled: Bool = true) -> Self { copy(preservesLinks: enabled) }

    /// Returns a copy that follows symlinks and copies referent files (`-L`).
    public func copyLinks(_ enabled: Bool = true) -> Self { copy(copiesLinkedFiles: enabled) }

    /// Returns a copy that preserves permissions (`-p`).
    public func permissions(_ enabled: Bool = true) -> Self { copy(preservesPermissions: enabled) }

    /// Returns a copy that preserves modification times (`-t`).
    public func times(_ enabled: Bool = true) -> Self { copy(preservesTimes: enabled) }

    /// Returns a copy that preserves owner information (`-o`).
    public func owner(_ enabled: Bool = true) -> Self { copy(preservesOwner: enabled) }

    /// Returns a copy that preserves group information (`-g`).
    public func group(_ enabled: Bool = true) -> Self { copy(preservesGroup: enabled) }

    /// Returns a copy that preserves hard links (`-H`).
    public func hardLinks(_ enabled: Bool = true) -> Self { copy(preservesHardLinks: enabled) }

    /// Returns a copy that handles sparse files efficiently (`-S`).
    public func sparse(_ enabled: Bool = true) -> Self { copy(handlesSparseFiles: enabled) }

    /// Returns a copy that avoids crossing filesystem boundaries (`-x`).
    public func oneFileSystem(_ enabled: Bool = true) -> Self { copy(staysOnOneFileSystem: enabled) }

    /// Returns a copy that prints an itemized change summary (`-i`).
    public func itemizeChanges(_ enabled: Bool = true) -> Self { copy(itemizesChanges: enabled) }

    /// Returns a copy that formats numbers in human-readable units (`-h`).
    public func humanReadable(_ enabled: Bool = true) -> Self { copy(usesHumanReadableOutput: enabled) }

    /// Returns a copy that shows transfer progress (`--progress`).
    public func progress(_ enabled: Bool = true) -> Self { copy(showsProgress: enabled) }

    /// Returns a copy that keeps partially transferred files (`--partial`).
    public func partial(_ enabled: Bool = true) -> Self { copy(keepsPartialFiles: enabled) }

    /// Returns a copy that skips creating files that do not already exist on the receiver.
    public func existing(_ enabled: Bool = true) -> Self { copy(requiresExistingDestinationFiles: enabled) }

    /// Returns a copy that skips updating files that already exist on the receiver.
    public func ignoreExisting(_ enabled: Bool = true) -> Self { copy(ignoresExistingDestinationFiles: enabled) }

    /// Returns a copy that removes source files after successful transfer.
    public func removeSourceFiles(_ enabled: Bool = true) -> Self { copy(removesSourceFiles: enabled) }

    /// Returns a copy that appends a source operand.
    ///
    /// Sources may be local paths, `host:path` remote-shell specs, daemon specs, or `rsync://`
    /// URLs. A trailing slash on a directory source keeps rsync's standard "copy contents"
    /// behavior.
    ///
    /// - Parameter value: Source operand to append.
    /// - Returns: A new ``Rsync`` value with the source appended.
    public func source(_ value: String) -> Self { copy(sources: state.sources + [value]) }

    /// Returns a copy that appends multiple source operands.
    ///
    /// - Parameter values: Source operands to append in order.
    /// - Returns: A new ``Rsync`` value with the sources appended.
    public func sources(_ values: [String]) -> Self { copy(sources: state.sources + values) }

    /// Returns a copy that sets the destination operand.
    ///
    /// Calling this multiple times keeps the last value.
    ///
    /// - Parameter value: Destination path, remote-shell spec, daemon spec, or `rsync://` URL.
    /// - Returns: A new ``Rsync`` value with the destination set.
    public func destination(_ value: String) -> Self { copy(destination: value) }

    /// Returns a copy that appends an exclude pattern (`--exclude <pattern>`).
    ///
    /// - Parameter pattern: Rsync filter pattern to exclude.
    /// - Returns: A new ``Rsync`` value with the exclude appended.
    public func exclude(_ pattern: String) -> Self { copy(excludes: state.excludes + [pattern]) }

    /// Returns a copy that appends multiple exclude patterns.
    ///
    /// - Parameter patterns: Rsync filter patterns to exclude.
    /// - Returns: A new ``Rsync`` value with the excludes appended.
    public func excludes(_ patterns: [String]) -> Self { copy(excludes: state.excludes + patterns) }

    /// Returns a copy that appends an include pattern (`--include <pattern>`).
    ///
    /// - Parameter pattern: Rsync filter pattern to include.
    /// - Returns: A new ``Rsync`` value with the include appended.
    public func include(_ pattern: String) -> Self { copy(includes: state.includes + [pattern]) }

    /// Returns a copy that appends multiple include patterns.
    ///
    /// - Parameter patterns: Rsync filter patterns to include.
    /// - Returns: A new ``Rsync`` value with the includes appended.
    public func includes(_ patterns: [String]) -> Self { copy(includes: state.includes + patterns) }

    /// Returns a copy that appends a raw filter rule (`--filter <rule>`).
    ///
    /// - Parameter rule: Rsync filter rule, such as `+ *.swift` or `- .build/`.
    /// - Returns: A new ``Rsync`` value with the filter appended.
    public func filter(_ rule: String) -> Self { copy(filters: state.filters + [rule]) }

    /// Returns a copy that appends multiple raw filter rules.
    ///
    /// - Parameter rules: Filter rules to append in order.
    /// - Returns: A new ``Rsync`` value with the filters appended.
    public func filters(_ rules: [String]) -> Self { copy(filters: state.filters + rules) }

    /// Returns a copy that reads exclude patterns from a file (`--exclude-from <file>`).
    public func excludeFrom(_ path: String) -> Self { copy(excludeFiles: state.excludeFiles + [path]) }

    /// Returns a copy that reads include patterns from a file (`--include-from <file>`).
    public func includeFrom(_ path: String) -> Self { copy(includeFiles: state.includeFiles + [path]) }

    /// Returns a copy that reads source filenames from a file (`--files-from <file>`).
    public func filesFrom(_ path: String) -> Self { copy(filesFrom: state.filesFrom + [path]) }

    /// Returns a copy that treats `*-from` files as NUL-delimited (`--from0`).
    public func from0(_ enabled: Bool = true) -> Self { copy(usesNullDelimitedFromFiles: enabled) }

    /// Returns a copy that selects the remote shell command (`-e <command>`).
    ///
    /// - Parameter command: Remote shell command, such as `ssh -i /path/key`.
    /// - Returns: A new ``Rsync`` value with the remote shell set.
    public func remoteShell(_ command: String) -> Self { copy(remoteShell: command) }

    /// Returns a copy that selects the rsync executable path on the remote host.
    ///
    /// - Parameter path: Program path or command to pass via `--rsync-path`.
    /// - Returns: A new ``Rsync`` value with the remote rsync path set.
    public func remoteRsyncPath(_ path: String) -> Self { copy(remoteRsyncPath: path) }

    /// Returns a copy that selects an alternate rsync daemon port (`--port <port>`).
    public func port(_ value: Int) -> Self { copy(port: value) }

    /// Returns a copy that limits socket I/O bandwidth (`--bwlimit <rate>`).
    ///
    /// - Parameter rate: Rsync rate string, such as `500K` or `2M`.
    /// - Returns: A new ``Rsync`` value with the bandwidth limit set.
    public func bandwidthLimit(_ rate: String) -> Self { copy(bandwidthLimit: rate) }

    /// Returns a copy that skips files larger than the given size (`--max-size <size>`).
    public func maxSize(_ value: String) -> Self { copy(maxSize: value) }

    /// Returns a copy that skips files smaller than the given size (`--min-size <size>`).
    public func minSize(_ value: String) -> Self { copy(minSize: value) }

    /// Returns a copy that sets rsync's I/O timeout (`--timeout <seconds>`).
    ///
    /// This is separate from ``timeout(_:)``, which sets SwiftyShell's process-level timeout.
    public func ioTimeout(_ seconds: Int) -> Self { copy(ioTimeout: seconds) }

    /// Returns a copy that appends a raw rsync option before operands.
    ///
    /// Use this for less common or implementation-specific flags while keeping the rest of the
    /// invocation typed.
    ///
    /// - Parameter value: A single option or argument to append.
    /// - Returns: A new ``Rsync`` value with the raw option appended.
    public func option(_ value: String) -> Self { copy(extraOptions: state.extraOptions + [value]) }

    /// Returns a copy that appends raw rsync options before operands.
    ///
    /// - Parameter values: Options or arguments to append in order.
    /// - Returns: A new ``Rsync`` value with the raw options appended.
    public func options(_ values: [String]) -> Self { copy(extraOptions: state.extraOptions + values) }

    /// Builds the raw `rsync` command represented by the current builder state.
    ///
    /// Arguments are emitted deterministically as behavior flags, parameterized options, raw
    /// options, sources, then destination.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if state.isArchive { arguments.append("-a") }
        if state.isRecursive { arguments.append("-r") }
        if state.usesCompression { arguments.append("-z") }
        if state.isVerbose { arguments.append("-v") }
        if state.isQuiet { arguments.append("-q") }
        if state.isDryRun { arguments.append("-n") }
        if state.usesChecksum { arguments.append("-c") }
        if state.updatesOnlyOlderFiles { arguments.append("-u") }
        if state.deletesExtraneousFiles { arguments.append("--delete") }
        if state.deletesExcludedFiles { arguments.append("--delete-excluded") }
        if state.preservesLinks { arguments.append("-l") }
        if state.copiesLinkedFiles { arguments.append("-L") }
        if state.preservesPermissions { arguments.append("-p") }
        if state.preservesTimes { arguments.append("-t") }
        if state.preservesOwner { arguments.append("-o") }
        if state.preservesGroup { arguments.append("-g") }
        if state.preservesHardLinks { arguments.append("-H") }
        if state.handlesSparseFiles { arguments.append("-S") }
        if state.staysOnOneFileSystem { arguments.append("-x") }
        if state.itemizesChanges { arguments.append("-i") }
        if state.usesHumanReadableOutput { arguments.append("-h") }
        if state.showsProgress { arguments.append("--progress") }
        if state.keepsPartialFiles { arguments.append("--partial") }
        if state.requiresExistingDestinationFiles { arguments.append("--existing") }
        if state.ignoresExistingDestinationFiles { arguments.append("--ignore-existing") }
        if state.removesSourceFiles { arguments.append("--remove-source-files") }
        if state.usesNullDelimitedFromFiles { arguments.append("--from0") }

        for pattern in state.excludes {
            arguments.append("--exclude")
            arguments.append(pattern)
        }

        for pattern in state.includes {
            arguments.append("--include")
            arguments.append(pattern)
        }

        for rule in state.filters {
            arguments.append("--filter")
            arguments.append(rule)
        }

        for path in state.excludeFiles {
            arguments.append("--exclude-from")
            arguments.append(path)
        }

        for path in state.includeFiles {
            arguments.append("--include-from")
            arguments.append(path)
        }

        for path in state.filesFrom {
            arguments.append("--files-from")
            arguments.append(path)
        }

        if let remoteShell = state.remoteShell {
            arguments.append("-e")
            arguments.append(remoteShell)
        }

        if let remoteRsyncPath = state.remoteRsyncPath {
            arguments.append("--rsync-path")
            arguments.append(remoteRsyncPath)
        }

        if let port = state.port {
            arguments.append("--port")
            arguments.append(String(port))
        }

        if let bandwidthLimit = state.bandwidthLimit {
            arguments.append("--bwlimit")
            arguments.append(bandwidthLimit)
        }

        if let maxSize = state.maxSize {
            arguments.append("--max-size")
            arguments.append(maxSize)
        }

        if let minSize = state.minSize {
            arguments.append("--min-size")
            arguments.append(minSize)
        }

        if let ioTimeout = state.ioTimeout {
            arguments.append("--timeout")
            arguments.append(String(ioTimeout))
        }

        arguments.append(contentsOf: state.extraOptions)
        arguments.append(contentsOf: state.sources)

        if let destination = state.destination {
            arguments.append(destination)
        }

        let base = Command("rsync")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        isArchive: Bool? = nil,
        isRecursive: Bool? = nil,
        usesCompression: Bool? = nil,
        isVerbose: Bool? = nil,
        isQuiet: Bool? = nil,
        isDryRun: Bool? = nil,
        usesChecksum: Bool? = nil,
        updatesOnlyOlderFiles: Bool? = nil,
        deletesExtraneousFiles: Bool? = nil,
        deletesExcludedFiles: Bool? = nil,
        preservesLinks: Bool? = nil,
        copiesLinkedFiles: Bool? = nil,
        preservesPermissions: Bool? = nil,
        preservesTimes: Bool? = nil,
        preservesOwner: Bool? = nil,
        preservesGroup: Bool? = nil,
        preservesHardLinks: Bool? = nil,
        handlesSparseFiles: Bool? = nil,
        staysOnOneFileSystem: Bool? = nil,
        itemizesChanges: Bool? = nil,
        usesHumanReadableOutput: Bool? = nil,
        showsProgress: Bool? = nil,
        keepsPartialFiles: Bool? = nil,
        requiresExistingDestinationFiles: Bool? = nil,
        ignoresExistingDestinationFiles: Bool? = nil,
        removesSourceFiles: Bool? = nil,
        sources: [String]? = nil,
        destination: String?? = nil,
        excludes: [String]? = nil,
        includes: [String]? = nil,
        filters: [String]? = nil,
        excludeFiles: [String]? = nil,
        includeFiles: [String]? = nil,
        filesFrom: [String]? = nil,
        usesNullDelimitedFromFiles: Bool? = nil,
        remoteShell: String?? = nil,
        remoteRsyncPath: String?? = nil,
        port: Int?? = nil,
        bandwidthLimit: String?? = nil,
        maxSize: String?? = nil,
        minSize: String?? = nil,
        ioTimeout: Int?? = nil,
        extraOptions: [String]? = nil
    ) -> Self {
        Self(
            state: RsyncState(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                isArchive: isArchive ?? state.isArchive,
                isRecursive: isRecursive ?? state.isRecursive,
                usesCompression: usesCompression ?? state.usesCompression,
                isVerbose: isVerbose ?? state.isVerbose,
                isQuiet: isQuiet ?? state.isQuiet,
                isDryRun: isDryRun ?? state.isDryRun,
                usesChecksum: usesChecksum ?? state.usesChecksum,
                updatesOnlyOlderFiles: updatesOnlyOlderFiles ?? state.updatesOnlyOlderFiles,
                deletesExtraneousFiles: deletesExtraneousFiles ?? state.deletesExtraneousFiles,
                deletesExcludedFiles: deletesExcludedFiles ?? state.deletesExcludedFiles,
                preservesLinks: preservesLinks ?? state.preservesLinks,
                copiesLinkedFiles: copiesLinkedFiles ?? state.copiesLinkedFiles,
                preservesPermissions: preservesPermissions ?? state.preservesPermissions,
                preservesTimes: preservesTimes ?? state.preservesTimes,
                preservesOwner: preservesOwner ?? state.preservesOwner,
                preservesGroup: preservesGroup ?? state.preservesGroup,
                preservesHardLinks: preservesHardLinks ?? state.preservesHardLinks,
                handlesSparseFiles: handlesSparseFiles ?? state.handlesSparseFiles,
                staysOnOneFileSystem: staysOnOneFileSystem ?? state.staysOnOneFileSystem,
                itemizesChanges: itemizesChanges ?? state.itemizesChanges,
                usesHumanReadableOutput: usesHumanReadableOutput ?? state.usesHumanReadableOutput,
                showsProgress: showsProgress ?? state.showsProgress,
                keepsPartialFiles: keepsPartialFiles ?? state.keepsPartialFiles,
                requiresExistingDestinationFiles: requiresExistingDestinationFiles
                    ?? state.requiresExistingDestinationFiles,
                ignoresExistingDestinationFiles: ignoresExistingDestinationFiles
                    ?? state.ignoresExistingDestinationFiles,
                removesSourceFiles: removesSourceFiles ?? state.removesSourceFiles,
                sources: sources ?? state.sources,
                destination: destination ?? state.destination,
                excludes: excludes ?? state.excludes,
                includes: includes ?? state.includes,
                filters: filters ?? state.filters,
                excludeFiles: excludeFiles ?? state.excludeFiles,
                includeFiles: includeFiles ?? state.includeFiles,
                filesFrom: filesFrom ?? state.filesFrom,
                usesNullDelimitedFromFiles: usesNullDelimitedFromFiles ?? state.usesNullDelimitedFromFiles,
                remoteShell: remoteShell ?? state.remoteShell,
                remoteRsyncPath: remoteRsyncPath ?? state.remoteRsyncPath,
                port: port ?? state.port,
                bandwidthLimit: bandwidthLimit ?? state.bandwidthLimit,
                maxSize: maxSize ?? state.maxSize,
                minSize: minSize ?? state.minSize,
                ioTimeout: ioTimeout ?? state.ioTimeout,
                extraOptions: extraOptions ?? state.extraOptions
            )
        )
    }
}

private struct RsyncState: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let isArchive: Bool
    let isRecursive: Bool
    let usesCompression: Bool
    let isVerbose: Bool
    let isQuiet: Bool
    let isDryRun: Bool
    let usesChecksum: Bool
    let updatesOnlyOlderFiles: Bool
    let deletesExtraneousFiles: Bool
    let deletesExcludedFiles: Bool
    let preservesLinks: Bool
    let copiesLinkedFiles: Bool
    let preservesPermissions: Bool
    let preservesTimes: Bool
    let preservesOwner: Bool
    let preservesGroup: Bool
    let preservesHardLinks: Bool
    let handlesSparseFiles: Bool
    let staysOnOneFileSystem: Bool
    let itemizesChanges: Bool
    let usesHumanReadableOutput: Bool
    let showsProgress: Bool
    let keepsPartialFiles: Bool
    let requiresExistingDestinationFiles: Bool
    let ignoresExistingDestinationFiles: Bool
    let removesSourceFiles: Bool
    let sources: [String]
    let destination: String?
    let excludes: [String]
    let includes: [String]
    let filters: [String]
    let excludeFiles: [String]
    let includeFiles: [String]
    let filesFrom: [String]
    let usesNullDelimitedFromFiles: Bool
    let remoteShell: String?
    let remoteRsyncPath: String?
    let port: Int?
    let bandwidthLimit: String?
    let maxSize: String?
    let minSize: String?
    let ioTimeout: Int?
    let extraOptions: [String]

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        isArchive: Bool = false,
        isRecursive: Bool = false,
        usesCompression: Bool = false,
        isVerbose: Bool = false,
        isQuiet: Bool = false,
        isDryRun: Bool = false,
        usesChecksum: Bool = false,
        updatesOnlyOlderFiles: Bool = false,
        deletesExtraneousFiles: Bool = false,
        deletesExcludedFiles: Bool = false,
        preservesLinks: Bool = false,
        copiesLinkedFiles: Bool = false,
        preservesPermissions: Bool = false,
        preservesTimes: Bool = false,
        preservesOwner: Bool = false,
        preservesGroup: Bool = false,
        preservesHardLinks: Bool = false,
        handlesSparseFiles: Bool = false,
        staysOnOneFileSystem: Bool = false,
        itemizesChanges: Bool = false,
        usesHumanReadableOutput: Bool = false,
        showsProgress: Bool = false,
        keepsPartialFiles: Bool = false,
        requiresExistingDestinationFiles: Bool = false,
        ignoresExistingDestinationFiles: Bool = false,
        removesSourceFiles: Bool = false,
        sources: [String] = [],
        destination: String? = nil,
        excludes: [String] = [],
        includes: [String] = [],
        filters: [String] = [],
        excludeFiles: [String] = [],
        includeFiles: [String] = [],
        filesFrom: [String] = [],
        usesNullDelimitedFromFiles: Bool = false,
        remoteShell: String? = nil,
        remoteRsyncPath: String? = nil,
        port: Int? = nil,
        bandwidthLimit: String? = nil,
        maxSize: String? = nil,
        minSize: String? = nil,
        ioTimeout: Int? = nil,
        extraOptions: [String] = []
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.isArchive = isArchive
        self.isRecursive = isRecursive
        self.usesCompression = usesCompression
        self.isVerbose = isVerbose
        self.isQuiet = isQuiet
        self.isDryRun = isDryRun
        self.usesChecksum = usesChecksum
        self.updatesOnlyOlderFiles = updatesOnlyOlderFiles
        self.deletesExtraneousFiles = deletesExtraneousFiles
        self.deletesExcludedFiles = deletesExcludedFiles
        self.preservesLinks = preservesLinks
        self.copiesLinkedFiles = copiesLinkedFiles
        self.preservesPermissions = preservesPermissions
        self.preservesTimes = preservesTimes
        self.preservesOwner = preservesOwner
        self.preservesGroup = preservesGroup
        self.preservesHardLinks = preservesHardLinks
        self.handlesSparseFiles = handlesSparseFiles
        self.staysOnOneFileSystem = staysOnOneFileSystem
        self.itemizesChanges = itemizesChanges
        self.usesHumanReadableOutput = usesHumanReadableOutput
        self.showsProgress = showsProgress
        self.keepsPartialFiles = keepsPartialFiles
        self.requiresExistingDestinationFiles = requiresExistingDestinationFiles
        self.ignoresExistingDestinationFiles = ignoresExistingDestinationFiles
        self.removesSourceFiles = removesSourceFiles
        self.sources = sources
        self.destination = destination
        self.excludes = excludes
        self.includes = includes
        self.filters = filters
        self.excludeFiles = excludeFiles
        self.includeFiles = includeFiles
        self.filesFrom = filesFrom
        self.usesNullDelimitedFromFiles = usesNullDelimitedFromFiles
        self.remoteShell = remoteShell
        self.remoteRsyncPath = remoteRsyncPath
        self.port = port
        self.bandwidthLimit = bandwidthLimit
        self.maxSize = maxSize
        self.minSize = minSize
        self.ioTimeout = ioTimeout
        self.extraOptions = extraOptions
    }
}
#endif
