import Foundation

/// A handle to a pipeline spawned without waiting for completion.
///
/// Use ``Pipeline/spawn(captureOutput:in:teardown:)`` for long-running pipelines such as
/// `tail -f log | grep ERROR`. The handle behaves like one ``SpawnedProcess`` for the whole
/// pipeline:
///
/// - ``SpawnedProcess/standardOutput`` and its siblings carry the final stage's stdout.
/// - ``SpawnedProcess/standardError`` carries the stderr of every stage, interleaved as it arrives.
/// - ``SpawnedProcess/send(_:)`` signals every stage, and ``SpawnedProcess/teardownAndWait()`` tears
///   every stage down with the configured ``TeardownStrategy``.
/// - ``SpawnedProcess/processIdentifier`` is the final stage's PID, like `$!` in a shell.
///
/// ```swift
/// let pipeline = try await Command("tail", arguments: "-f", "app.log")
///     .pipe(to: Command("grep", arguments: "--line-buffered", "ERROR"))
///     .spawn()
/// for await line in pipeline.standardOutputLines {
///     print(line)
/// }
/// let codes = await pipeline.waitForStageExitCodes()
/// ```
public protocol SpawnedPipeline: SpawnedProcess {
    /// The process identifier of each stage, in pipeline order.
    var stageProcessIdentifiers: [Int32] { get }

    /// Waits for every stage to exit and returns each stage's exit code in pipeline order.
    ///
    /// A stage terminated by a signal reports `128 + signal`. Unlike ``Pipeline/run(in:)``, no exit
    /// code is treated as a failure.
    func waitForStageExitCodes() async -> [Int32]
}

extension Pipeline {
    /// Starts every stage of the pipeline and returns a handle without waiting for exit.
    ///
    /// All stages run concurrently and are connected stdout-to-stdin as in ``run(in:)``. By default
    /// output is only streamed, not retained; pass `captureOutput: true` to keep the final stage's
    /// stdout and every stage's stderr for ``SpawnedProcess/waitForExit()`` and
    /// ``SpawnedProcess/teardownAndWait()``, up to the usual output limits. Timeouts are not
    /// enforced for spawned processes, and no exit code raises an error: read them with
    /// ``SpawnedPipeline/waitForStageExitCodes()``.
    ///
    /// - Parameters:
    ///   - captureOutput: Whether the final output is retained for the wait methods.
    ///   - context: The shell context that supplies defaults to every stage.
    ///   - teardown: The strategy applied to every stage by ``SpawnedProcess/teardownAndWait()``.
    /// - Returns: A handle to the running pipeline.
    /// - Throws: ``ShellError`` when a stage cannot be started. Custom executors that do not implement
    ///   ``CommandExecutor/spawn(_:in:teardown:)-(Pipeline,_,_)`` throw
    ///   ``ShellError/invalidConfiguration(description:)``.
    public func spawn(
        captureOutput: Bool = false,
        in context: ShellContext = .init(),
        teardown: TeardownStrategy = .graceful
    ) async throws -> any SpawnedPipeline {
        try validateInputSources()
        let retaining = Pipeline(stages: stages.map { $0.retainingSpawnOutput(captureOutput) })
        return try await context.executor.spawn(retaining, in: context, teardown: teardown)
    }
}

/// A spawned pipeline that never launches a process, for tests.
///
/// Returned by ``MockExecutor`` when a pipeline is spawned. Like ``MockSpawnedProcess`` it records
/// signals and teardown; it also reports the exit code each stage's mock response carried.
public struct MockSpawnedPipeline: SpawnedPipeline {
    private let process: MockSpawnedProcess
    private let stageOutputs: [ShellOutput]

    /// Creates a mock spawned pipeline from per-stage responses.
    ///
    /// - Parameters:
    ///   - stageOutputs: One response per stage, in pipeline order.
    ///   - teardown: The ``TeardownStrategy`` passed to ``Pipeline/spawn(captureOutput:in:teardown:)``.
    ///   - captureOutput: Whether the wait methods return the output or only the exit code.
    init(stageOutputs: [ShellOutput], teardown: TeardownStrategy, captureOutput: Bool) {
        self.stageOutputs = stageOutputs
        let combined = ShellOutput(
            stdoutData: stageOutputs.last?.stdoutData ?? Data(),
            stderrData: stageOutputs.reduce(into: Data()) { $0.append($1.stderrData) },
            exitCode: stageOutputs.last?.exitCode ?? 0
        )
        self.process = MockSpawnedProcess(
            teardown: teardown,
            output: combined,
            retainedOutput: captureOutput ? combined : ShellOutput(exitCode: combined.exitCode)
        )
    }

    /// The final stage's mock PID; stage `n` (counting from `1`) reports PID `n`.
    public var processIdentifier: Int32 { Int32(stageOutputs.count) }

    /// The mock PID of each stage, numbered from `1`.
    public var stageProcessIdentifiers: [Int32] { stageOutputs.indices.map { Int32($0 + 1) } }

    /// The final stage's stdout as text.
    public var standardOutput: AsyncStream<String> { process.standardOutput }

    /// The concatenated stderr of every stage as text.
    public var standardError: AsyncStream<String> { process.standardError }

    /// The final stage's stdout as bytes.
    public var standardOutputData: AsyncStream<Data> { process.standardOutputData }

    /// The concatenated stderr of every stage as bytes.
    public var standardErrorData: AsyncStream<Data> { process.standardErrorData }

    /// The strategy that was configured when the pipeline was spawned.
    public var configuredTeardown: TeardownStrategy { process.configuredTeardown }

    /// Signals sent to this pipeline, in order.
    public var signalHistory: [ProcessSignal] {
        get async { await process.signalHistory }
    }

    /// Whether ``teardownAndWait()`` has been called.
    public var didTeardown: Bool {
        get async { await process.didTeardown }
    }

    /// Records a signal, as if it had been sent to every stage.
    public func send(_ signal: ProcessSignal) async throws {
        try await process.send(signal)
    }

    /// Records teardown and returns the combined preset output.
    public func teardownAndWait() async -> ShellOutput {
        await process.teardownAndWait()
    }

    /// Returns the combined preset output.
    public func waitForExit() async -> ShellOutput {
        await process.waitForExit()
    }

    /// Returns the exit code each stage's mock response carried.
    public func waitForStageExitCodes() async -> [Int32] {
        stageOutputs.map(\.exitCode)
    }
}
