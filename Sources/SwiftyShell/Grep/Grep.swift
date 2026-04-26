#if Grep
import Foundation

/// The pattern mode used by `grep`.
///
/// Selects between fixed-string matching (passed as `-F`) and extended regular expressions
/// (passed as `-E`). The matching mode flag is added to the final argv automatically based on
/// which case is in use.
public enum GrepPattern: Sendable, Equatable, Hashable {
    /// A literal (fixed-string) match. Maps to `grep -F`.
    case literal(String)

    /// An extended regular expression match. Maps to `grep -E`.
    case regularExpression(String)

    fileprivate var value: String {
        switch self {
        case let .literal(value), let .regularExpression(value):
            value
        }
    }

    fileprivate var optionArguments: [String] {
        switch self {
        case .literal:
            ["-F"]
        case .regularExpression:
            ["-E"]
        }
    }
}

/// A fluent wrapper for the `grep` command.
///
/// ``Grep`` supports literal and regular-expression patterns, case-insensitive
/// matching, recursive search, and all standard tool configuration overrides.
/// Each run returns raw ``ShellOutput`` with matching lines in `stdout`.
///
/// Use ``init(_:context:)`` for literal searches. This example searches one file and includes line
/// numbers before each match.
///
/// ```swift
/// let result = try await Grep("TODO", context: context)
///     .file("Sources/main.swift")
///     .lineNumbers()    // Prefix each matching line with its line number.
///     .run()
///
/// print(result.stdout)
/// ```
///
/// Use ``regex(_:context:)`` when the pattern should be interpreted as an extended regular
/// expression instead of a literal string.
///
/// ```swift
/// let result = try await Grep.regex("^import\\s+Foundation", context: context)
///     .recursive()     // Search below Sources/.
///     .ignoreCase()    // Match imports regardless of case.
///     .file("Sources/")
///     .run()
/// ```
///
/// Build a ``Command`` with ``command()`` when `grep` should be a pipeline stage.
///
/// ```swift
/// let output = try await Command("ls", arguments: "-la")
///     .pipe(to: Grep(".swift").command())
///     .run(in: context)
/// ```
public struct Grep: RunnableCommandFamily {
    /// Shared configuration applied to commands produced by this client.
    ///
    /// Holds the executor, environment, working-directory, timeout, and output-limit overrides
    /// that get merged onto the built command.
    public let config: ToolConfiguration

    /// The stdout handling strategy for built commands. Defaults to ``OutputDestination/capture``.
    public let stdoutDestination: OutputDestination

    /// The stderr handling strategy for built commands. Defaults to ``OutputDestination/capture``.
    public let stderrDestination: OutputDestination

    /// The grep pattern mode and value.
    ///
    /// Determined by the constructor used: ``init(_:context:)`` produces ``GrepPattern/literal(_:)``;
    /// ``regex(_:context:)`` produces ``GrepPattern/regularExpression(_:)``.
    public let pattern: GrepPattern

    /// Whether matches ignore case (`grep -i`).
    public let isCaseInsensitive: Bool

    /// Whether the match is inverted to return non-matching lines (`grep -v`).
    public let isInverted: Bool

    /// Whether grep recurses into directories (`grep -r`).
    public let isRecursive: Bool

    /// Whether matching line numbers are prefixed to each output line (`grep -n`).
    public let includesLineNumbers: Bool

    /// Whether grep returns only the count of matching lines per file (`grep -c`).
    public let countsOnly: Bool

    /// File paths searched by grep. Empty means read from stdin (typical for pipeline use).
    public let filePaths: [String]

    /// The shell context used when running this command family.
    ///
    /// Forwarded from ``config`` so commands built by ``command()`` and invocations of
    /// ``run()`` share the same executor and defaults.
    public var context: ShellContext { config.context }

    /// Creates a literal-match grep command family.
    ///
    /// The pattern is treated as a fixed string; the executor passes `-F` to `grep`. Switch to
    /// regex mode with ``regex(_:context:)``.
    ///
    /// ```swift
    /// let result = try await Grep("TODO", context: context)
    ///     .file("Sources/main.swift")
    ///     .lineNumbers()
    ///     .run()
    /// ```
    ///
    /// - Parameters:
    ///   - pattern: The literal string to search for.
    ///   - context: The shell context whose executor, search paths, environment, and defaults
    ///     will be used. Defaults to a freshly constructed ``ShellContext``.
    public init(_ pattern: String, context: ShellContext = .init()) {
        self.config = ToolConfiguration(context: context)
        self.stdoutDestination = .capture
        self.stderrDestination = .capture
        self.pattern = .literal(pattern)
        self.isCaseInsensitive = false
        self.isInverted = false
        self.isRecursive = false
        self.includesLineNumbers = false
        self.countsOnly = false
        self.filePaths = []
    }

    private init(
        config: ToolConfiguration,
        stdoutDestination: OutputDestination,
        stderrDestination: OutputDestination,
        pattern: GrepPattern,
        isCaseInsensitive: Bool,
        isInverted: Bool,
        isRecursive: Bool,
        includesLineNumbers: Bool,
        countsOnly: Bool,
        filePaths: [String]
    ) {
        self.config = config
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
        self.pattern = pattern
        self.isCaseInsensitive = isCaseInsensitive
        self.isInverted = isInverted
        self.isRecursive = isRecursive
        self.includesLineNumbers = includesLineNumbers
        self.countsOnly = countsOnly
        self.filePaths = filePaths
    }

    /// Creates a regular-expression grep command family.
    ///
    /// The pattern is treated as an extended regular expression; the executor passes `-E` to
    /// `grep`. Use ``init(_:context:)`` for fixed-string searches.
    ///
    /// ```swift
    /// let result = try await Grep.regex("^import\\s+Foundation", context: context)
    ///     .recursive()
    ///     .file("Sources/")
    ///     .run()
    /// ```
    ///
    /// - Parameters:
    ///   - pattern: The extended regular expression to match.
    ///   - context: The shell context whose executor, search paths, environment, and defaults
    ///     will be used. Defaults to a freshly constructed ``ShellContext``.
    /// - Returns: A new ``Grep`` value configured for regex matching.
    public static func regex(_ pattern: String, context: ShellContext = .init()) -> Self {
        Self(
            config: ToolConfiguration(context: context),
            stdoutDestination: .capture,
            stderrDestination: .capture,
            pattern: .regularExpression(pattern),
            isCaseInsensitive: false,
            isInverted: false,
            isRecursive: false,
            includesLineNumbers: false,
            countsOnly: false,
            filePaths: []
        )
    }

    /// Returns a copy with updated shared tool configuration.
    ///
    /// Funnel for the protocol-provided helpers (``executable(_:)``, ``env(_:_:)``,
    /// ``workingDirectory(_:)``, ``timeout(_:)``, ``outputLimit(_:)``).
    ///
    /// - Parameter update: A pure function that returns the next ``ToolConfiguration``.
    /// - Returns: A new ``Grep`` value with the updated configuration applied.
    public func updatingConfiguration(
        _ update: (ToolConfiguration) -> ToolConfiguration
    ) -> Self {
        copy(config: update(config))
    }

    /// Returns a copy that routes the built `grep` command's stdout to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. Stdout carries the matching lines, so this is
    /// the stream most callers will inspect.
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Grep`` value with the stdout destination applied.
    public func settingStdoutDestination(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy that routes the built `grep` command's stderr to the given destination.
    ///
    /// Defaults to ``OutputDestination/capture``. `grep` writes diagnostics here when files
    /// cannot be read.
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Grep`` value with the stderr destination applied.
    public func settingStderrDestination(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a copy that performs case-insensitive matching.
    ///
    /// Maps to the `-i` flag.
    ///
    /// - Parameter enabled: `true` to add `-i`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Grep`` value with the flag applied.
    public func ignoreCase(_ enabled: Bool = true) -> Self {
        copy(isCaseInsensitive: enabled)
    }

    /// Returns a copy that inverts the match — emits lines that do **not** match the pattern.
    ///
    /// Maps to the `-v` flag.
    ///
    /// - Parameter enabled: `true` to add `-v`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Grep`` value with the flag applied.
    public func invertMatch(_ enabled: Bool = true) -> Self {
        copy(isInverted: enabled)
    }

    /// Returns a copy that searches directories recursively.
    ///
    /// Maps to the `-r` flag. When recursive search is enabled, supply directory paths via
    /// ``file(_:)`` or ``files(_:)``.
    ///
    /// - Parameter enabled: `true` to add `-r`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Grep`` value with the flag applied.
    public func recursive(_ enabled: Bool = true) -> Self {
        copy(isRecursive: enabled)
    }

    /// Returns a copy that prefixes each output line with its 1-based line number.
    ///
    /// Maps to the `-n` flag.
    ///
    /// - Parameter enabled: `true` to add `-n`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Grep`` value with the flag applied.
    public func lineNumbers(_ enabled: Bool = true) -> Self {
        copy(includesLineNumbers: enabled)
    }

    /// Returns a copy that emits only the count of matching lines per file.
    ///
    /// Maps to the `-c` flag. Suppresses the matching lines themselves.
    ///
    /// - Parameter enabled: `true` to add `-c`; `false` to omit it. Defaults to `true`.
    /// - Returns: A new ``Grep`` value with the flag applied.
    public func count(_ enabled: Bool = true) -> Self {
        copy(countsOnly: enabled)
    }

    /// Returns a copy with one additional file path appended to search.
    ///
    /// With no file paths configured, `grep` reads from stdin — useful when the family is used
    /// as a pipeline stage. With one or more file paths, `grep` searches each file (and, when
    /// ``recursive(_:)`` is enabled, descends into directory paths).
    ///
    /// - Parameter path: A file or directory path to search.
    /// - Returns: A new ``Grep`` value with the path appended.
    public func file(_ path: String) -> Self {
        copy(filePaths: filePaths + [path])
    }

    /// Returns a copy with multiple file paths appended to search.
    ///
    /// - Parameter paths: The file or directory paths to append, in order.
    /// - Returns: A new ``Grep`` value with the paths appended.
    public func files(_ paths: [String]) -> Self {
        copy(filePaths: filePaths + paths)
    }

    /// Builds the raw `grep` command represented by the current builder state.
    ///
    /// Argv is assembled in the order: behavior flags (`-i`, `-v`, `-r`, `-n`, `-c`), then the
    /// pattern-mode flag (`-F` or `-E`), then `--`, then the pattern string, then file paths.
    /// The `--` sentinel ensures patterns starting with `-` are not interpreted as options. The
    /// shared ``ToolConfiguration`` overrides are merged in via ``ToolConfiguration/apply(to:)``.
    ///
    /// - Returns: A ``Command`` ready for execution or pipeline composition.
    public func command() -> Command {
        var arguments: [String] = []

        if isCaseInsensitive {
            arguments.append("-i")
        }
        if isInverted {
            arguments.append("-v")
        }
        if isRecursive {
            arguments.append("-r")
        }
        if includesLineNumbers {
            arguments.append("-n")
        }
        if countsOnly {
            arguments.append("-c")
        }

        arguments.append(contentsOf: pattern.optionArguments)
        arguments.append("--")
        arguments.append(pattern.value)
        arguments.append(contentsOf: filePaths)

        let base = Command("grep")
            .args(arguments)
            .stdout(stdoutDestination)
            .stderr(stderrDestination)

        return config.apply(to: base)
    }

    private func copy(
        config: ToolConfiguration? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil,
        pattern: GrepPattern? = nil,
        isCaseInsensitive: Bool? = nil,
        isInverted: Bool? = nil,
        isRecursive: Bool? = nil,
        includesLineNumbers: Bool? = nil,
        countsOnly: Bool? = nil,
        filePaths: [String]? = nil
    ) -> Self {
        Self(
            config: config ?? self.config,
            stdoutDestination: stdoutDestination ?? self.stdoutDestination,
            stderrDestination: stderrDestination ?? self.stderrDestination,
            pattern: pattern ?? self.pattern,
            isCaseInsensitive: isCaseInsensitive ?? self.isCaseInsensitive,
            isInverted: isInverted ?? self.isInverted,
            isRecursive: isRecursive ?? self.isRecursive,
            includesLineNumbers: includesLineNumbers ?? self.includesLineNumbers,
            countsOnly: countsOnly ?? self.countsOnly,
            filePaths: filePaths ?? self.filePaths
        )
    }
}
#endif
