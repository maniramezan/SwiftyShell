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
/// let output = try await Command("echo", arguments: "hello").run(in: context)
/// print(output.stdout)
/// ```
///
/// Fluent modifiers return new immutable command values, so this configures only this invocation:
///
/// ```swift
/// let deployOutput = try await Command("ruby", arguments: "deploy.rb")
///     .env("RAILS_ENV", "production")
///     .workingDirectory("/var/app")
///     .timeout(.seconds(120))
///     .run(in: context)
/// ```
///
/// Redirect stdout when output should go to a file instead of memory:
///
/// ```swift
/// try await Command("swift", arguments: "build", "--verbose")
///     .stdout(.file(path: "/tmp/build.log", append: false))
///     .run(in: context)
/// ```
///
/// Use ``pipe(to:)`` to connect commands without writing a shell string:
///
/// ```swift
/// let output = try await Command("ls", arguments: "-la")
///     .pipe(to: Command("grep", arguments: ".swift"))
///     .run(in: context)
/// ```
///
/// All ``Command`` values are immutable; every modifier returns a new copy.
public struct Command: Sendable {
    private var options = ExecutionOptions()

    /// The executable name originally requested for the command.
    ///
    /// This is the value passed to ``init(_:arguments:)-(_,String...)``. It may be a bare program name (such as
    /// `"git"`) which the executor resolves against ``ShellContext/searchPaths``, or it may be
    /// an absolute path. Use ``executableOverride`` to inspect any explicit override applied via
    /// ``executable(_:)``.
    public let executableName: String

    /// The argv arguments passed to the executable.
    ///
    /// Each element becomes a separate argument when the process is spawned, so values containing
    /// spaces are passed as a single argument rather than being split by a shell.
    public private(set) var arguments: [String]

    /// An optional absolute or relative executable path that replaces ``executableName`` at
    /// execution time.
    ///
    /// Set with ``executable(_:)``. When `nil`, the executor resolves ``executableName`` against
    /// ``ShellContext/searchPaths``.
    public var executableOverride: String? { options.executableOverride }

    /// Environment variable overrides applied when running the command.
    ///
    /// These values are merged on top of ``ShellContext/environment`` for this invocation only.
    /// Use ``env(_:_:)`` or ``env(_:)`` to populate.
    public var environmentOverrides: [String: String] { options.environmentOverrides }

    /// Environment variables removed from the inherited environment for this invocation.
    ///
    /// Names here are absent from the child's environment even when ``ShellContext/environment``
    /// defines them. Use ``unsetEnv(_:)-(String...)`` to populate. A name is never in both this set and
    /// ``environmentOverrides``: whichever call came last wins.
    public var unsetEnvironmentVariables: Set<String> { options.unsetEnvironmentVariables }

    /// An optional working directory override applied when running the command.
    ///
    /// When non-`nil`, this path replaces ``ShellContext/workingDirectory`` for this invocation
    /// only. Set with ``workingDirectory(_:)``.
    public var workingDirectoryOverride: String? { options.workingDirectoryOverride }

    /// An optional per-command timeout.
    ///
    /// When non-`nil`, this value replaces ``ShellContext/defaultTimeout`` for this invocation.
    /// A value of `.zero` disables waiting beyond the immediate process scheduler tick. Set with
    /// ``timeout(_:)-(Duration)``.
    public var timeoutOverride: Duration? { options.timeoutOverride }

    /// An optional per-command output capture limit in bytes.
    ///
    /// When non-`nil`, this value replaces ``ShellContext/defaultOutputLimit``. A value of `0`
    /// means unlimited (no cap). A positive value enforces that byte limit — exceeding it
    /// raises ``ShellError/outputLimitExceeded(command:limit:partialOutput:)``. Set with
    /// ``outputLimit(_:)``.
    public var outputLimitOverride: Int? { options.outputLimitOverride }

    /// The stdout handling strategy for this command.
    ///
    /// Defaults to ``OutputDestination/capture``, which retains stdout in ``ShellOutput/stdout``.
    /// Change with ``stdout(_:)`` to discard or write to a file.
    public private(set) var stdoutDestination: OutputDestination = .capture

    /// Where this command's stdin comes from.
    ///
    /// Defaults to ``InputSource/none``, an empty stdin. Change with ``stdin(_:)``.
    public private(set) var stdinSource: InputSource = .none

    /// Whether a spawned process keeps its captured output for ``SpawnedProcess/waitForExit()``.
    ///
    /// `false` (the default for ``spawn(in:teardown:)``) streams output live without retaining it,
    /// so a long-running process cannot grow memory over its lifetime. Set it with
    /// ``spawn(captureOutput:in:teardown:)``. Custom executors read it to honor the same contract.
    public private(set) var spawnRetainsOutput = false

    /// The stderr handling strategy for this command.
    ///
    /// Defaults to ``OutputDestination/capture``, which retains stderr in ``ShellOutput/stderr``.
    /// Change with ``stderr(_:)`` to discard or write to a file.
    public private(set) var stderrDestination: OutputDestination = .capture

    /// Creates a command from an executable name and optional argv arguments.
    ///
    /// The executable name is resolved against ``ShellContext/searchPaths`` at execution time
    /// unless an override is later supplied via ``executable(_:)``. Each element of `arguments`
    /// is forwarded as a single argv entry, so callers do not need to perform shell quoting.
    ///
    /// The example below builds a command equivalent to `echo hello world` and runs it:
    ///
    /// ```swift
    /// let output = try await Command("echo", arguments: "hello", "world").run(in: context)
    /// ```
    ///
    /// - Parameters:
    ///   - executable: The executable name or absolute path to invoke.
    ///   - arguments: The argv arguments to pass to the executable. Each variadic element becomes
    ///     a separate argument; no shell parsing or quoting is performed.
    public init(_ executable: String, arguments: String...) {
        self.init(executable, arguments: arguments)
    }

    /// Creates a command from an executable name and an array of argv arguments.
    ///
    /// Use this overload when the arguments are computed at runtime:
    ///
    /// ```swift
    /// let files = ["Package.swift", "README.md"]
    /// let output = try await Command("wc", arguments: ["-l"] + files).run(in: context)
    /// ```
    ///
    /// - Parameters:
    ///   - executable: The executable name or absolute path to invoke.
    ///   - arguments: The argv arguments to pass to the executable, in order. Each element becomes
    ///     a separate argument; no shell parsing or quoting is performed.
    public init(_ executable: String, arguments: [String]) {
        self.executableName = executable
        self.arguments = arguments
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
    /// try await Command("git", arguments: "status")
    ///     .executable("/Applications/Xcode.app/Contents/Developer/usr/bin/git")
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter path: An absolute or relative path to the executable to invoke.
    /// - Returns: A new ``Command`` with the executable override applied.
    public func executable(_ path: String) -> Self {
        modified(self) { $0.options.executableOverride = path }
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
        modified(self) { $0.arguments.append(value) }
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
        modified(self) { $0.arguments += values }
    }

    /// Returns a copy of the command with one environment variable set or replaced.
    ///
    /// The override is merged onto ``ShellContext/environment`` at execution time. If the same
    /// `name` is supplied to this method multiple times, the last value wins. To remove a
    /// variable from the inherited environment, use ``unsetEnv(_:)-(String...)``; an empty value is not the
    /// same as an unset variable for most tools.
    ///
    /// ```swift
    /// try await Command("ruby", arguments: "deploy.rb")
    ///     .env("RAILS_ENV", "production")
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameters:
    ///   - name: The environment variable name.
    ///   - value: The value to assign for this command's execution.
    /// - Returns: A new ``Command`` with the environment override applied.
    public func env(_ name: String, _ value: String) -> Self {
        modified(self) { $0.options.setEnvironment([name: value]) }
    }

    /// Returns a copy of the command with multiple environment variable overrides merged in.
    ///
    /// Keys in `values` are merged on top of any overrides already configured on the command;
    /// when a key already exists in ``environmentOverrides``, the value from `values` wins.
    /// The merged set is then applied on top of ``ShellContext/environment`` at execution time.
    ///
    /// ```swift
    /// try await Command("swift", arguments: "test")
    ///     .env(["CI": "true", "NODE_ENV": "test"])
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter values: A dictionary of environment variable name/value pairs to merge.
    /// - Returns: A new ``Command`` with the merged environment overrides applied.
    public func env(_ values: [String: String]) -> Self {
        modified(self) { $0.options.setEnvironment(values) }
    }

    /// Returns a copy of the command with environment variables removed from its environment.
    ///
    /// The named variables are absent from the child's environment even when
    /// ``ShellContext/environment`` defines them, and any override for them set earlier with
    /// ``env(_:_:)`` is dropped. A later ``env(_:_:)`` for the same name sets it again.
    ///
    /// ```swift
    /// // Make sure the tool does not pick up the caller's credentials.
    /// try await Command("aws", arguments: "sts", "get-caller-identity")
    ///     .unsetEnv("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN")
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter names: The environment variable names to remove.
    /// - Returns: A new ``Command`` without those variables in its environment.
    public func unsetEnv(_ names: String...) -> Self {
        unsetEnv(names)
    }

    /// Returns a copy of the command with environment variables removed from its environment.
    ///
    /// - Parameter names: The environment variable names to remove.
    /// - Returns: A new ``Command`` without those variables in its environment.
    public func unsetEnv(_ names: [String]) -> Self {
        modified(self) { $0.options.unsetEnvironment(names) }
    }

    /// Returns a copy of the command that runs in the given working directory.
    ///
    /// The path replaces ``ShellContext/workingDirectory`` for this invocation only. Both
    /// absolute and relative paths are accepted; relative paths are resolved by the executor
    /// against the current process's working directory. Relative executable overrides and output
    /// file destinations are then resolved against this effective directory.
    ///
    /// ```swift
    /// try await Command("git", arguments: "pull")
    ///     .workingDirectory("/var/app")
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter path: The directory in which to spawn the command's process.
    /// - Returns: A new ``Command`` with the working-directory override applied.
    public func workingDirectory(_ path: String) -> Self {
        modified(self) { $0.options.workingDirectoryOverride = path }
    }

    /// Returns a copy of the command with a per-command timeout.
    ///
    /// When the running process exceeds `duration`, the executor terminates it and throws
    /// ``ShellError/timeout(command:duration:partialOutput:)`` containing whatever output was
    /// captured before termination. The value must not be negative — negative values raise
    /// ``ShellError/invalidConfiguration(description:)`` at execution time.
    ///
    /// This override replaces ``ShellContext/defaultTimeout`` for this invocation only.
    ///
    /// ```swift
    /// try await Command("swift", arguments: "build")
    ///     .timeout(.seconds(120))   // abort if the build runs longer than two minutes
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter duration: The maximum time to wait for the process. Must not be negative.
    /// - Returns: A new ``Command`` with the timeout override applied.
    public func timeout(_ duration: Duration) -> Self {
        modified(self) { $0.options.timeoutOverride = duration }
    }

    /// Returns a copy of the command with a per-command timeout in seconds.
    ///
    /// - Parameter seconds: The maximum duration to wait for the process, in seconds.
    /// - Returns: A new ``Command`` with the timeout override applied.
    @available(*, deprecated, message: "Pass a Duration, for example timeout(.seconds(120))")
    public func timeout(_ seconds: TimeInterval) -> Self {
        modified(self) { $0.options.timeoutOverride = Duration(timeoutSeconds: seconds) }
    }

    /// Returns a copy of the command with a per-command captured-output limit in bytes.
    ///
    /// The limit applies to the combined size of captured stdout and stderr. When exceeded,
    /// the executor terminates the process and throws
    /// ``ShellError/outputLimitExceeded(command:limit:partialOutput:)`` containing the captured
    /// portion. Pass `0` for unlimited (no cap), or a positive value for a byte limit.
    ///
    /// Streams routed through ``OutputDestination/file(path:append:)`` or
    /// ``OutputDestination/discard`` do not contribute to the captured size.
    ///
    /// ```swift
    /// try await Command("ls", arguments: "-R", "/")
    ///     .outputLimit(1_048_576)   // cap captured output at 1 MB
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter bytes: The maximum number of bytes to retain in memory. Must be `>= 0`.
    /// - Returns: A new ``Command`` with the output-limit override applied.
    public func outputLimit(_ bytes: Int) -> Self {
        modified(self) { $0.options.outputLimitOverride = bytes }
    }

    /// Returns a copy of the command that reads its stdin from the given source.
    ///
    /// The default is ``InputSource/none``, an empty stdin. In a ``Pipeline`` only the first
    /// stage may set a source; later stages read the previous stage's stdout, and a source set on
    /// one of them fails the run with ``ShellError/invalidConfiguration(description:)``.
    ///
    /// ```swift
    /// let name = try await Command("jq", arguments: "-r", ".name")
    ///     .stdin(.string(#"{"name": "SwiftyShell"}"#))
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter source: Where the command's stdin comes from.
    /// - Returns: A new ``Command`` with the input source applied.
    public func stdin(_ source: InputSource) -> Self {
        modified(self) { $0.stdinSource = source }
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
    /// try await Command("swift", arguments: "build", "--verbose")
    ///     .stdout(.file(path: "/tmp/build.log", append: false))
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter destination: Where the executor should send the stdout stream.
    /// - Returns: A new ``Command`` with the stdout destination applied.
    public func stdout(_ destination: OutputDestination) -> Self {
        modified(self) { $0.stdoutDestination = destination }
    }

    /// Returns a copy of the command that routes stderr to the given destination.
    ///
    /// Behaves like ``stdout(_:)`` but for the stderr stream. Defaults to
    /// ``OutputDestination/capture``.
    ///
    /// ```swift
    /// try await Command("make", arguments: "clean")
    ///     .stderr(.discard)   // suppress noisy progress messages
    ///     .run(in: context)
    /// ```
    ///
    /// - Parameter destination: Where the executor should send the stderr stream.
    /// - Returns: A new ``Command`` with the stderr destination applied.
    public func stderr(_ destination: OutputDestination) -> Self {
        modified(self) { $0.stderrDestination = destination }
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
    /// let pipeline = Command("ls", arguments: "-la")
    ///     .pipe(to: Command("grep", arguments: ".swift"))
    ///     .pipe(to: Command("wc", arguments: "-l"))
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
    /// let output = try await Command("git", arguments: "rev-parse", "HEAD").run(in: context)
    /// let sha = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    /// ```
    ///
    /// - Parameter context: The shell context that provides defaults and the executor. Defaults
    ///   to a freshly constructed ``ShellContext``.
    /// - Returns: The captured ``ShellOutput`` from the process.
    /// - Throws: ``ShellError`` describing the failure mode (timeout, non-zero exit,
    ///   output-limit overflow, cancellation, spawn error, or invalid configuration). Output that
    ///   is not valid UTF-8 is not an error; read the raw bytes from ``ShellOutput/stdoutData``.
    public func run(in context: ShellContext = .init()) async throws -> ShellOutput {
        try await context.executor.execute(self, in: context)
    }

    /// Spawns the command without waiting for it to exit.
    ///
    /// Use `spawn` for long-running processes that need to be controlled later, such as servers,
    /// file watchers, or recorders. The returned ``SpawnedProcess`` provides real-time output
    /// streams and methods for signaling or gracefully tearing down the process.
    ///
    /// Output is streamed live but not retained, so ``SpawnedProcess/waitForExit()`` and
    /// ``SpawnedProcess/teardownAndWait()`` report the exit code with empty output. Use
    /// ``spawn(captureOutput:in:teardown:)`` when the final output is needed.
    ///
    /// ```swift
    /// let server = try await Command("python3", arguments: "-m", "http.server", "8080")
    ///     .spawn(in: context)
    ///
    /// // ... use the server ...
    /// let output = await server.teardownAndWait()
    /// ```
    ///
    /// - Parameters:
    ///   - context: The shell context that provides defaults and the executor. Defaults to a
    ///     freshly constructed ``ShellContext``.
    ///   - teardown: The strategy used by ``SpawnedProcess/teardownAndWait()``. Defaults to
    ///     ``TeardownStrategy/graceful``.
    /// - Returns: A handle to the running process.
    /// - Throws: ``ShellError`` describing invalid configuration or spawn failure.
    public func spawn(
        in context: ShellContext = .init(),
        teardown: TeardownStrategy = .graceful
    ) async throws -> any SpawnedProcess {
        try await spawn(captureOutput: false, in: context, teardown: teardown)
    }

    /// Spawns the command without waiting for it to exit, optionally retaining its output.
    ///
    /// With `captureOutput: true`, captured streams are also kept (up to the output limit) and
    /// returned by ``SpawnedProcess/waitForExit()`` and ``SpawnedProcess/teardownAndWait()``.
    /// Exceeding the output limit tears the process down, so prefer the default for long-running
    /// processes and read the live streams instead.
    ///
    /// ```swift
    /// let build = try await Command("swift", arguments: "build").spawn(captureOutput: true)
    /// for await chunk in build.standardOutput { print(chunk, terminator: "") }
    /// let output = await build.waitForExit()   // output.stdout holds the full log
    /// ```
    ///
    /// - Parameters:
    ///   - captureOutput: Whether to retain captured output for the final ``ShellOutput``.
    ///   - context: The shell context that provides defaults and the executor.
    ///   - teardown: The strategy used by ``SpawnedProcess/teardownAndWait()``.
    /// - Returns: A handle to the running process.
    /// - Throws: ``ShellError`` describing invalid configuration or spawn failure.
    public func spawn(
        captureOutput: Bool,
        in context: ShellContext = .init(),
        teardown: TeardownStrategy = .graceful
    ) async throws -> any SpawnedProcess {
        let command = modified(self) { $0.spawnRetainsOutput = captureOutput }
        return try await context.executor.spawn(command, in: context, teardown: teardown)
    }

    /// Returns a shell-quoted string representation of the command suitable for display or logging.
    ///
    /// Components that are empty or contain anything other than letters, digits, and
    /// `@%+=:,./_-` are wrapped in POSIX single quotes, with embedded single quotes written as
    /// `'\''`. The result can be pasted into a POSIX shell (`sh`, `bash`, `zsh`) to run the same
    /// argv: variables, globs, and command separators inside arguments are not expanded.
    ///
    /// ```swift
    /// Command("git", arguments: "commit", "-m", "it's $HOME").displayString()
    /// // git commit -m 'it'\''s $HOME'
    /// ```
    ///
    /// - Parameter resolvedExecutable: When supplied, this overrides the executable portion
    ///   of the display string. Pass the resolved absolute path returned by the executor to
    ///   show exactly which binary ran.
    /// - Returns: A string of the form `executable [arg ...]` with arguments quoted when necessary.
    public func displayString(using resolvedExecutable: String? = nil) -> String {
        ([resolvedExecutable ?? executableOverride ?? executableName] + arguments)
            .map(Self.shellQuoted)
            .joined(separator: " ")
    }

    /// Returns `component` unchanged when it is safe to paste into a POSIX shell, otherwise wrapped
    /// in single quotes.
    internal static func shellQuoted(_ component: String) -> String {
        if !component.isEmpty, component.unicodeScalars.allSatisfy(isShellSafe) {
            return component
        }
        return "'" + component.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    private static func isShellSafe(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar {
        case "a"..."z", "A"..."Z", "0"..."9", "@", "%", "+", "=", ":", ",", ".", "/", "_", "-":
            true
        default:
            false
        }
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
        if !unsetEnvironmentVariables.isEmpty { parts.append("unsetEnv: \(unsetEnvironmentVariables.sorted())") }
        if let wd = workingDirectoryOverride { parts.append("workingDirectory: \(wd.debugDescription)") }
        if let timeout = timeoutOverride { parts.append("timeout: \(timeout)") }
        if let limit = outputLimitOverride { parts.append("outputLimit: \(limit)") }
        if stdinSource != .none { parts.append("stdin: \(stdinSource.debugSummary)") }
        if stdoutDestination != .capture { parts.append("stdout: \(stdoutDestination)") }
        if stderrDestination != .capture { parts.append("stderr: \(stderrDestination)") }
        return parts.joined(separator: ", ") + ")"
    }
}
