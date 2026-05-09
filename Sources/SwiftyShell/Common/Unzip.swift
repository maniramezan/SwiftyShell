#if Unzip
import Foundation

/// A typed entry parsed from `unzip -l` output by ``Unzip/entries()``.
///
/// Each value carries the archive-relative ``path``, the uncompressed ``size`` in bytes, and an
/// optional ``modified`` timestamp. ``modified`` is `nil` when the timestamp column cannot be
/// parsed, so callers should guard before relying on it.
///
/// ```swift
/// let entries = try await Unzip(context: context)
///     .archive("/tmp/release.zip")
///     .entries()
///     .run()
///
/// for entry in entries {
///     print("\(entry.path) — \(entry.size) bytes")
/// }
/// ```
public struct UnzipEntry: Sendable, Equatable, Hashable {
    /// The entry's archive-relative path as reported by `unzip -l`.
    public let path: String

    /// The uncompressed size of the entry in bytes.
    public let size: Int

    /// The entry's last-modified timestamp, parsed from the listing in UTC. `nil` when the
    /// timestamp column did not match the expected `yyyy-MM-dd HH:mm` format.
    public let modified: Date?

    /// Creates a parsed unzip listing entry.
    ///
    /// - Parameters:
    ///   - path: The archive-relative path.
    ///   - size: The uncompressed byte size.
    ///   - modified: The last-modified timestamp, or `nil` if unavailable.
    public init(path: String, size: Int, modified: Date?) {
        self.path = path
        self.size = size
        self.modified = modified
    }
}

/// A fluent wrapper for the Info-ZIP `unzip` command.
///
/// Use ``Unzip`` to extract, list, or test `.zip` archives with a typed builder. The same API
/// works on macOS (where `unzip` ships by default) and on Linux distributions that have the
/// `unzip` package installed; flag semantics are identical because both targets ship the
/// Info-ZIP implementation.
///
/// ```swift
/// // Extract an archive into a destination directory, overwriting existing files.
/// try await Unzip(context: context)
///     .archive("/tmp/release.zip")
///     .destination("/tmp/release")
///     .overwrite()
///     .run()
/// ```
///
/// For programmatic listings call ``entries()`` instead of running `unzip -l` and parsing the
/// raw output yourself.
///
/// > Important: ``password(_:)`` puts the password directly on the subprocess argv, where it
/// > may be visible to other users via `ps`.
public struct Unzip: RunnableCommandFamily {
    private let state: State

    /// The shell context used when running this command family.
    ///
    /// Forwarded from the embedded ``ToolConfiguration`` so commands built by ``command()`` and
    /// invocations of ``run()`` share the same executor and defaults.
    public var context: ShellContext { state.config.context }

    /// Creates an `unzip` command family bound to a shell context.
    ///
    /// All builder state starts empty: no archive, no members, no flags. Configure the archive
    /// (and any options) before calling ``run()``, ``entries()``, or ``command()``.
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
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new ``Unzip`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(state.config))
    }

    /// Returns a copy that routes the built `unzip` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `unzip` writes status lines and listing
    /// output on stdout.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Unzip`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `unzip` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Unzip`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that sets the archive path to operate on.
    ///
    /// Calling this multiple times keeps the last value. The archive path is required for any
    /// non-trivial `unzip` invocation.
    ///
    /// - Parameter path: The path to the `.zip` archive.
    /// - Returns: A new ``Unzip`` value with the archive set.
    public func archive(_ path: String) -> Self {
        copy(archivePath: path)
    }

    /// Returns a copy with one additional member pattern appended.
    ///
    /// Member patterns are positional and follow the archive path. Without any member, `unzip`
    /// extracts every entry.
    ///
    /// - Parameter pattern: A glob pattern such as `"docs/*.md"`.
    /// - Returns: A new ``Unzip`` value with the member pattern appended.
    public func member(_ pattern: String) -> Self {
        copy(members: state.members + [pattern])
    }

    /// Returns a copy with multiple member patterns appended.
    ///
    /// - Parameter patterns: Glob patterns to append in order.
    /// - Returns: A new ``Unzip`` value with the patterns appended.
    public func members(_ patterns: [String]) -> Self {
        copy(members: state.members + patterns)
    }

    /// Returns a copy with one exclude pattern appended (`-x <pattern>`).
    ///
    /// Exclude patterns follow the member list.
    ///
    /// - Parameter pattern: A glob pattern such as `"*.tmp"`.
    /// - Returns: A new ``Unzip`` value with the exclude pattern appended.
    public func exclude(_ pattern: String) -> Self {
        copy(excludes: state.excludes + [pattern])
    }

    /// Returns a copy with multiple exclude patterns appended.
    ///
    /// - Parameter patterns: Glob patterns to append in order.
    /// - Returns: A new ``Unzip`` value with the exclude patterns appended.
    public func excludes(_ patterns: [String]) -> Self {
        copy(excludes: state.excludes + patterns)
    }

    /// Returns a copy that toggles list mode (`-l`).
    ///
    /// In list mode `unzip` prints a tabular listing of archive entries to stdout instead of
    /// extracting. ``entries()`` builds on top of this mode.
    ///
    /// - Parameter enabled: `true` to add `-l`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func list(_ enabled: Bool = true) -> Self {
        copy(modeList: enabled)
    }

    /// Returns a copy that toggles test mode (`-t`).
    ///
    /// In test mode `unzip` validates archive integrity (CRC checks) without writing any
    /// extracted files.
    ///
    /// - Parameter enabled: `true` to add `-t`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func test(_ enabled: Bool = true) -> Self {
        copy(modeTest: enabled)
    }

    /// Returns a copy that toggles pipe-to-stdout mode (`-p`).
    ///
    /// `unzip -p` writes the contents of selected entries to stdout, suitable for piping into
    /// other commands. No filesystem entries are created.
    ///
    /// - Parameter enabled: `true` to add `-p`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func printToStdout(_ enabled: Bool = true) -> Self {
        copy(modePrint: enabled)
    }

    /// Returns a copy that sets the extraction destination directory (`-d <dir>`).
    ///
    /// `unzip` creates the directory if it does not exist and extracts entries into it. Calling
    /// this multiple times keeps the last value.
    ///
    /// - Parameter path: The directory to extract into.
    /// - Returns: A new ``Unzip`` value with the destination set.
    public func destination(_ path: String) -> Self {
        copy(destinationPath: path)
    }

    /// Returns a copy that toggles always-overwrite mode (`-o`).
    ///
    /// Without this flag `unzip` prompts on stdin before overwriting existing files; SwiftyShell
    /// does not feed stdin, so unattended extractions should pass `-o` (or ``neverOverwrite(_:)``)
    /// to avoid hanging.
    ///
    /// - Parameter enabled: `true` to add `-o`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func overwrite(_ enabled: Bool = true) -> Self {
        copy(overwrites: enabled)
    }

    /// Returns a copy that toggles never-overwrite mode (`-n`).
    ///
    /// With this flag `unzip` skips entries whose target already exists.
    ///
    /// - Parameter enabled: `true` to add `-n`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func neverOverwrite(_ enabled: Bool = true) -> Self {
        copy(neverOverwrites: enabled)
    }

    /// Returns a copy that toggles quiet mode (`-q`).
    ///
    /// Suppresses informational status lines.
    ///
    /// - Parameter enabled: `true` to add `-q`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func quiet(_ enabled: Bool = true) -> Self {
        copy(isQuiet: enabled)
    }

    /// Returns a copy that toggles junk-paths mode (`-j`).
    ///
    /// With this flag `unzip` strips directory components from extracted paths.
    ///
    /// - Parameter enabled: `true` to add `-j`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func junkPaths(_ enabled: Bool = true) -> Self {
        copy(junksPaths: enabled)
    }

    /// Returns a copy that toggles preserve-case mode (`-K`).
    ///
    /// Preserves the original case of file names on case-insensitive file systems.
    ///
    /// - Parameter enabled: `true` to add `-K`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func preserveCase(_ enabled: Bool = true) -> Self {
        copy(preservesCase: enabled)
    }

    /// Returns a copy that toggles freshen mode (`-f`).
    ///
    /// Replaces only existing on-disk entries that are older than the archive copy.
    ///
    /// - Parameter enabled: `true` to add `-f`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func freshen(_ enabled: Bool = true) -> Self {
        copy(modeFreshen: enabled)
    }

    /// Returns a copy that toggles update mode (`-u`).
    ///
    /// Like ``freshen(_:)`` but also creates new files that don't yet exist on disk.
    ///
    /// - Parameter enabled: `true` to add `-u`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func updateOnly(_ enabled: Bool = true) -> Self {
        copy(modeUpdate: enabled)
    }

    /// Returns a copy that supplies a password on the command line (`-P <password>`).
    ///
    /// > Warning: The password is visible to other users on the system via `ps` because it is
    /// > placed on the subprocess argv.
    ///
    /// - Parameter value: The password to forward to `unzip`.
    /// - Returns: A new ``Unzip`` value with the password applied.
    public func password(_ value: String) -> Self {
        copy(password: value)
    }

    /// Builds the raw `unzip` command represented by the current builder state.
    ///
    /// Argv is assembled deterministically as: mode flags → behavior flags → `-P <password>` →
    /// archive → members → `-x <excludes>` → `-d <destination>`. The shared
    /// ``ToolConfiguration`` overrides are merged via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if state.modeList { arguments.append("-l") }
        if state.modeTest { arguments.append("-t") }
        if state.modePrint { arguments.append("-p") }
        if state.modeFreshen { arguments.append("-f") }
        if state.modeUpdate { arguments.append("-u") }

        if state.overwrites { arguments.append("-o") }
        if state.neverOverwrites { arguments.append("-n") }
        if state.isQuiet { arguments.append("-q") }
        if state.junksPaths { arguments.append("-j") }
        if state.preservesCase { arguments.append("-K") }

        if let password = state.password {
            arguments.append("-P")
            arguments.append(password)
        }

        if let archivePath = state.archivePath {
            arguments.append(archivePath)
        }

        arguments.append(contentsOf: state.members)

        if !state.excludes.isEmpty {
            arguments.append("-x")
            arguments.append(contentsOf: state.excludes)
        }

        if let destination = state.destinationPath {
            arguments.append("-d")
            arguments.append(destination)
        }

        let base = Command("unzip")
            .args(arguments)
            .stdout(state.stdoutDestination)
            .stderr(state.stderrDestination)

        return state.config.apply(to: base)
    }

    /// Returns a single-use workflow that runs `unzip -l` and parses the listing.
    ///
    /// The workflow forces ``list(_:)`` on so the archive listing format is produced regardless
    /// of any other mode flag the caller may have set. Members and excludes are forwarded so
    /// `entries()` can scope to a subset of the archive.
    ///
    /// ```swift
    /// let entries = try await Unzip(context: context)
    ///     .archive("/tmp/release.zip")
    ///     .entries()
    ///     .run()
    /// ```
    ///
    /// - Returns: A single-use ``Workflow`` producing parsed ``UnzipEntry`` values.
    public func entries() -> Workflow<[UnzipEntry]> {
        let context = state.config.context
        let cmd = self.list().command()
        return Workflow {
            let output = try await cmd.run(in: context)
            return UnzipEntryParser.parse(output.stdout)
        }
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        archivePath: String?? = nil,
        members: [String]? = nil,
        excludes: [String]? = nil,
        destinationPath: String?? = nil,
        modeList: Bool? = nil,
        modeTest: Bool? = nil,
        modePrint: Bool? = nil,
        modeFreshen: Bool? = nil,
        modeUpdate: Bool? = nil,
        overwrites: Bool? = nil,
        neverOverwrites: Bool? = nil,
        isQuiet: Bool? = nil,
        junksPaths: Bool? = nil,
        preservesCase: Bool? = nil,
        password: String?? = nil
    ) -> Self {
        Self(
            state: State(
                config: config ?? state.config,
                stdoutDestination: stdoutDestination ?? state.stdoutDestination,
                stderrDestination: stderrDestination ?? state.stderrDestination,
                archivePath: archivePath ?? state.archivePath,
                members: members ?? state.members,
                excludes: excludes ?? state.excludes,
                destinationPath: destinationPath ?? state.destinationPath,
                modeList: modeList ?? state.modeList,
                modeTest: modeTest ?? state.modeTest,
                modePrint: modePrint ?? state.modePrint,
                modeFreshen: modeFreshen ?? state.modeFreshen,
                modeUpdate: modeUpdate ?? state.modeUpdate,
                overwrites: overwrites ?? state.overwrites,
                neverOverwrites: neverOverwrites ?? state.neverOverwrites,
                isQuiet: isQuiet ?? state.isQuiet,
                junksPaths: junksPaths ?? state.junksPaths,
                preservesCase: preservesCase ?? state.preservesCase,
                password: password ?? state.password
            )
        )
    }
}

private struct State: Sendable {
    let config: ToolConfiguration
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let archivePath: String?
    let members: [String]
    let excludes: [String]
    let destinationPath: String?
    let modeList: Bool
    let modeTest: Bool
    let modePrint: Bool
    let modeFreshen: Bool
    let modeUpdate: Bool
    let overwrites: Bool
    let neverOverwrites: Bool
    let isQuiet: Bool
    let junksPaths: Bool
    let preservesCase: Bool
    let password: String?

    init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination = .capture,
        stderrDestination: OutputDestination = .capture,
        archivePath: String? = nil,
        members: [String] = [],
        excludes: [String] = [],
        destinationPath: String? = nil,
        modeList: Bool = false,
        modeTest: Bool = false,
        modePrint: Bool = false,
        modeFreshen: Bool = false,
        modeUpdate: Bool = false,
        overwrites: Bool = false,
        neverOverwrites: Bool = false,
        isQuiet: Bool = false,
        junksPaths: Bool = false,
        preservesCase: Bool = false,
        password: String? = nil
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.archivePath = archivePath
        self.members = members
        self.excludes = excludes
        self.destinationPath = destinationPath
        self.modeList = modeList
        self.modeTest = modeTest
        self.modePrint = modePrint
        self.modeFreshen = modeFreshen
        self.modeUpdate = modeUpdate
        self.overwrites = overwrites
        self.neverOverwrites = neverOverwrites
        self.isQuiet = isQuiet
        self.junksPaths = junksPaths
        self.preservesCase = preservesCase
        self.password = password
    }
}

/// Internal parser for `unzip -l` output. Made `internal` (not `fileprivate`) so the test
/// suite can validate it directly with canned input via `@testable import`.
enum UnzipEntryParser {
    /// Parses the standard Info-ZIP `unzip -l` table into typed entries.
    ///
    /// The parser tolerates extra header text from the verbose listing (`unzip -lv`), skips
    /// lines that don't match the expected `<size> <date> <time> <path>` shape, and gracefully
    /// returns an empty array when no recognizable rows are present.
    static func parse(_ stdout: String) -> [UnzipEntry] {
        let lines = stdout.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // Find the first separator line ("---..."). Entries follow it until the trailing
        // separator line (or end of input).
        guard let firstSeparator = lines.firstIndex(where: isSeparatorLine) else {
            return []
        }

        var entries: [UnzipEntry] = []
        for index in (firstSeparator + 1)..<lines.count {
            let line = lines[index]
            if isSeparatorLine(line) {
                break
            }
            if let entry = parseEntryLine(line) {
                entries.append(entry)
            }
        }
        return entries
    }

    private static func isSeparatorLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { $0 == "-" || $0 == " " }
    }

    private static func parseEntryLine(_ line: String) -> UnzipEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Collapse runs of whitespace, then split into at most 4 components: size, date, time,
        // and the rest (which is the path, possibly containing single spaces).
        let parts = trimmed.split(
            maxSplits: 3,
            omittingEmptySubsequences: true,
            whereSeparator: { $0 == " " || $0 == "\t" }
        )
        guard parts.count == 4 else { return nil }

        guard let size = Int(parts[0]) else { return nil }
        let dateString = "\(parts[1]) \(parts[2])"
        // `split(maxSplits:)` with `omittingEmptySubsequences: true` still leaves
        // run-internal whitespace in the trailing component once the split limit is
        // reached, so the listing's `   path` gap survives. Trim it explicitly.
        let path = String(parts[3]).trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }

        return UnzipEntry(
            path: path,
            size: size,
            modified: parseModifiedTimestamp(dateString)
        )
    }

    private static func parseModifiedTimestamp(_ value: String) -> Date? {
        // Modern Info-ZIP emits "yyyy-MM-dd HH:mm". Older builds use "MM-dd-yyyy HH:mm".
        for format in ["yyyy-MM-dd HH:mm", "MM-dd-yyyy HH:mm"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
#endif
