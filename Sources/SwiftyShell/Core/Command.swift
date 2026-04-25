import Foundation

/// A value describing a single shell command and its execution overrides.
///
/// ``Command`` is the fundamental unit of execution in SwiftyShell. Build a command
/// by naming the executable, then chain fluent modifiers to add arguments, set
/// environment variables, redirect output, or constrain execution:
///
/// A basic command captures stdout and stderr in ``ShellOutput``:
///
/// ```swift
/// let output = try await Command("echo", "hello").run(in: context)
/// print(output.stdout)
/// ```
///
/// Fluent modifiers return new immutable command values, so this configures only this invocation:
///
/// ```swift
/// let deployOutput = try await Command("ruby", "deploy.rb")
///     .env("RAILS_ENV", "production")
///     .workingDirectory("/var/app")
///     .timeout(120)
///     .run(in: context)
/// ```
///
/// Redirect stdout when output should go to a file instead of memory:
///
/// ```swift
/// try await Command("swift", "build", "--verbose")
///     .stdout(.file(path: "/tmp/build.log", append: false))
///     .run(in: context)
/// ```
///
/// Use ``pipe(to:)`` to connect commands without writing a shell string:
///
/// ```swift
/// let output = try await Command("ls", "-la")
///     .pipe(to: Grep(".swift").command())
///     .run(in: context)
/// ```
///
/// All ``Command`` values are immutable; every modifier returns a new copy.
public struct Command: Sendable {
    /// The executable name originally requested for the command.
    ///
    /// This is the value passed to ``init(_:_:)``. It may be a bare program name (such as
    /// `"git"`) which the executor resolves against ``ShellContext/searchPaths``, or it may be
    /// an absolute path. Use ``executableOverride`` to inspect any explicit override applied via
    /// ``executable(_:)``.
    public let executableName: String

    /// The argv arguments passed to the executable.
    ///
    /// Each element becomes a separate argument when the process is spawned, so values containing
    /// spaces are passed as a single argument rather than being split by a shell.
    public let arguments: [String]

    /// An optional absolute or relative executable path that replaces ``executableName`` at
    /// execution time.
    ///
    /// Set with ``executable(_:)``. When `nil`, the executor resolves ``executableName`` against
    /// ``ShellContext/searchPaths``.
    public let executableOverride: String?

    /// Environment variable overrides applied when running the command.
    ///
    /// These values are merged on top of ``ShellContext/environment`` for this invocation only.
    /// Use ``env(_:_:)`` or ``env(_:)`` to populate.
    public let environmentOverrides: [String: String]

    /// An optional working directory override applied when running the command.
    ///
    /// When non-`nil`, this path replaces ``ShellContext/workingDirectory`` for this invocation
    /// only. Set with ``workingDirectory(_:)``.
    public let workingDirectoryOverride: String?

    /// An optional per-command timeout in seconds.
    ///
    /// When non-`nil`, this value replaces ``ShellContext/defaultTimeout`` for this invocation.
    /// A value of `0` disables waiting beyond the immediate process scheduler tick. Set with
    /// ``timeout(_:)``.
    public let timeoutOverride: TimeInterval?

    /// An optional per-command output capture limit in bytes.
    ///
    /// When non-`nil`, this value replaces ``ShellContext/defaultOutputLimit``. Exceeding the
    /// limit raises ``ShellError/outputLimitExceeded(command:limit:partialOutput:)``. Set with
    /// ``outputLimit(_:)``.
    public let outputLimitOverride: Int?

    /// The stdout handling strategy for this command.
    ///
    /// Defaults to ``OutputDestination/capture``, which retains stdout in ``ShellOutput/stdout``.
    /// Change with ``stdout(_:)`` to discard or write to a file.
    public let stdoutDestination: OutputDestination

    /// The stderr handling strategy for this command.
    ///
    /// Defaults to ``OutputDestination/capture``, which retains stderr in ``ShellOutput/stderr``.
    /// Change with ``stderr(_:)`` to discard or write to a file.
    public let stderrDestination: OutputDestination

    /// Creates a command from an executable name and optional argv arguments.
    ///
    /// The executable name is resolved against ``ShellContext/searchPaths`` at execution time
    /// unless an override is later supplied via ``executable(_:)``. Each element of `arguments`
    /// is forwarded as a single argv entry, so callers do not need to perform shell quoting.
    ///
    /// The example below builds a command equivalent to `echo hello world` and runs it:
    ///
    /// ```swift
    /// let output = try await Command("echo", "hello", "world").run(in: context)
    /// ```
    ///
    /// - Parameters:
    ///   - executable: The executable name or absolute path to invoke.
    ///   - arguments: The argv arguments to pass to the executable. Each variadic element becomes
    ///     a separate argument; no shell parsing or quoting is performed.
    public init(_ executable: String, _ arguments: String...) {
        self.executableName = executable
        self.arguments = arguments
        self.executableOverride = nil
        self.environmentOverrides = [:]
        self.workingDirectoryOverride = nil
        self.timeoutOverride = nil
        self.outputLimitOverride = nil
        self.stdoutDestination = .capture
        self.stderrDestination = .capture
    }

    private init(
        executableName: String,
        arguments: [String],
        executableOverride: String?,
        environmentOverrides: [String: String],
        workingDirectoryOverride: String?,
        timeoutOverride: TimeInterval?,
        outputLimitOverride: Int?,
        stdoutDestination: OutputDestination,
        stderrDestination: OutputDestination
    ) {
        self.executableName = executableName
        self.arguments = arguments
        self.executableOverride = executableOverride
        self.environmentOverrides = environmentOverrides
        self.workingDirectoryOverride = workingDirectoryOverride
        self.timeoutOverride = timeoutOverride
        self.outputLimitOverride = outputLimitOverride
        self.stdoutDestination = stdoutDestination
        self.stderrDestination = stderrDestination
    }

    /// Returns a copy of the command with an explicit executable path.
    ///
    /// Use this to bypass ``ShellContext/searchPaths`` resolution and invoke a specific binary —
    /// for example to pin to a Homebrew installation or a tool inside a project's vendor
    /// directory. The original ``executableName`` is preserved for display and debugging.
    ///
    /// The example below pins `git` to the Xcode-bundled binary regardless of `PATH`:
    ///
    /// ```swift
    /// try await Command("git", "status")
    ///     .executable("/Applications/Xcode.app/Contents/Developer/usr/bin/git")
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter path: An absolute or relative path to the executable to invoke.
    /// - Returns: A new ``Command`` with the executable override applied.
    public func executable(_ path: String) -> Self {
        copy(executableOverride: path)
    }

    /// Returns a copy of the command with one additional argv argument appended.
    ///
    /// Existing arguments are preserved. The new value is added to the end of ``arguments``.
    /// Because the value is treated as a single argv entry, spaces inside `value` are passed
    /// verbatim to the executable rather than being interpreted as separators.
    ///
    /// ```swift
    /// let cmd = Command("git").arg("status").arg("--short")
    /// // Equivalent to: git status --short
    /// ```
    ///
    /// - Parameter value: The argv argument to append.
    /// - Returns: A new ``Command`` with the additional argument.
    public func arg(_ value: String) -> Self {
        copy(arguments: arguments + [value])
    }

    /// Returns a copy of the command with multiple argv arguments appended.
    ///
    /// Existing arguments are preserved; the new values are appended in order.
    ///
    /// ```swift
    /// let cmd = Command("git").args(["log", "--oneline", "-n", "5"])
    /// ```
    ///
    /// - Parameter values: The argv arguments to append, in order.
    /// - Returns: A new ``Command`` with the additional arguments.
    public func args(_ values: [String]) -> Self {
        copy(arguments: arguments + values)
    }

    /// Returns a copy of the command with one environment variable set or replaced.
    ///
    /// The override is merged onto ``ShellContext/environment`` at execution time. If the same
    /// `name` is supplied to this method multiple times, the last value wins. To remove a
    /// variable from the inherited environment, set its value to the empty string and let the
    /// child process treat it as unset.
    ///
    /// ```swift
    /// try await Command("ruby", "deploy.rb")
    ///     .env("RAILS_ENV", "production")
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameters:
    ///   - name: The environment variable name.
    ///   - value: The value to assign for this command's execution.
    /// - Returns: A new ``Command`` with the environment override applied.
    public func env(_ name: String, _ value: String) -> Self {
        var overrides = environmentOverrides
        overrides[name] = value
        return copy(environmentOverrides: overrides)
    }

    /// Returns a copy of the command with multiple environment variable overrides merged in.
    ///
    /// Keys in `values` are merged on top of any overrides already configured on the command;
    /// when a key already exists in ``environmentOverrides``, the value from `values` wins.
    /// The merged set is then applied on top of ``ShellContext/environment`` at execution time.
    ///
    /// ```swift
    /// try await Command("npm", "test")
    ///     .env(["CI": "true", "NODE_ENV": "test"])
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter values: A dictionary of environment variable name/value pairs to merge.
    /// - Returns: A new ``Command`` with the merged environment overrides applied.
    public func env(_ values: [String: String]) -> Self {
        copy(environmentOverrides: environmentOverrides.merging(values) { _, new in new })
    }

    /// Returns a copy of the command that runs in the given working directory.
    ///
    /// The path replaces ``ShellContext/workingDirectory`` for this invocation only. Both
    /// absolute and relative paths are accepted; relative paths are resolved by the executor
    /// against the current process's working directory at spawn time.
    ///
    /// ```swift
    /// try await Command("git", "pull")
    ///     .workingDirectory("/var/app")
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter path: The directory in which to spawn the command's process.
    /// - Returns: A new ``Command`` with the working-directory override applied.
    public func workingDirectory(_ path: String) -> Self {
        copy(workingDirectoryOverride: path)
    }

    /// Returns a copy of the command with a per-command timeout in seconds.
    ///
    /// When the running process exceeds `seconds`, the executor terminates it and throws
    /// ``ShellError/timeout(command:duration:partialOutput:)`` containing whatever output was
    /// captured before termination. The value must be greater than or equal to zero — negative
    /// values raise ``ShellError/invalidConfiguration(description:)`` at execution time.
    ///
    /// This override replaces ``ShellContext/defaultTimeout`` for this invocation only.
    ///
    /// ```swift
    /// try await Command("swift", "build")
    ///     .timeout(120)   // abort if the build runs longer than two minutes
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter seconds: The maximum duration to wait for the process, in seconds. Must be
    ///   `>= 0`.
    /// - Returns: A new ``Command`` with the timeout override applied.
    public func timeout(_ seconds: TimeInterval) -> Self {
        copy(timeoutOverride: seconds)
    }

    /// Returns a copy of the command with a per-command captured-output limit in bytes.
    ///
    /// The limit applies to the combined size of captured stdout and stderr. When exceeded,
    /// the executor terminates the process and throws
    /// ``ShellError/outputLimitExceeded(command:limit:partialOutput:)`` containing the captured
    /// portion. The value must be greater than or equal to zero.
    ///
    /// Streams routed through ``OutputDestination/file(path:append:)`` or
    /// ``OutputDestination/discard`` do not contribute to the captured size.
    ///
    /// ```swift
    /// try await Command("ls", "-R", "/")
    ///     .outputLimit(1_048_576)   // cap captured output at 1 MB
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter bytes: The maximum number of bytes to retain in memory. Must be `>= 0`.
    /// - Returns: A new ``Command`` with the output-limit override applied.
    public func outputLimit(_ bytes: Int) -> Self {
        copy(outputLimitOverride: bytes)
    }

    /// Returns a copy of the command that routes stdout to the given destination.
    ///
    /// The default destination is ``OutputDestination/capture``, which keeps stdout in memory
    /// for inspection via ``ShellOutput/stdout``. Use ``OutputDestination/file(path:append:)``
    /// to stream stdout to disk or ``OutputDestination/discard`` to drop it entirely.
    ///
    /// The example below writes verbose build output to a log file instead of capturing it in
    /// memory, which is helpful when output can be large:
    ///
    /// ```swift
    /// try await Command("swift", "build", "--verbose")
    ///     .stdout(.file(path: "/tmp/build.log", append: false))
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Command`` with the stdout destination applied.
    public func stdout(_ destination: OutputDestination) -> Self {
        copy(stdoutDestination: destination)
    }

    /// Returns a copy of the command that routes stderr to the given destination.
    ///
    /// Behaves like ``stdout(_:)`` but for the stderr stream. Defaults to
    /// ``OutputDestination/capture``.
    ///
    /// ```swift
    /// try await Command("make", "clean")
    ///     .stderr(.discard)   // suppress noisy progress messages
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Command`` with the stderr destination applied.
    public func stderr(_ destination: OutputDestination) -> Self {
        copy(stderrDestination: destination)
    }

    /// Returns a two-stage ``Pipeline`` connecting this command's stdout to `next`'s stdin.
    ///
    /// The result is equivalent to writing `self | next` in a shell, but the connection is
    /// performed by SwiftyShell rather than by spawning a shell interpreter. Each stage runs as
    /// a separate process; only the final stage's output is returned by
    /// ``Pipeline/run(in:)``.
    ///
    /// Chain additional stages by calling ``Pipeline/pipe(to:)`` on the returned value:
    ///
    /// ```swift
    /// let pipeline = Command("ls", "-la")
    ///     .pipe(to: Command("grep", ".swift"))
    ///     .pipe(to: Command("wc", "-l"))
    ///
    /// let output = try await pipeline.run(in: context)
    /// ```
    ///
    /// - Parameter next: The downstream command that receives this command's stdout as stdin.
    /// - Returns: A ``Pipeline`` with `self` followed by `next`.
    public func pipe(to next: Command) -> Pipeline {
        Pipeline(stages: [self, next])
    }

    /// Runs the command using the provided shell context and returns its captured output.
    ///
    /// Resolution, environment merging, working-directory selection, timeout and output-limit
    /// enforcement, and exit-code handling are all delegated to ``ShellContext/executor``. A
    /// non-zero exit raises ``ShellError/exitFailure(command:output:)``; other failure modes
    /// surface as the matching ``ShellError`` case.
    ///
    /// ```swift
    /// let output = try await Command("git", "rev-parse", "HEAD").run(in: context)
    /// let sha = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    /// ```
    ///
    /// - Parameter context: The shell context that provides defaults and the executor. Defaults
    ///   to a freshly constructed ``ShellContext``.
    /// - Returns: The captured ``ShellOutput`` from the process.
    /// - Throws: ``ShellError`` describing the failure mode (timeout, non-zero exit, decoding
    ///   failure, output-limit overflow, cancellation, spawn error, or invalid configuration).
    public func run(in context: ShellContext = .init()) async throws -> ShellOutput {
        try await context.executor.execute(self, in: context)
    }

    /// Returns a shell-quoted string representation of the command suitable for display or logging.
    ///
    /// Components containing whitespace are wrapped in double quotes with embedded quotes
    /// escaped. The result is intended for human-readable diagnostics — not for re-parsing by a
    /// shell.
    ///
    /// - Parameter resolvedExecutable: When supplied, this overrides the executable portion
    ///   of the display string. Pass the resolved absolute path returned by the executor to
    ///   show exactly which binary ran.
    /// - Returns: A string of the form `executable [arg ...]` with arguments quoted when necessary.
    public func displayString(using resolvedExecutable: String? = nil) -> String {
        ([resolvedExecutable ?? executableOverride ?? executableName] + arguments)
            .map(Self.quoteIfNeeded)
            .joined(separator: " ")
    }

    internal static func quoteIfNeeded(_ component: String) -> String {
        if component.contains(where: \.isWhitespace) {
            return "\"\(component.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return component
    }

    private func copy(
        executableName: String? = nil,
        arguments: [String]? = nil,
        executableOverride: String?? = nil,
        environmentOverrides: [String: String]? = nil,
        workingDirectoryOverride: String?? = nil,
        timeoutOverride: TimeInterval?? = nil,
        outputLimitOverride: Int?? = nil,
        stdoutDestination: OutputDestination? = nil,
        stderrDestination: OutputDestination? = nil
    ) -> Self {
        Self(
            executableName: executableName ?? self.executableName,
            arguments: arguments ?? self.arguments,
            executableOverride: executableOverride ?? self.executableOverride,
            environmentOverrides: environmentOverrides ?? self.environmentOverrides,
            workingDirectoryOverride: workingDirectoryOverride ?? self.workingDirectoryOverride,
            timeoutOverride: timeoutOverride ?? self.timeoutOverride,
            outputLimitOverride: outputLimitOverride ?? self.outputLimitOverride,
            stdoutDestination: stdoutDestination ?? self.stdoutDestination,
            stderrDestination: stderrDestination ?? self.stderrDestination
        )
    }
}

extension Command: CustomStringConvertible {
    /// Returns the shell command as it would appear on the command line.
    public var description: String {
        displayString()
    }
}

extension Command: CustomDebugStringConvertible {
    /// Returns a detailed debug representation including all active overrides.
    public var debugDescription: String {
        var parts = ["Command(\(displayString().debugDescription)"]
        if let override = executableOverride { parts.append("executable: \(override.debugDescription)") }
        if !environmentOverrides.isEmpty { parts.append("env: \(environmentOverrides)") }
        if let wd = workingDirectoryOverride { parts.append("workingDirectory: \(wd.debugDescription)") }
        if let timeout = timeoutOverride { parts.append("timeout: \(timeout)s") }
        if let limit = outputLimitOverride { parts.append("outputLimit: \(limit)") }
        if stdoutDestination != .capture { parts.append("stdout: \(stdoutDestination)") }
        if stderrDestination != .capture { parts.append("stderr: \(stderrDestination)") }
        return parts.joined(separator: ", ") + ")"
    }
}
