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
    private var state: RsyncState

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
    /// ``workingDirectory(_:)``, ``timeout(_:)-(Duration)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new ``Rsync`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `rsync` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Rsync writes itemized changes, progress, and
    /// list output to stdout depending on the selected flags.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Rsync`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `rsync` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Rsync`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that enables archive mode (`-a`).
    public func archive(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isArchive = enabled } }

    /// Returns a copy that enables recursive directory traversal (`-r`).
    public func recursive(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isRecursive = enabled } }

    /// Returns a copy that enables compression during transfer (`-z`).
    public func compress(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesCompression = enabled } }

    /// Returns a copy that increases verbosity (`-v`).
    public func verbose(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isVerbose = enabled } }

    /// Returns a copy that suppresses non-error messages (`-q`).
    public func quiet(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isQuiet = enabled } }

    /// Returns a copy that performs a trial run without changing files (`-n`).
    public func dryRun(_ enabled: Bool = true) -> Self { modified(self) { $0.state.isDryRun = enabled } }

    /// Returns a copy that skips based on checksum instead of size and modification time (`-c`).
    public func checksum(_ enabled: Bool = true) -> Self { modified(self) { $0.state.usesChecksum = enabled } }

    /// Returns a copy that skips files newer on the receiver (`-u`).
    public func update(_ enabled: Bool = true) -> Self { modified(self) { $0.state.updatesOnlyOlderFiles = enabled } }

    /// Returns a copy that deletes extraneous destination files (`--delete`).
    public func delete(_ enabled: Bool = true) -> Self { modified(self) { $0.state.deletesExtraneousFiles = enabled } }

    /// Returns a copy that also deletes excluded files from destination directories.
    public func deleteExcluded(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.deletesExcludedFiles = enabled }
    }

    /// Returns a copy that preserves symbolic links as symbolic links (`-l`).
    public func links(_ enabled: Bool = true) -> Self { modified(self) { $0.state.preservesLinks = enabled } }

    /// Returns a copy that follows symlinks and copies referent files (`-L`).
    public func copyLinks(_ enabled: Bool = true) -> Self { modified(self) { $0.state.copiesLinkedFiles = enabled } }

    /// Returns a copy that preserves permissions (`-p`).
    public func permissions(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.preservesPermissions = enabled }
    }

    /// Returns a copy that preserves modification times (`-t`).
    public func times(_ enabled: Bool = true) -> Self { modified(self) { $0.state.preservesTimes = enabled } }

    /// Returns a copy that preserves owner information (`-o`).
    public func owner(_ enabled: Bool = true) -> Self { modified(self) { $0.state.preservesOwner = enabled } }

    /// Returns a copy that preserves group information (`-g`).
    public func group(_ enabled: Bool = true) -> Self { modified(self) { $0.state.preservesGroup = enabled } }

    /// Returns a copy that preserves hard links (`-H`).
    public func hardLinks(_ enabled: Bool = true) -> Self { modified(self) { $0.state.preservesHardLinks = enabled } }

    /// Returns a copy that handles sparse files efficiently (`-S`).
    public func sparse(_ enabled: Bool = true) -> Self { modified(self) { $0.state.handlesSparseFiles = enabled } }

    /// Returns a copy that avoids crossing filesystem boundaries (`-x`).
    public func oneFileSystem(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.staysOnOneFileSystem = enabled }
    }

    /// Returns a copy that prints an itemized change summary (`-i`).
    public func itemizeChanges(_ enabled: Bool = true) -> Self { modified(self) { $0.state.itemizesChanges = enabled } }

    /// Returns a copy that formats numbers in human-readable units (`-h`).
    public func humanReadable(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.usesHumanReadableOutput = enabled }
    }

    /// Returns a copy that shows transfer progress (`--progress`).
    public func progress(_ enabled: Bool = true) -> Self { modified(self) { $0.state.showsProgress = enabled } }

    /// Returns a copy that keeps partially transferred files (`--partial`).
    public func partial(_ enabled: Bool = true) -> Self { modified(self) { $0.state.keepsPartialFiles = enabled } }

    /// Returns a copy that skips creating files that do not already exist on the receiver.
    public func existing(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.requiresExistingDestinationFiles = enabled }
    }

    /// Returns a copy that skips updating files that already exist on the receiver.
    public func ignoreExisting(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.ignoresExistingDestinationFiles = enabled }
    }

    /// Returns a copy that removes source files after successful transfer.
    public func removeSourceFiles(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.removesSourceFiles = enabled }
    }

    /// Returns a copy that appends a source operand.
    ///
    /// Sources may be local paths, `host:path` remote-shell specs, daemon specs, or `rsync://`
    /// URLs. A trailing slash on a directory source keeps rsync's standard "copy contents"
    /// behavior.
    ///
    /// - Parameter value: Source operand to append.
    /// - Returns: A new ``Rsync`` value with the source appended.
    public func source(_ value: String) -> Self { modified(self) { $0.state.sources += [value] } }

    /// Returns a copy that appends multiple source operands.
    ///
    /// - Parameter values: Source operands to append in order.
    /// - Returns: A new ``Rsync`` value with the sources appended.
    public func sources(_ values: [String]) -> Self { modified(self) { $0.state.sources += values } }

    /// Returns a copy that sets the destination operand.
    ///
    /// Calling this multiple times keeps the last value.
    ///
    /// - Parameter value: Destination path, remote-shell spec, daemon spec, or `rsync://` URL.
    /// - Returns: A new ``Rsync`` value with the destination set.
    public func destination(_ value: String) -> Self { modified(self) { $0.state.destination = value } }

    /// Returns a copy that appends an exclude pattern (`--exclude <pattern>`).
    ///
    /// - Parameter pattern: Rsync filter pattern to exclude.
    /// - Returns: A new ``Rsync`` value with the exclude appended.
    public func exclude(_ pattern: String) -> Self { modified(self) { $0.state.excludes += [pattern] } }

    /// Returns a copy that appends multiple exclude patterns.
    ///
    /// - Parameter patterns: Rsync filter patterns to exclude.
    /// - Returns: A new ``Rsync`` value with the excludes appended.
    public func excludes(_ patterns: [String]) -> Self { modified(self) { $0.state.excludes += patterns } }

    /// Returns a copy that appends an include pattern (`--include <pattern>`).
    ///
    /// - Parameter pattern: Rsync filter pattern to include.
    /// - Returns: A new ``Rsync`` value with the include appended.
    public func include(_ pattern: String) -> Self { modified(self) { $0.state.includes += [pattern] } }

    /// Returns a copy that appends multiple include patterns.
    ///
    /// - Parameter patterns: Rsync filter patterns to include.
    /// - Returns: A new ``Rsync`` value with the includes appended.
    public func includes(_ patterns: [String]) -> Self { modified(self) { $0.state.includes += patterns } }

    /// Returns a copy that appends a raw filter rule (`--filter <rule>`).
    ///
    /// - Parameter rule: Rsync filter rule, such as `+ *.swift` or `- .build/`.
    /// - Returns: A new ``Rsync`` value with the filter appended.
    public func filter(_ rule: String) -> Self { modified(self) { $0.state.filters += [rule] } }

    /// Returns a copy that appends multiple raw filter rules.
    ///
    /// - Parameter rules: Filter rules to append in order.
    /// - Returns: A new ``Rsync`` value with the filters appended.
    public func filters(_ rules: [String]) -> Self { modified(self) { $0.state.filters += rules } }

    /// Returns a copy that reads exclude patterns from a file (`--exclude-from <file>`).
    public func excludeFrom(_ path: String) -> Self { modified(self) { $0.state.excludeFiles += [path] } }

    /// Returns a copy that reads include patterns from a file (`--include-from <file>`).
    public func includeFrom(_ path: String) -> Self { modified(self) { $0.state.includeFiles += [path] } }

    /// Returns a copy that reads source filenames from a file (`--files-from <file>`).
    public func filesFrom(_ path: String) -> Self { modified(self) { $0.state.filesFrom += [path] } }

    /// Returns a copy that treats `*-from` files as NUL-delimited (`--from0`).
    public func from0(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.usesNullDelimitedFromFiles = enabled }
    }

    /// Returns a copy that selects the remote shell command (`-e <command>`).
    ///
    /// - Parameter command: Remote shell command, such as `ssh -i /path/key`.
    /// - Returns: A new ``Rsync`` value with the remote shell set.
    public func remoteShell(_ command: String) -> Self { modified(self) { $0.state.remoteShell = command } }

    /// Returns a copy that selects the rsync executable path on the remote host.
    ///
    /// - Parameter path: Program path or command to pass via `--rsync-path`.
    /// - Returns: A new ``Rsync`` value with the remote rsync path set.
    public func remoteRsyncPath(_ path: String) -> Self { modified(self) { $0.state.remoteRsyncPath = path } }

    /// Returns a copy that selects an alternate rsync daemon port (`--port <port>`).
    public func port(_ value: Int) -> Self { modified(self) { $0.state.port = value } }

    /// Returns a copy that limits socket I/O bandwidth (`--bwlimit <rate>`).
    ///
    /// - Parameter rate: Rsync rate string, such as `500K` or `2M`.
    /// - Returns: A new ``Rsync`` value with the bandwidth limit set.
    public func bandwidthLimit(_ rate: String) -> Self { modified(self) { $0.state.bandwidthLimit = rate } }

    /// Returns a copy that skips files larger than the given size (`--max-size <size>`).
    public func maxSize(_ value: String) -> Self { modified(self) { $0.state.maxSize = value } }

    /// Returns a copy that skips files smaller than the given size (`--min-size <size>`).
    public func minSize(_ value: String) -> Self { modified(self) { $0.state.minSize = value } }

    /// Returns a copy that sets rsync's I/O timeout (`--timeout <seconds>`).
    ///
    /// This is separate from ``timeout(_:)-(Duration)``, which sets SwiftyShell's process-level timeout.
    public func ioTimeout(_ seconds: Int) -> Self { modified(self) { $0.state.ioTimeout = seconds } }

    /// Returns a copy that appends a raw rsync option before operands.
    ///
    /// Use this for less common or implementation-specific flags while keeping the rest of the
    /// invocation typed.
    ///
    /// - Parameter value: A single option or argument to append.
    /// - Returns: A new ``Rsync`` value with the raw option appended.
    public func option(_ value: String) -> Self { modified(self) { $0.state.extraOptions += [value] } }

    /// Returns a copy that appends raw rsync options before operands.
    ///
    /// - Parameter values: Options or arguments to append in order.
    /// - Returns: A new ``Rsync`` value with the raw options appended.
    public func options(_ values: [String]) -> Self { modified(self) { $0.state.extraOptions += values } }

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
}

private struct RsyncState: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var isArchive: Bool = false
    var isRecursive: Bool = false
    var usesCompression: Bool = false
    var isVerbose: Bool = false
    var isQuiet: Bool = false
    var isDryRun: Bool = false
    var usesChecksum: Bool = false
    var updatesOnlyOlderFiles: Bool = false
    var deletesExtraneousFiles: Bool = false
    var deletesExcludedFiles: Bool = false
    var preservesLinks: Bool = false
    var copiesLinkedFiles: Bool = false
    var preservesPermissions: Bool = false
    var preservesTimes: Bool = false
    var preservesOwner: Bool = false
    var preservesGroup: Bool = false
    var preservesHardLinks: Bool = false
    var handlesSparseFiles: Bool = false
    var staysOnOneFileSystem: Bool = false
    var itemizesChanges: Bool = false
    var usesHumanReadableOutput: Bool = false
    var showsProgress: Bool = false
    var keepsPartialFiles: Bool = false
    var requiresExistingDestinationFiles: Bool = false
    var ignoresExistingDestinationFiles: Bool = false
    var removesSourceFiles: Bool = false
    var sources: [String] = []
    var destination: String? = nil
    var excludes: [String] = []
    var includes: [String] = []
    var filters: [String] = []
    var excludeFiles: [String] = []
    var includeFiles: [String] = []
    var filesFrom: [String] = []
    var usesNullDelimitedFromFiles: Bool = false
    var remoteShell: String? = nil
    var remoteRsyncPath: String? = nil
    var port: Int? = nil
    var bandwidthLimit: String? = nil
    var maxSize: String? = nil
    var minSize: String? = nil
    var ioTimeout: Int? = nil
    var extraOptions: [String] = []
}
#endif
