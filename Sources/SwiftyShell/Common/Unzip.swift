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

    /// The entry's last-modified timestamp, parsed from the listing in the current system time
    /// zone. `nil` when the timestamp column did not match the expected `yyyy-MM-dd HH:mm`
    /// format.
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
    private var state: State

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
    /// ``workingDirectory(_:)``, ``timeout(_:)-(Duration)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that receives the current ``ToolConfiguration`` and
    ///   returns the next one.
    /// - Returns: A new ``Unzip`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        modified(self) { $0.state.config = update(state.config) }
    }

    /// Returns a copy that routes the built `unzip` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `unzip` writes status lines and listing
    /// output on stdout.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Unzip`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stdoutDestination = destination }
    }

    /// Returns a copy that routes the built `unzip` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Unzip`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        modified(self) { $0.state.stderrDestination = destination }
    }

    /// Returns a copy that sets the archive path to operate on.
    ///
    /// Calling this multiple times keeps the last value. The archive path is required for any
    /// non-trivial `unzip` invocation.
    ///
    /// - Parameter path: The path to the `.zip` archive.
    /// - Returns: A new ``Unzip`` value with the archive set.
    public func archive(_ path: String) -> Self {
        modified(self) { $0.state.archivePath = path }
    }

    /// Returns a copy with one additional member pattern appended.
    ///
    /// Member patterns are positional and follow the archive path. Without any member, `unzip`
    /// extracts every entry.
    ///
    /// - Parameter pattern: A glob pattern such as `"docs/*.md"`.
    /// - Returns: A new ``Unzip`` value with the member pattern appended.
    public func member(_ pattern: String) -> Self {
        modified(self) { $0.state.members += [pattern] }
    }

    /// Returns a copy with multiple member patterns appended.
    ///
    /// - Parameter patterns: Glob patterns to append in order.
    /// - Returns: A new ``Unzip`` value with the patterns appended.
    public func members(_ patterns: [String]) -> Self {
        modified(self) { $0.state.members += patterns }
    }

    /// Returns a copy with one exclude pattern appended (`-x <pattern>`).
    ///
    /// Exclude patterns follow the member list.
    ///
    /// - Parameter pattern: A glob pattern such as `"*.tmp"`.
    /// - Returns: A new ``Unzip`` value with the exclude pattern appended.
    public func exclude(_ pattern: String) -> Self {
        modified(self) { $0.state.excludes += [pattern] }
    }

    /// Returns a copy with multiple exclude patterns appended.
    ///
    /// - Parameter patterns: Glob patterns to append in order.
    /// - Returns: A new ``Unzip`` value with the exclude patterns appended.
    public func excludes(_ patterns: [String]) -> Self {
        modified(self) { $0.state.excludes += patterns }
    }

    /// Returns a copy that toggles list mode (`-l`).
    ///
    /// In list mode `unzip` prints a tabular listing of archive entries to stdout instead of
    /// extracting. ``entries()`` builds on top of this mode. List, ``test(_:)``, and
    /// ``printToStdout(_:)`` are mutually exclusive; the last one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-l`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func list(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.mode = toggledMode(state.mode, .list, enabled: enabled) }
    }

    /// Returns a copy that toggles test mode (`-t`).
    ///
    /// In test mode `unzip` validates archive integrity (CRC checks) without writing any
    /// extracted files. Mutually exclusive with ``list(_:)`` and ``printToStdout(_:)``; the last
    /// one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-t`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func test(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.mode = toggledMode(state.mode, .test, enabled: enabled) }
    }

    /// Returns a copy that toggles pipe-to-stdout mode (`-p`).
    ///
    /// `unzip -p` writes the contents of selected entries to stdout, suitable for piping into
    /// other commands. No filesystem entries are created. Mutually exclusive with ``list(_:)`` and
    /// ``test(_:)``; the last one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-p`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func printToStdout(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.mode = toggledMode(state.mode, .print, enabled: enabled) }
    }

    /// Returns a copy that sets the extraction destination directory (`-d <dir>`).
    ///
    /// `unzip` creates the directory if it does not exist and extracts entries into it. Calling
    /// this multiple times keeps the last value.
    ///
    /// - Parameter path: The directory to extract into.
    /// - Returns: A new ``Unzip`` value with the destination set.
    public func destination(_ path: String) -> Self {
        modified(self) { $0.state.destinationPath = path }
    }

    /// Returns a copy that toggles always-overwrite mode (`-o`).
    ///
    /// Without this flag `unzip` prompts on stdin before overwriting existing files; SwiftyShell
    /// does not feed stdin, so unattended extractions should pass `-o` (or ``neverOverwrite(_:)``)
    /// to avoid hanging. Mutually exclusive with ``neverOverwrite(_:)``; the last one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-o`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func overwrite(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.overwrite = toggledMode(state.overwrite, .always, enabled: enabled) }
    }

    /// Returns a copy that toggles never-overwrite mode (`-n`).
    ///
    /// With this flag `unzip` skips entries whose target already exists. Mutually exclusive with
    /// ``overwrite(_:)``; the last one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-n`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func neverOverwrite(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.overwrite = toggledMode(state.overwrite, .never, enabled: enabled) }
    }

    /// Returns a copy that toggles quiet mode (`-q`).
    ///
    /// Suppresses informational status lines.
    ///
    /// - Parameter enabled: `true` to add `-q`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func quiet(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.isQuiet = enabled }
    }

    /// Returns a copy that toggles junk-paths mode (`-j`).
    ///
    /// With this flag `unzip` strips directory components from extracted paths.
    ///
    /// - Parameter enabled: `true` to add `-j`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func junkPaths(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.junksPaths = enabled }
    }

    /// Returns a copy that restores archived setuid, setgid, and sticky permission bits (`-K`).
    ///
    /// Info-ZIP clears these privileged permission bits by default. Enable this only for trusted
    /// archives whose entries and ownership have been independently verified: restoring them can
    /// create executables that run with elevated privileges.
    ///
    /// - Parameter enabled: `true` to add `-K`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func restoreSecurityMetadata(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.restoresSecurityMetadata = enabled }
    }

    /// Returns a copy that toggles freshen mode (`-f`).
    ///
    /// Replaces only existing on-disk entries that are older than the archive copy. Mutually
    /// exclusive with ``updateOnly(_:)``; the last one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-f`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func freshen(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.refresh = toggledMode(state.refresh, .freshen, enabled: enabled) }
    }

    /// Returns a copy that toggles update mode (`-u`).
    ///
    /// Like ``freshen(_:)`` but also creates new files that don't yet exist on disk. Mutually
    /// exclusive with ``freshen(_:)``; the last one enabled wins.
    ///
    /// - Parameter enabled: `true` to add `-u`. Defaults to `true`.
    /// - Returns: A new ``Unzip`` value with the flag applied.
    public func updateOnly(_ enabled: Bool = true) -> Self {
        modified(self) { $0.state.refresh = toggledMode(state.refresh, .update, enabled: enabled) }
    }

    /// Returns a copy that supplies a password on the command line (`-P <password>`).
    ///
    /// > Warning: The password is visible to other users on the system via `ps` because it is
    /// > placed on the subprocess argv.
    ///
    /// - Parameter value: The password to forward to `unzip`.
    /// - Returns: A new ``Unzip`` value with the password applied.
    public func password(_ value: String) -> Self {
        modified(self) { $0.state.password = value }
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

        if let mode = state.mode { arguments.append(mode.flag) }
        if let refresh = state.refresh { arguments.append(refresh.flag) }

        if let overwrite = state.overwrite { arguments.append(overwrite.flag) }
        if state.isQuiet { arguments.append("-q") }
        if state.junksPaths { arguments.append("-j") }
        if state.restoresSecurityMetadata { arguments.append("-K") }

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

    /// Returns a workflow that runs `unzip -l` and parses the listing.
    ///
    /// The workflow forces a captured `unzip -l` listing regardless of any conflicting
    /// extraction or stdout-redirection state the caller may have configured. Members and
    /// excludes are forwarded so `entries()` can scope to a subset of the archive.
    ///
    /// ```swift
    /// let entries = try await Unzip(context: context)
    ///     .archive("/tmp/release.zip")
    ///     .entries()
    ///     .run()
    /// ```
    ///
    /// - Returns: A ``Workflow`` producing parsed ``UnzipEntry`` values.
    public func entries() -> Workflow<[UnzipEntry]> {
        let context = state.config.context
        let cmd = modified(self) {
            $0.state.stdoutDestination = .capture
            $0.state.destinationPath = nil
            $0.state.mode = .list
        }.command()
        return Workflow {
            let output = try await cmd.run(in: context)
            return UnzipEntryParser.parse(try output.validatedStdout(for: cmd))
        }
    }
}

/// The mutually exclusive non-extracting modes; `nil` means extract.
private enum UnzipMode: Sendable, Equatable {
    case list
    case test
    case print

    var flag: String {
        switch self {
        case .list: "-l"
        case .test: "-t"
        case .print: "-p"
        }
    }
}

/// The mutually exclusive refresh policies for extraction.
private enum UnzipRefresh: Sendable, Equatable {
    case freshen
    case update

    var flag: String {
        switch self {
        case .freshen: "-f"
        case .update: "-u"
        }
    }
}

/// The mutually exclusive answers to "overwrite an existing file?"; `nil` means prompt.
private enum UnzipOverwrite: Sendable, Equatable {
    case always
    case never

    var flag: String {
        switch self {
        case .always: "-o"
        case .never: "-n"
        }
    }
}

private struct State: Sendable {
    var config: ToolConfiguration
    var stdoutDestination: OutputDestination = .capture
    var stderrDestination: OutputDestination = .capture
    var archivePath: String? = nil
    var members: [String] = []
    var excludes: [String] = []
    var destinationPath: String? = nil
    var mode: UnzipMode? = nil
    var refresh: UnzipRefresh? = nil
    var overwrite: UnzipOverwrite? = nil
    var isQuiet: Bool = false
    var junksPaths: Bool = false
    var restoresSecurityMetadata: Bool = false
    var password: String? = nil
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
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
#endif
