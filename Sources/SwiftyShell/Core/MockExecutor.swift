import Foundation
import Synchronization

/// A test-double implementation of ``CommandExecutor`` that returns caller-controlled
/// responses without spawning real processes.
///
/// Use ``MockExecutor`` in unit tests to verify that your code calls the right
/// commands without relying on the filesystem or external tools.
///
/// The fixed-output initializer makes every command return the same successful ``ShellOutput``.
/// Every mock records the commands it receives in ``recordedCommands``:
///
/// ```swift
/// let mock = MockExecutor(stdout: "hello\n")
/// let output = try await Command("echo", arguments: "hello").run(in: ShellContext(executor: mock))
/// #expect(output.stdout == "hello\n")
/// #expect(mock.recordedCommands.map(\.arguments) == [["hello"]])
/// ```
///
/// Use stubs to answer different commands differently. A command that matches no stub throws
/// ``ShellError/commandNotFound(_:)`` unless a fallback output is supplied:
///
/// ```swift
/// let mock = MockExecutor(stubs: [
///     .init("git", arguments: ["rev-parse", "HEAD"], returning: ShellOutput(stdout: "abc123\n", exitCode: 0)),
///     .init("git", returning: ShellOutput(stderr: "unexpected", exitCode: 1)),
/// ])
/// ```
///
/// Use the handler initializer when responses need arbitrary logic.
///
/// ```swift
/// let mock = MockExecutor { command, _ in
///     ShellOutput(stdout: command.arguments.joined(separator: " "), exitCode: 0)
/// }
/// ```
public struct MockExecutor: CommandExecutor {
    /// The handler type invoked for each ``Command`` execution.
    public typealias Handler = @Sendable (Command, ShellContext) async throws -> ShellOutput

    /// A canned response for commands that match a predicate.
    ///
    /// Stubs are checked in order and the first match wins, so list specific stubs before
    /// general ones.
    public struct Stub: Sendable {
        let matches: @Sendable (Command) -> Bool
        let output: ShellOutput

        /// Creates a stub that matches an executable name and, optionally, exact arguments.
        ///
        /// - Parameters:
        ///   - executable: The ``Command/executableName`` to match.
        ///   - arguments: The exact ``Command/arguments`` to match, or `nil` to match any.
        ///   - output: The output to return. A non-zero exit code throws
        ///     ``ShellError/exitFailure(command:output:)`` as in production.
        public init(_ executable: String, arguments: [String]? = nil, returning output: ShellOutput) {
            self.matches = { command in
                command.executableName == executable && (arguments.map { $0 == command.arguments } ?? true)
            }
            self.output = output
        }

        /// Creates a stub that matches commands accepted by `predicate`.
        ///
        /// - Parameters:
        ///   - predicate: Returns `true` for commands this stub answers.
        ///   - output: The output to return.
        public init(matching predicate: @escaping @Sendable (Command) -> Bool, returning output: ShellOutput) {
            self.matches = predicate
            self.output = output
        }
    }

    private let handler: Handler
    private let log = CommandLog()

    /// The commands this mock has received, in the order they ran.
    ///
    /// Pipelines record each stage in pipeline order, and ``spawn(_:in:teardown:)`` records the
    /// spawned command. Commands rejected by configuration validation are not recorded, because
    /// the production executor would not have run them. Copies of a mock share one log.
    public var recordedCommands: [Command] {
        log.commands
    }

    /// Creates a mock executor that invokes `handler` for every command.
    ///
    /// - Parameter handler: Closure receiving the command and context; returns
    ///   the ``ShellOutput`` to report back to the caller or throws a ``ShellError``.
    public init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Creates a mock executor that answers commands from a list of stubs.
    ///
    /// ```swift
    /// let mock = MockExecutor(
    ///     stubs: [.init("git", arguments: ["branch", "--show-current"], returning: ShellOutput(stdout: "main\n", exitCode: 0))],
    ///     fallback: ShellOutput(exitCode: 0)
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - stubs: Stubs checked in order; the first match supplies the output.
    ///   - fallback: The output for commands that match no stub. When `nil` (the default), an
    ///     unmatched command throws ``ShellError/commandNotFound(_:)`` with its executable name, so
    ///     unexpected commands fail the test loudly.
    public init(stubs: [Stub], fallback: ShellOutput? = nil) {
        self.init { command, _ in
            if let stub = stubs.first(where: { $0.matches(command) }) {
                return stub.output
            }
            guard let fallback else {
                throw ShellError.commandNotFound(command.executableName)
            }
            return fallback
        }
    }

    /// Creates a mock executor that always returns a fixed successful response.
    ///
    /// - Parameters:
    ///   - stdout: The stdout string to return. Defaults to `""`.
    ///   - stderr: The stderr string to return. Defaults to `""`.
    ///   - exitCode: The exit code to return. Defaults to `0`.
    public init(stdout: String = "", stderr: String = "", exitCode: Int32 = 0) {
        self.init { _, _ in
            ShellOutput(stdout: stdout, stderr: stderr, exitCode: exitCode)
        }
    }

    /// Executes a single command by invoking the mock handler.
    ///
    /// The mock validates the command's effective timeout and output-limit configuration before
    /// invoking the handler, so misconfigured tests fail with the same
    /// ``ShellError/invalidConfiguration(description:)`` they would in production. After the
    /// handler returns, a non-zero exit code is translated into
    /// ``ShellError/exitFailure(command:output:)`` to match real-executor semantics.
    ///
    /// - Parameters:
    ///   - command: The command being executed.
    ///   - context: The shell context that supplies defaults.
    /// - Returns: The captured ``ShellOutput`` returned by the handler.
    /// - Throws: Whatever the handler throws, plus
    ///   ``ShellError/invalidConfiguration(description:)`` for invalid timeout/output-limit
    ///   values and ``ShellError/exitFailure(command:output:)`` when the handler returns a
    ///   non-zero exit code.
    public func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
        try validateConfiguration(for: command, in: context)
        log.append(command)
        return try validate(output: try await handler(command, context), for: command)
    }

    /// Executes a pipeline by running each stage's command through the handler.
    ///
    /// Mirrors the built-in executor's pipeline semantics: every stage's configuration is
    /// validated before any stage runs, and every stage is invoked (production starts all stages
    /// concurrently). The result carries the final stage's stdout and the stderr of every stage
    /// concatenated in stage order. When a stage returns a non-zero exit code, the first such
    /// stage in pipeline order is reported through ``ShellError/exitFailure(command:output:)``
    /// with that stage's exit code and the combined output. As in production, a non-final stage
    /// that reports `128 + SIGPIPE` (a downstream stage stopped reading) is not a failure. The
    /// mock does not feed one stage's stdout into the next stage.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline to run.
    ///   - context: The shell context that supplies defaults to every stage.
    /// - Returns: The final stage's stdout with the combined stderr of all stages.
    /// - Throws: Whatever the handler throws for any stage, plus the same configuration and
    ///   exit-code errors as ``execute(_:in:)-(Command,_)``.
    public func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput {
        for stage in pipeline.stages {
            try validateConfiguration(for: stage, in: context)
        }

        var outputs: [ShellOutput] = []
        for stage in pipeline.stages {
            log.append(stage)
            outputs.append(try await handler(stage, context))
        }

        let stdout = outputs.last?.stdout ?? ""
        let stderr = outputs.map(\.stderr).joined()
        let finalIndex = outputs.count - 1
        let failure = zip(pipeline.stages, outputs).enumerated().first { index, stageAndOutput in
            let exitCode = stageAndOutput.1.exitCode
            let isBenignBrokenPipe = index < finalIndex && exitCode == 128 + SIGPIPE
            return exitCode != 0 && !isBenignBrokenPipe
        }.map(\.element)
        if let failure {
            throw ShellError.exitFailure(
                command: failure.0.displayString(),
                output: ShellOutput(stdout: stdout, stderr: stderr, exitCode: failure.1.exitCode)
            )
        }
        return ShellOutput(stdout: stdout, stderr: stderr, exitCode: 0)
    }

    /// Spawns a mock process by invoking the mock handler and returning a ``MockSpawnedProcess``.
    ///
    /// The returned ``MockSpawnedProcess`` stores the configured ``TeardownStrategy`` so tests
    /// can verify the strategy via ``MockSpawnedProcess/configuredTeardown``.
    ///
    /// - Parameters:
    ///   - command: The command to spawn.
    ///   - context: The shell context that supplies defaults.
    ///   - teardown: The strategy stored on the returned ``MockSpawnedProcess``.
    /// - Returns: A ``MockSpawnedProcess`` wrapping the handler's output.
    /// - Throws: ``ShellError/invalidConfiguration(description:)`` for invalid timeout or
    ///   output-limit values, or whatever the handler throws.
    public func spawn(
        _ command: Command,
        in context: ShellContext,
        teardown: TeardownStrategy
    ) async throws -> any SpawnedProcess {
        try validateConfiguration(for: command, in: context)
        log.append(command)
        return MockSpawnedProcess(teardown: teardown, output: try await handler(command, context))
    }

    private func validateConfiguration(for command: Command, in context: ShellContext) throws {
        if let timeout = command.timeoutOverride ?? context.defaultTimeout, timeout < .zero {
            throw ShellError.invalidConfiguration(description: "Timeout must be greater than or equal to zero seconds")
        }

        let outputLimit = command.outputLimitOverride ?? context.defaultOutputLimit
        if outputLimit < 0 {
            throw ShellError.invalidConfiguration(
                description: "Output limit must be zero (unlimited) or a positive byte count"
            )
        }
    }

    private func validate(output: ShellOutput, for command: Command) throws -> ShellOutput {
        guard output.exitCode == 0 else {
            throw ShellError.exitFailure(command: command.displayString(), output: output)
        }
        return output
    }
}

/// Thread-safe, append-only storage for the commands a ``MockExecutor`` receives.
private final class CommandLog: Sendable {
    private let storage = Mutex<[Command]>([])

    var commands: [Command] {
        storage.withLock { $0 }
    }

    func append(_ command: Command) {
        storage.withLock { $0.append(command) }
    }
}
