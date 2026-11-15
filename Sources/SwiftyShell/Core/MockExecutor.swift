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
        ///     ``ShellError/exitFailure(command:output:)-enum.case`` as in production.
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
    /// Pipelines record each stage in pipeline order, and spawned commands are recorded as well.
    /// Commands rejected by configuration validation are not recorded, because the production
    /// executor would not have run them. Copies of a mock share one log.
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
    /// ``ShellError/exitFailure(command:output:)-enum.case`` to match real-executor semantics.
    ///
    /// - Parameters:
    ///   - command: The command being executed.
    ///   - context: The shell context that supplies defaults.
    /// - Returns: The captured ``ShellOutput`` returned by the handler.
    /// - Throws: Whatever the handler throws, plus
    ///   ``ShellError/invalidConfiguration(description:)`` for invalid timeout/output-limit
    ///   values and ``ShellError/exitFailure(command:output:)-enum.case`` when the handler returns a
    ///   non-zero exit code.
    public func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
        try validateConfiguration(for: command, in: context)
        log.append(command)
        return try validate(
            output: retainingLogTails(merging(try await handler(command, context), for: command), for: command),
            for: command
        )
    }

    /// Executes a pipeline by running each stage's command through the handler.
    ///
    /// Mirrors the built-in executor's pipeline semantics: every stage's configuration is
    /// validated before any stage runs, and every stage is invoked (production starts all stages
    /// concurrently). The result carries the final stage's stdout and the stderr of every stage
    /// concatenated in stage order. When a stage returns a non-zero exit code, the first such
    /// stage in pipeline order is reported through ``ShellError/exitFailure(command:output:)-enum.case``
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
        let outputs = try await runStages(of: pipeline, in: context)
        let stdoutData = outputs.last?.stdoutData ?? Data()
        let stderrData = outputs.reduce(into: Data()) { $0.append($1.stderrData) }
        let finalIndex = outputs.count - 1
        let failure = zip(pipeline.stages, outputs).enumerated().first { index, stageAndOutput in
            let exitCode = stageAndOutput.1.exitCode
            let isBenignBrokenPipe = index < finalIndex && exitCode == 128 + SIGPIPE
            let isAccepted = exitCode == 0 || stageAndOutput.0.acceptedExitCodes.contains(exitCode)
            return !isAccepted && !isBenignBrokenPipe
        }.map(\.element)
        if let failure {
            throw ShellError.exitFailure(
                command: CommandSnapshot(failure.0),
                output: ShellOutput(stdoutData: stdoutData, stderrData: stderrData, exitCode: failure.1.exitCode)
            )
        }
        return ShellOutput(stdoutData: stdoutData, stderrData: stderrData, exitCode: outputs.last?.exitCode ?? 0)
    }

    /// Runs a pipeline through the handler and reports every stage's exit code.
    ///
    /// Like ``execute(_:in:)-(Pipeline,_)`` but no stage's exit code raises
    /// ``ShellError/exitFailure(command:output:)-enum.case``; the codes the handler returned are
    /// reported in ``PipelineResult/stageExitCodes``.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline to run.
    ///   - context: The shell context that supplies defaults to every stage.
    /// - Returns: The final stage's stdout with the combined stderr, and each stage's exit code.
    /// - Throws: Whatever the handler throws, plus the configuration errors of
    ///   ``execute(_:in:)-(Command,_)``.
    public func executeReportingStages(_ pipeline: Pipeline, in context: ShellContext) async throws -> PipelineResult {
        let outputs = try await runStages(of: pipeline, in: context)
        return PipelineResult(
            output: ShellOutput(
                stdoutData: outputs.last?.stdoutData ?? Data(),
                stderrData: outputs.reduce(into: Data()) { $0.append($1.stderrData) },
                exitCode: outputs.last?.exitCode ?? 0
            ),
            stageExitCodes: outputs.map(\.exitCode)
        )
    }

    private func runStages(of pipeline: Pipeline, in context: ShellContext) async throws -> [ShellOutput] {
        try pipeline.validateInputSources()
        for stage in pipeline.stages {
            try validateConfiguration(for: stage, in: context)
        }

        var outputs: [ShellOutput] = []
        for (index, stage) in pipeline.stages.enumerated() {
            log.append(stage)
            outputs.append(
                retainingLogTails(
                    merging(try await handler(stage, context), for: stage),
                    for: stage,
                    includeStdout: index == pipeline.stages.count - 1
                )
            )
        }
        return outputs
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
        let output = merging(try await handler(command, context), for: command)
        return MockSpawnedProcess(
            teardown: teardown,
            output: output,
            retainedOutput: command.spawnRetainsOutput
                ? retainingLogTails(output, for: command) : ShellOutput(exitCode: output.exitCode)
        )
    }

    /// Spawns a mock pipeline by invoking the handler for every stage.
    ///
    /// Every stage's configuration is validated and recorded in ``recordedCommands``, and the
    /// handler's responses become the stage exit codes reported by
    /// ``MockSpawnedPipeline/waitForStageExitCodes()``. Stage stdout is not fed to the next stage.
    ///
    /// - Parameters:
    ///   - pipeline: The pipeline to spawn.
    ///   - context: The shell context that supplies defaults.
    ///   - teardown: The strategy stored on the returned ``MockSpawnedPipeline``.
    /// - Returns: A ``MockSpawnedPipeline`` wrapping the handler's outputs.
    public func spawn(
        _ pipeline: Pipeline,
        in context: ShellContext,
        teardown: TeardownStrategy
    ) async throws -> any SpawnedPipeline {
        let outputs = try await runStages(of: pipeline, in: context)
        return MockSpawnedPipeline(
            stageOutputs: outputs,
            teardown: teardown,
            captureOutput: pipeline.stages.last?.spawnRetainsOutput ?? false
        )
    }

    /// Records a detached launch without starting a process or writing files.
    ///
    /// Applies detached configuration validation, invokes the handler, and returns the synthetic
    /// PID `1`. The stub's exit code describes eventual exit and does not make startup fail.
    public func spawnDetached(_ command: Command, in context: ShellContext) async throws -> Int32 {
        let command = try command.detachedCommand(in: context)
        try validateConfiguration(for: command, in: context)
        log.append(command)
        _ = try await handler(command, context)
        return 1
    }

    private func merging(_ output: ShellOutput, for command: Command) -> ShellOutput {
        guard command.mergesStderrIntoStdout else { return output }
        return ShellOutput(
            stdoutData: output.stdoutData + output.stderrData,
            stderrData: Data(),
            exitCode: output.exitCode
        )
    }

    private func retainingLogTails(
        _ output: ShellOutput,
        for command: Command,
        includeStdout: Bool = true
    ) -> ShellOutput {
        var result = output
        if includeStdout, case let .log(_, _, count, _) = command.stdoutDestination {
            result.stdoutData = Data(output.stdoutData.suffix(count))
        }
        if case let .log(_, _, count, _) = command.stderrDestination {
            result.stderrData = Data(output.stderrData.suffix(count))
        }
        return result
    }

    private func validateConfiguration(for command: Command, in context: ShellContext) throws {
        try command.stdoutDestination.validate()
        try command.stderrDestination.validate()
        try command.validateStderrMerge()
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
        guard output.exitCode == 0 || command.acceptedExitCodes.contains(output.exitCode) else {
            throw ShellError.exitFailure(command: CommandSnapshot(command), output: output)
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
