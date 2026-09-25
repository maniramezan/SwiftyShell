import Foundation
import Subprocess
import Synchronization

#if canImport(System)
import System
#else
import SystemPackage
#endif

/// The `Execution` specialization for a command whose stdout and stderr SwiftyShell streams
/// itself. SwiftyShell never writes to a child's stdin, so it leaves stdin to swift-subprocess
/// (`.none`, an empty `/dev/null`) instead of opening a writer only to close it. The spawned-process
/// state stores executions, and `Subprocess.Execution` is generic over its IO methods, so it needs
/// this concrete type.
/// The parts of a running swift-subprocess `Execution` a spawned-process handle needs, erased from
/// the execution's input and output types so any ``InputSource`` can be used.
private struct SpawnedExecution: Sendable {
    let processIdentifier: Int32
    private let sendSignal: @Sendable (Signal, Bool) throws -> Void
    private let runTeardown: @Sendable ([TeardownStep]) async -> Void

    init<Input, Output, Error>(_ execution: Execution<Input, Output, Error>) {
        self.processIdentifier = Int32(execution.processIdentifier.value)
        self.sendSignal = { signal, toProcessGroup in
            try execution.send(signal: signal, toProcessGroup: toProcessGroup)
        }
        self.runTeardown = { steps in
            await execution.teardown(using: steps)
        }
    }

    func send(_ signal: Signal, toProcessGroup: Bool = false) throws {
        try sendSignal(signal, toProcessGroup)
    }

    func teardown(using steps: [TeardownStep]) async {
        await runTeardown(steps)
    }
}

/// The default ``CommandExecutor`` that runs commands using Swift's `Subprocess` package.
///
/// `SubprocessExecutor` is what ``ShellContext/init(executor:searchPaths:environment:workingDirectory:defaultTimeout:defaultOutputLimit:)-(_,_,_,_,Duration?,_)``
/// installs by default. It spawns a real OS subprocess for each ``Command`` or ``Pipeline``
/// stage, wires stdin/stdout/stderr per the configured ``OutputDestination``, enforces
/// per-command timeouts and output limits, and converts non-zero exits into ``ShellError``.
///
/// You normally do not construct this type directly — `ShellContext()` already uses it.
/// Construct one explicitly only when you need to inject it into a context that requires
/// a non-default executor argument:
///
/// ```swift
/// let context = ShellContext(executor: SubprocessExecutor())
/// let output = try await Command("echo", arguments: "hi").run(in: context)
/// ```
///
/// To replace real process execution in tests, pass ``MockExecutor`` to the same
/// `executor:` parameter instead.
///
/// > Note: `SubprocessExecutor` lives under the `Internal/` folder for organizational
/// > reasons, but it is intentionally `public` because it is the default value used by
/// > `ShellContext.init`.
public struct SubprocessExecutor: CommandExecutor {
    /// Creates a subprocess-backed command executor.
    ///
    /// The executor is stateless; every ``execute(_:in:)-(Command,_)`` and
    /// ``execute(_:in:)-(Pipeline,_)`` call spawns fresh subprocesses configured from the
    /// supplied ``Command`` values and ``ShellContext``.
    public init() {}

    /// Executes a single ``Command`` in the given ``ShellContext`` and returns its captured output.
    ///
    /// Resolves the executable against `context.searchPaths`, merges environment
    /// overrides on top of `context.environment`, applies the working directory, timeout,
    /// and output limit (with command-level overrides winning), and runs the subprocess while
    /// streaming stdout and stderr per the configured ``OutputDestination``.
    ///
    /// - Parameters:
    ///   - command: The fully-configured ``Command`` to spawn.
    ///   - context: The ``ShellContext`` providing defaults for environment, search paths, and limits.
    /// - Returns: The captured ``ShellOutput`` on a successful zero-exit run.
    /// - Throws: ``ShellError`` for invalid configuration, spawn failures, non-zero exits,
    ///   timeouts, output-limit overflows, decoding failures, and cancellation.
    public func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
        let resolved = try ResolvedCommand(command: command, context: context)
        return try await SingleCommandRunner(resolved: resolved).run()
    }

    /// Executes a ``Pipeline`` in the given ``ShellContext`` and returns the final stage's output.
    ///
    /// Spawns one subprocess per pipeline stage, wires consecutive stages together with OS pipes,
    /// captures the final stage's stdout into ``ShellOutput/stdout``, and concatenates every
    /// stage's stderr into ``ShellOutput/stderr``. The shortest non-`nil` stage timeout governs
    /// the whole pipeline.
    ///
    /// - Parameters:
    ///   - pipeline: The ``Pipeline`` of commands to spawn, in order.
    ///   - context: The ``ShellContext`` providing defaults for each stage.
    /// - Returns: A ``ShellOutput`` whose `stdout` is the final stage's captured output and
    ///   whose `stderr` is the concatenated stderr of all stages.
    /// - Throws: ``ShellError`` describing the first failing stage, a timeout, an output
    ///   limit overflow, a spawn error, or task cancellation.
    public func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput {
        try pipeline.validateInputSources()
        let resolved = try pipeline.stages.map { try ResolvedCommand(command: $0, context: context) }
        return try await PipelineRunner(resolved: resolved).run()
    }

    /// Spawns a single ``Command`` and returns a handle without waiting for exit.
    public func spawn(
        _ command: Command,
        in context: ShellContext,
        teardown: TeardownStrategy
    ) async throws -> any SpawnedProcess {
        let resolved = try ResolvedCommand(command: command, context: context)
        return try await SpawnedCommandRunner(resolved: resolved, teardown: teardown).spawn()
    }
}

private struct ResolvedCommand: Sendable {
    let original: Command
    let executablePath: String
    let arguments: [String]
    let environment: [String: String]
    let workingDirectory: String?
    let timeout: Duration?
    let outputLimit: Int
    let stdinSource: InputSource
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let displayCommand: String

    init(command: Command, context: ShellContext) throws {
        let workingDirectory = command.workingDirectoryOverride ?? context.workingDirectory
        let resolvedWorkingDirectory = workingDirectory.map { Self.absolutePath($0) }
        self.original = command
        self.executablePath = try Self.resolveExecutable(
            command.executableOverride ?? command.executableName,
            searchPaths: context.searchPaths,
            workingDirectory: resolvedWorkingDirectory
        )
        self.arguments = command.arguments
        self.environment = context.environment.merging(command.environmentOverrides) { _, new in new }
        self.workingDirectory = resolvedWorkingDirectory
        self.timeout = command.timeoutOverride ?? context.defaultTimeout
        let rawLimit = command.outputLimitOverride ?? context.defaultOutputLimit
        guard rawLimit >= 0 else {
            throw ShellError.invalidConfiguration(
                description: "Output limit must be zero (unlimited) or a positive byte count"
            )
        }
        // 0 means unlimited; normalize to Int.max so downstream comparisons work unchanged.
        self.outputLimit = rawLimit == 0 ? Int.max : rawLimit
        if let timeout, timeout < .zero {
            throw ShellError.invalidConfiguration(description: "Timeout must be greater than or equal to zero seconds")
        }
        if case let .file(path) = command.stdinSource {
            self.stdinSource = .file(path: Self.absolutePath(path, relativeTo: resolvedWorkingDirectory))
        } else {
            self.stdinSource = command.stdinSource
        }
        self.stdoutDestination = Self.resolveOutputDestination(
            command.stdoutDestination,
            workingDirectory: resolvedWorkingDirectory
        )
        self.stderrDestination = Self.resolveOutputDestination(
            command.stderrDestination,
            workingDirectory: resolvedWorkingDirectory
        )
        try Self.validateOutputDestinations(stdout: stdoutDestination, stderr: stderrDestination)
        self.displayCommand = command.displayString(using: executablePath)
    }

    /// The configuration for `run()` and pipeline stages, which stop by killing the process group.
    var configuration: Configuration {
        configuration(teardownSequence: forcedTeardownSequence)
    }

    func configuration(teardownSequence: [TeardownStep]) -> Configuration {
        Configuration(
            executable: .path(FilePath(executablePath)),
            arguments: Arguments(arguments),
            environment: .custom(Dictionary(uniqueKeysWithValues: environment.map { ($0.key.key, $0.value) })),
            workingDirectory: workingDirectory.map { FilePath($0) },
            platformOptions: subprocessPlatformOptions(teardownSequence: teardownSequence)
        )
    }

    private static func resolveExecutable(
        _ executable: String,
        searchPaths: [String],
        workingDirectory: String?
    ) throws -> String {
        if executable.contains("/") {
            let path = absolutePath(executable, relativeTo: workingDirectory)
            guard isExecutableFile(atPath: path) else {
                throw ShellError.commandNotFound(executable)
            }
            return path
        }

        for directory in searchPaths {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(executable).path
            if isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw ShellError.commandNotFound(executable)
    }

    /// Whether `path` is a file that can be spawned.
    ///
    /// Directories carry the execute bit, so `isExecutableFile(atPath:)` alone accepts them; a
    /// search-path directory that happens to share the command's name would then shadow the real
    /// executable further down the path. swift-subprocess 1.0.0 excludes directories from its own
    /// lookup for the same reason.
    private static func isExecutableFile(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && FileManager.default.isExecutableFile(atPath: path)
    }

    private static func resolveOutputDestination(
        _ destination: OutputDestination,
        workingDirectory: String?
    ) -> OutputDestination {
        guard case let .file(path, append) = destination else { return destination }
        return .file(path: absolutePath(path, relativeTo: workingDirectory), append: append)
    }

    private static func validateOutputDestinations(
        stdout: OutputDestination,
        stderr: OutputDestination
    ) throws {
        guard case let .file(stdoutPath, stdoutAppend) = stdout,
            case let .file(stderrPath, stderrAppend) = stderr,
            stdoutPath == stderrPath,
            !stdoutAppend || !stderrAppend
        else { return }

        throw ShellError.invalidConfiguration(
            description: "stdout and stderr cannot overwrite the same file; use append mode for both streams"
        )
    }

    private static func absolutePath(_ path: String, relativeTo directory: String? = nil) -> String {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        let base =
            directory.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL.path
    }
}

private struct CaptureLimitExceeded: Error, Sendable {}

private enum EarlyTerminationReason: Sendable {
    case outputLimitExceeded(command: String, limit: Int)
}

private actor RunEventNotifier<Event: Sendable> {
    private var continuation: CheckedContinuation<Event, Never>?
    private var event: Event?

    func wait() async -> Event {
        if let event {
            return event
        }

        return await withCheckedContinuation { continuation in
            if let event {
                continuation.resume(returning: event)
            } else {
                self.continuation = continuation
            }
        }
    }

    func notify(_ event: Event) {
        guard self.event == nil else { return }
        self.event = event
        continuation?.resume(returning: event)
        continuation = nil
    }
}

private struct CaptureSnapshot: Sendable {
    let stdout: Data
    let stderr: Data
}

/// Accumulates captured bytes from stdout and stderr up to a shared byte limit.
///
/// A mutex serializes access so concurrent stream tasks can safely append data. When the total
/// captured byte count exceeds the limit, ``append(_:to:)`` throws ``CaptureLimitExceeded`` after
/// storing as many bytes as will fit.
///
/// Chunks are kept as they arrive and joined once, at their exact final size, by ``snapshot()``.
/// Appending to one growing `Data` instead reallocates and copies it repeatedly, and on macOS leaves
/// a trail of freed-but-resident large blocks behind every large capture.
private final class OutputCaptureStore: Sendable {
    private struct Chunks {
        var capturedByteCount = 0
        var stdout: [Data] = []
        var stderr: [Data] = []
    }

    private let limit: Int
    private let chunks = Mutex(Chunks())

    init(limit: Int) {
        self.limit = limit
    }

    func append(_ data: Data, to stream: StreamKind) throws {
        let exceeded = chunks.withLock { chunks in
            let remaining = limit - chunks.capturedByteCount
            guard remaining > 0 else { return true }

            let accepted = data.count > remaining ? data.prefix(remaining) : data
            if !accepted.isEmpty {
                switch stream {
                case .stdout: chunks.stdout.append(accepted)
                case .stderr: chunks.stderr.append(accepted)
                }
                chunks.capturedByteCount += accepted.count
            }
            return data.count > remaining
        }
        if exceeded {
            throw CaptureLimitExceeded()
        }
    }

    func snapshot() -> CaptureSnapshot {
        chunks.withLock { chunks in
            CaptureSnapshot(stdout: joined(chunks.stdout), stderr: joined(chunks.stderr))
        }
    }
}

/// Concatenates captured chunks into one `Data` with a single allocation of the final size.
private func joined(_ chunks: [Data]) -> Data {
    if chunks.count == 1 {
        return chunks[0]
    }
    var data = Data(capacity: chunks.reduce(0) { $0 + $1.count })
    for chunk in chunks {
        data.append(chunk)
    }
    return data
}

private struct SingleCommandRunner {
    let resolved: ResolvedCommand

    func run() async throws -> ShellOutput {
        let store = OutputCaptureStore(limit: resolved.outputLimit)
        let eventNotifier = RunEventNotifier<SingleCommandRunEvent>()
        let processTask = Task {
            do {
                let output = try await runSubprocess(store: store, eventNotifier: eventNotifier)
                await eventNotifier.notify(.completed(.success(output)))
                return output
            } catch {
                await eventNotifier.notify(.completed(.failure(errorDescription: String(describing: error))))
                throw error
            }
        }
        let timeoutTask = resolved.timeout.map { timeout in
            Task {
                try? await Task.sleep(for: timeout)
                await eventNotifier.notify(.timedOut)
            }
        }
        defer { timeoutTask?.cancel() }

        do {
            return try await withTaskCancellationHandler {
                try await waitForSubprocess(
                    processTask: processTask,
                    store: store,
                    eventNotifier: eventNotifier
                )
            } onCancel: {
                processTask.cancel()
                Task {
                    await eventNotifier.notify(.canceled)
                }
            }
        } catch is CancellationError {
            processTask.cancel()
            _ = await processTask.result
            let output = makeOutput(snapshot: store.snapshot(), exitCode: -1)
            throw ShellError.canceled(command: resolved.displayCommand, partialOutput: output)
        }
    }

    private func runSubprocess(
        store: OutputCaptureStore,
        eventNotifier: RunEventNotifier<SingleCommandRunEvent>
    ) async throws -> ShellOutput {
        do {
            let (stdinRoute, stdoutRoute, stderrRoute) = try makeRoutes(
                stdin: resolved.stdinSource,
                stdout: resolved.stdoutDestination,
                stderr: resolved.stderrDestination
            )
            // Throwing out of the body (or cancelling this task) makes swift-subprocess run the
            // configuration's teardown sequence, killing the process group.
            let terminationStatus = try await runRouted(
                resolved.configuration,
                stdin: stdinRoute,
                stdout: stdoutRoute,
                stderr: stderrRoute
            ) { outputSequence, errorSequence in
                try await captureStreams(stdout: outputSequence, stderr: errorSequence, of: resolved, into: store) {
                    await eventNotifier.notify(
                        .earlyTerminated(
                            .outputLimitExceeded(command: resolved.displayCommand, limit: resolved.outputLimit)
                        )
                    )
                }
            }

            let snapshot = store.snapshot()
            let output = makeOutput(snapshot: snapshot, exitCode: terminationStatus.swiftyShellExitCode)

            if Task.isCancelled {
                throw ShellError.canceled(command: resolved.displayCommand, partialOutput: output)
            }

            if !terminationStatus.isSuccess {
                throw ShellError.exitFailure(command: resolved.displayCommand, output: output)
            }

            return output
        } catch is CaptureLimitExceeded {
            let output = makeOutput(snapshot: store.snapshot(), exitCode: -1)
            throw ShellError.outputLimitExceeded(
                command: resolved.displayCommand,
                limit: resolved.outputLimit,
                partialOutput: output
            )
        } catch is CancellationError {
            let output = makeOutput(snapshot: store.snapshot(), exitCode: -1)
            throw ShellError.canceled(command: resolved.displayCommand, partialOutput: output)
        } catch let error as ShellError {
            throw error
        } catch let error as SubprocessError {
            throw mapSubprocessError(error, command: resolved.displayCommand, limit: resolved.outputLimit)
        } catch {
            throw ShellError.spawnError(command: resolved.displayCommand, reason: String(describing: error))
        }
    }

    private func waitForSubprocess(
        processTask: Task<ShellOutput, any Error>,
        store: OutputCaptureStore,
        eventNotifier: RunEventNotifier<SingleCommandRunEvent>
    ) async throws -> ShellOutput {
        switch await eventNotifier.wait() {
        case let .completed(.success(output)):
            return output
        case .completed(.failure):
            return try await processTask.value
        case .timedOut:
            processTask.cancel()
            _ = await processTask.result
            let output = makeOutput(snapshot: store.snapshot(), exitCode: -1)
            throw ShellError.timeout(
                command: resolved.displayCommand,
                duration: resolved.timeout ?? .zero,
                partialOutput: output
            )
        case let .earlyTerminated(reason):
            processTask.cancel()
            _ = await processTask.result
            switch reason {
            case let .outputLimitExceeded(command, limit):
                let output = makeOutput(snapshot: store.snapshot(), exitCode: -1)
                throw ShellError.outputLimitExceeded(command: command, limit: limit, partialOutput: output)
            }
        case .canceled:
            processTask.cancel()
            _ = await processTask.result
            let output = makeOutput(snapshot: store.snapshot(), exitCode: -1)
            throw ShellError.canceled(command: resolved.displayCommand, partialOutput: output)
        }
    }
}

private enum SingleCommandProcessCompletion: Sendable {
    case success(ShellOutput)
    case failure(errorDescription: String)
}

private enum SingleCommandRunEvent: Sendable {
    case completed(SingleCommandProcessCompletion)
    case timedOut
    case earlyTerminated(EarlyTerminationReason)
    case canceled
}

private enum SpawnedCommandTaskResult: Sendable {
    case streamComplete
}

/// Keeps the most recent chunks of a live spawned-process stream that the caller has not read yet.
private let liveStreamBufferingPolicy = AsyncStream<String>.Continuation.BufferingPolicy.bufferingNewest(1024)

private struct SpawnedCommandRunner: Sendable {
    let resolved: ResolvedCommand
    let teardown: TeardownStrategy

    func spawn() async throws -> any SpawnedProcess {
        // Bounded so an unread stream cannot grow without limit over a long-lived process.
        let stdoutStream = AsyncStream.makeStream(of: String.self, bufferingPolicy: liveStreamBufferingPolicy)
        let stderrStream = AsyncStream.makeStream(of: String.self, bufferingPolicy: liveStreamBufferingPolicy)
        let state = SubprocessSpawnedProcessState(teardown: teardown)
        let task = Task<ShellOutput, Never> {
            let output = await runSpawnedProcess(
                state: state,
                stdoutContinuation: stdoutStream.continuation,
                stderrContinuation: stderrStream.continuation
            )
            await state.markExited()
            return output
        }
        await state.attachTask(task)
        let execution = try await state.waitForExecution()
        return SubprocessSpawnedProcess(
            processIdentifier: execution.processIdentifier,
            standardOutput: stdoutStream.stream,
            standardError: stderrStream.stream,
            state: state
        )
    }

    private func runSpawnedProcess(
        state: SubprocessSpawnedProcessState,
        stdoutContinuation: AsyncStream<String>.Continuation,
        stderrContinuation: AsyncStream<String>.Continuation
    ) async -> ShellOutput {
        let store = OutputCaptureStore(limit: resolved.outputLimit)
        do {
            let stdoutHandle = try openFileHandleIfNeeded(for: resolved.stdoutDestination)
            let stderrHandle = try openFileHandleIfNeeded(for: resolved.stderrDestination)
            defer {
                try? stdoutHandle?.close()
                try? stderrHandle?.close()
                stdoutContinuation.finish()
                stderrContinuation.finish()
            }

            let streams = SpawnedStreams(
                stdoutHandle: stdoutHandle,
                stderrHandle: stderrHandle,
                store: store,
                stdoutContinuation: stdoutContinuation,
                stderrContinuation: stderrContinuation
            )
            let terminationStatus: TerminationStatus
            switch try makeStdinRoute(for: resolved.stdinSource) {
            case .none:
                terminationStatus = try await runSubprocess(input: NoInput.none, state: state, streams: streams)
            case let .data(data):
                terminationStatus = try await runSubprocess(input: DataInput.data(data), state: state, streams: streams)
            case let .descriptor(fileDescriptor):
                terminationStatus = try await runSubprocess(
                    input: FileDescriptorInput.fileDescriptor(fileDescriptor, closeAfterSpawningProcess: true),
                    state: state,
                    streams: streams
                )
            }

            return makeOutput(snapshot: store.snapshot(), exitCode: terminationStatus.swiftyShellExitCode)
        } catch is CaptureLimitExceeded {
            return makeOutput(snapshot: store.snapshot(), exitCode: -1)
        } catch {
            await state.failStartupIfNeeded(error)
            return makeOutput(snapshot: store.snapshot(), exitCode: -1)
        }
    }

    /// Runs the spawned process with `input` as its stdin, streaming both outputs live.
    private func runSubprocess<Input: InputProtocol>(
        input: Input,
        state: SubprocessSpawnedProcessState,
        streams: SpawnedStreams
    ) async throws -> TerminationStatus {
        // The spawned configuration carries the caller's `TeardownStrategy` as its teardown
        // sequence, so swift-subprocess applies it itself if the body throws.
        let outcome = try await Subprocess.run(
            resolved.configuration(teardownSequence: teardown.subprocessSteps),
            input: input,
            output: .sequence,
            error: .sequence
        ) { execution in
            await state.setExecution(SpawnedExecution(execution))
            let outputSequence = execution.standardOutput
            let errorSequence = execution.standardError
            try await withThrowingTaskGroup(of: SpawnedCommandTaskResult.self) { group in
                group.addTask {
                    try await routeSpawnStream(
                        outputSequence,
                        stream: .stdout,
                        destination: resolved.stdoutDestination,
                        fileHandle: streams.stdoutHandle,
                        store: streams.store,
                        continuation: streams.stdoutContinuation
                    )
                    return .streamComplete
                }
                group.addTask {
                    try await routeSpawnStream(
                        errorSequence,
                        stream: .stderr,
                        destination: resolved.stderrDestination,
                        fileHandle: streams.stderrHandle,
                        store: streams.store,
                        continuation: streams.stderrContinuation
                    )
                    return .streamComplete
                }
                var completedStreams = 0
                do {
                    while let result = try await group.next() {
                        switch result {
                        case .streamComplete:
                            completedStreams += 1
                            if completedStreams == 2 {
                                group.cancelAll()
                                return
                            }
                        }
                    }
                } catch is CaptureLimitExceeded {
                    group.cancelAll()
                    throw CaptureLimitExceeded()
                }
            }
        }
        return outcome.terminationStatus
    }
}

/// Where a spawned process's output goes while it runs.
private struct SpawnedStreams: Sendable {
    let stdoutHandle: FileHandle?
    let stderrHandle: FileHandle?
    let store: OutputCaptureStore
    let stdoutContinuation: AsyncStream<String>.Continuation
    let stderrContinuation: AsyncStream<String>.Continuation
}

private final class SubprocessSpawnedProcess: SpawnedProcess, @unchecked Sendable {
    let processIdentifier: Int32
    let standardOutput: AsyncStream<String>
    let standardError: AsyncStream<String>

    private let state: SubprocessSpawnedProcessState

    init(
        processIdentifier: Int32,
        standardOutput: AsyncStream<String>,
        standardError: AsyncStream<String>,
        state: SubprocessSpawnedProcessState
    ) {
        self.processIdentifier = processIdentifier
        self.standardOutput = standardOutput
        self.standardError = standardError
        self.state = state
    }

    deinit {
        let state = state
        Task {
            _ = await state.teardownAndWait()
        }
    }

    func send(_ signal: ProcessSignal) async throws {
        try await state.send(signal)
    }

    func teardownAndWait() async -> ShellOutput {
        await state.teardownAndWait()
    }

    func waitForExit() async -> ShellOutput {
        await state.waitForExit()
    }
}

private actor SubprocessSpawnedProcessState {
    private let teardown: TeardownStrategy
    private var task: Task<ShellOutput, Never>?
    private var cachedOutput: ShellOutput?
    private var executionResult: Result<SpawnedExecution, any Error>?
    private var executionContinuations: [CheckedContinuation<Result<SpawnedExecution, any Error>, Never>] = []
    private var didTeardown = false
    private var hasExited = false

    init(teardown: TeardownStrategy) {
        self.teardown = teardown
    }

    func attachTask(_ task: Task<ShellOutput, Never>) {
        self.task = task
    }

    func setExecution(_ execution: SpawnedExecution) {
        guard executionResult == nil else { return }
        executionResult = .success(execution)
        resumeExecutionContinuations(with: .success(execution))
    }

    func failStartupIfNeeded(_ error: any Error) {
        guard executionResult == nil else { return }
        executionResult = .failure(error)
        resumeExecutionContinuations(with: .failure(error))
    }

    func waitForExecution() async throws -> SpawnedExecution {
        let result: Result<SpawnedExecution, any Error>
        if let executionResult {
            result = executionResult
        } else {
            result = await withCheckedContinuation { continuation in
                executionContinuations.append(continuation)
            }
        }
        return try result.get()
    }

    private func resumeExecutionContinuations(with result: Result<SpawnedExecution, any Error>) {
        let continuations = executionContinuations
        executionContinuations.removeAll(keepingCapacity: false)
        for continuation in continuations {
            continuation.resume(returning: result)
        }
    }

    func send(_ signal: ProcessSignal) async throws {
        let execution = try await waitForExecution()
        try execution.send(signal.subprocessSignal)
    }

    func teardownAndWait() async -> ShellOutput {
        if !didTeardown {
            didTeardown = true
            if !hasExited, let execution = try? await waitForExecution() {
                await execution.teardown(using: teardown.subprocessSteps)
                // swift-subprocess stops tearing down as soon as the process itself exits, so a
                // descendant that ignored an earlier step's signal (for example a background job,
                // which starts with SIGINT ignored) would survive. Kill whatever is left of the
                // group. This is sent unconditionally: the process may already have been reaped
                // (swift-subprocess stops waiting on the output pipes once it exits) while
                // descendants live on, so `hasExited` cannot tell whether anything remains. A group
                // ID cannot be reused while any member is alive; only if every member exited during
                // the teardown await could the ID be free, and it would have to be reused by an
                // unrelated group within that instant for this kill to reach it.
                try? execution.send(.kill, toProcessGroup: true)
            }
        }
        return await output()
    }

    func markExited() {
        hasExited = true
    }

    func waitForExit() async -> ShellOutput {
        return await output()
    }

    private func output() async -> ShellOutput {
        if let cachedOutput { return cachedOutput }
        guard let task else { return ShellOutput(exitCode: -1) }
        let output = await task.value
        cachedOutput = output
        return output
    }
}

private func routeSpawnStream(
    _ sequence: SubprocessOutputSequence,
    stream: StreamKind,
    destination: OutputDestination,
    fileHandle: FileHandle?,
    store: OutputCaptureStore,
    continuation: AsyncStream<String>.Continuation
) async throws {
    var decoder = UTF8ChunkDecoder()
    defer {
        if let text = decoder.finish() {
            continuation.yield(text)
        }
    }
    for try await buffer in sequence {
        let data = Data(buffer: buffer)
        if let text = decoder.decode(data) {
            continuation.yield(text)
        }
        try routeData(data, stream: stream, destination: destination, fileHandle: fileHandle, store: store)
    }
}

/// Reads the streams SwiftyShell captures (`.capture` and `.tee`) concurrently into `store`.
///
/// Streams the child writes elsewhere arrive as `nil` and are skipped. When a stream exceeds the
/// output limit, `onLimitExceeded` runs from inside that stream's task, before the error unwinds the
/// group: the group would otherwise wait for the other stream, which only ends once the process
/// exits, and the process may be blocked writing to the stream nobody is reading any more.
private func captureStreams(
    stdout: SubprocessOutputSequence?,
    stderr: SubprocessOutputSequence?,
    of command: ResolvedCommand,
    into store: OutputCaptureStore,
    onLimitExceeded: @escaping @Sendable () async -> Void
) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for (sequence, stream, destination) in [
            (stdout, StreamKind.stdout, command.stdoutDestination),
            (stderr, StreamKind.stderr, command.stderrDestination),
        ] {
            guard let sequence else { continue }
            group.addTask {
                do {
                    try await captureStream(sequence, stream: stream, destination: destination, into: store)
                } catch is CaptureLimitExceeded {
                    await onLimitExceeded()
                    throw CaptureLimitExceeded()
                }
            }
        }
        try await group.waitForAll()
    }
}

private func captureStream(
    _ sequence: SubprocessOutputSequence,
    stream: StreamKind,
    destination: OutputDestination,
    into store: OutputCaptureStore
) async throws {
    for try await buffer in sequence {
        let data = Data(buffer: buffer)
        try store.append(data, to: stream)
        if destination == .tee {
            try writeTee(data, to: stream)
        }
    }
}

/// How one output stream of a child process is wired.
private enum StreamRoute {
    /// SwiftyShell reads the stream through a pipe (``OutputDestination/capture`` and
    /// ``OutputDestination/tee``).
    case read
    /// The child writes to the null device; SwiftyShell never sees the bytes.
    case discarded
    /// The child writes straight to this descriptor, which swift-subprocess closes in this process
    /// once the child is spawned (or the spawn fails).
    case descriptor(FileDescriptor)

    /// Closes a descriptor that was opened but never handed to swift-subprocess.
    func closeUnused() {
        if case let .descriptor(fileDescriptor) = self {
            try? fileDescriptor.close()
        }
    }
}

/// Wires a stream for `run()`: `.discard` and `.file` are handed to the child, so their bytes never
/// pass through this process.
private func makeRoute(for destination: OutputDestination) throws -> StreamRoute {
    switch destination {
    case .capture, .tee:
        return .read
    case .discard:
        return .discarded
    case let .file(path, append):
        return .descriptor(try openOutputFile(path: path, append: append))
    }
}

private func makeRoutes(
    stdout: OutputDestination,
    stderr: OutputDestination
) throws -> (stdout: StreamRoute, stderr: StreamRoute) {
    let stdoutRoute = try makeRoute(for: stdout)
    do {
        return (stdoutRoute, try makeRoute(for: stderr))
    } catch {
        stdoutRoute.closeUnused()
        throw error
    }
}

/// Opens `path` for a child's output the way shell redirection does: created with `0666` (less the
/// umask) if missing, then truncated or opened for appending.
private func openOutputFile(path: String, append: Bool) throws -> FileDescriptor {
    try FileDescriptor.open(
        FilePath(path),
        .writeOnly,
        options: append ? [.create, .append] : [.create, .truncate],
        permissions: [.ownerReadWrite, .groupReadWrite, .otherReadWrite]
    )
}

/// How a child's stdin is wired.
private enum StdinRoute {
    /// An empty stdin.
    case none
    /// Bytes swift-subprocess writes to the child's stdin, then closes it.
    case data(Data)
    /// A descriptor the child reads directly; swift-subprocess closes it here once spawned.
    case descriptor(FileDescriptor)

    /// Closes a descriptor that was opened but never handed to swift-subprocess.
    func closeUnused() {
        if case let .descriptor(fileDescriptor) = self {
            try? fileDescriptor.close()
        }
    }
}

private func makeStdinRoute(for source: InputSource) throws -> StdinRoute {
    switch source {
    case .none:
        return .none
    case let .data(data):
        return .data(data)
    case let .string(text):
        return .data(Data(text.utf8))
    case let .file(path):
        return .descriptor(try FileDescriptor.open(FilePath(path), .readOnly))
    }
}

/// Opens the stdin and output routes for one process, closing anything already opened if a later
/// route fails.
private func makeRoutes(
    stdin: InputSource,
    stdout: OutputDestination,
    stderr: OutputDestination
) throws -> (stdin: StdinRoute, stdout: StreamRoute, stderr: StreamRoute) {
    let stdinRoute = try makeStdinRoute(for: stdin)
    do {
        let (stdoutRoute, stderrRoute) = try makeRoutes(stdout: stdout, stderr: stderr)
        return (stdinRoute, stdoutRoute, stderrRoute)
    } catch {
        stdinRoute.closeUnused()
        throw error
    }
}

/// Runs `configuration` with stdin and each output stream wired per their routes; see
/// ``runRouted(_:input:stdout:stderr:body:)``.
private func runRouted(
    _ configuration: Configuration,
    stdin: StdinRoute,
    stdout: StreamRoute,
    stderr: StreamRoute,
    body: (SubprocessOutputSequence?, SubprocessOutputSequence?) async throws -> Void
) async throws -> TerminationStatus {
    switch stdin {
    case .none:
        return try await runRouted(configuration, input: NoInput.none, stdout: stdout, stderr: stderr, body: body)
    case let .data(data):
        return try await runRouted(
            configuration,
            input: DataInput.data(data),
            stdout: stdout,
            stderr: stderr,
            body: body
        )
    case let .descriptor(fileDescriptor):
        return try await runRouted(
            configuration,
            input: FileDescriptorInput.fileDescriptor(fileDescriptor, closeAfterSpawningProcess: true),
            stdout: stdout,
            stderr: stderr,
            body: body
        )
    }
}

/// Runs `configuration` with each output stream wired per its route and calls `body` with the
/// sequences of the routes SwiftyShell reads (`nil` for streams the child writes elsewhere).
///
/// swift-subprocess exposes `standardOutput` / `standardError` only when that stream's output type
/// is `SequenceOutput`, so each route is turned into a concrete output type one stream at a time and
/// the sequences are recovered with a runtime cast inside the body.
private func runRouted<Input: InputProtocol>(
    _ configuration: Configuration,
    input: Input,
    stdout: StreamRoute,
    stderr: StreamRoute,
    body: (SubprocessOutputSequence?, SubprocessOutputSequence?) async throws -> Void
) async throws -> TerminationStatus {
    switch stdout {
    case .read:
        return try await runRouted(
            configuration,
            input: input,
            output: SequenceOutput.sequence,
            stderr: stderr,
            body: body
        )
    case .discarded:
        return try await runRouted(
            configuration,
            input: input,
            output: DiscardedOutput.discarded,
            stderr: stderr,
            body: body
        )
    case let .descriptor(fileDescriptor):
        return try await runRouted(
            configuration,
            input: input,
            output: FileDescriptorOutput.fileDescriptor(fileDescriptor, closeAfterSpawningProcess: true),
            stderr: stderr,
            body: body
        )
    }
}

private func runRouted<Input: InputProtocol, Output: OutputProtocol>(
    _ configuration: Configuration,
    input: Input,
    output: Output,
    stderr: StreamRoute,
    body: (SubprocessOutputSequence?, SubprocessOutputSequence?) async throws -> Void
) async throws -> TerminationStatus {
    switch stderr {
    case .read:
        return try await runRouted(
            configuration,
            input: input,
            output: output,
            error: SequenceOutput.sequence,
            body: body
        )
    case .discarded:
        return try await runRouted(
            configuration,
            input: input,
            output: output,
            error: DiscardedOutput.discarded,
            body: body
        )
    case let .descriptor(fileDescriptor):
        return try await runRouted(
            configuration,
            input: input,
            output: output,
            error: FileDescriptorOutput.fileDescriptor(fileDescriptor, closeAfterSpawningProcess: true),
            body: body
        )
    }
}

private func runRouted<Input: InputProtocol, Output: OutputProtocol, Error: ErrorOutputProtocol>(
    _ configuration: Configuration,
    input: Input,
    output: Output,
    error: Error,
    body: (SubprocessOutputSequence?, SubprocessOutputSequence?) async throws -> Void
) async throws -> TerminationStatus {
    let result = try await Subprocess.run(configuration, input: input, output: output, error: error) { execution in
        let outputSequence = (execution as Any as? Execution<Input, SequenceOutput, Error>)?.standardOutput
        let errorSequence = (execution as Any as? Execution<Input, Output, SequenceOutput>)?.standardError
        try await body(outputSequence, errorSequence)
    }
    return result.terminationStatus
}

private func routeData(
    _ data: Data,
    stream: StreamKind,
    destination: OutputDestination,
    fileHandle: FileHandle?,
    store: OutputCaptureStore
) throws {
    switch destination {
    case .capture:
        try store.append(data, to: stream)
    case .discard:
        break
    case .file:
        try fileHandle?.write(contentsOf: data)
    case .tee:
        // Capture for ShellOutput…
        try store.append(data, to: stream)
        // …and echo live to the parent process stream.
        try writeTee(data, to: stream)
    }
}

/// Serializes live `.tee` writes to the parent process's standard output and standard error.
///
/// Routing tasks for stdout and stderr run concurrently, so without coordination their writes to
/// `FileHandle.standardOutput` / `FileHandle.standardError` could interleave mid-buffer and corrupt
/// each other. A single shared mutex guards every live write.
private let teeLock = Mutex(())

private func writeTee(_ data: Data, to stream: StreamKind) throws {
    let handle: FileHandle = (stream == .stdout) ? .standardOutput : .standardError
    try teeLock.withLock { _ in
        try handle.write(contentsOf: data)
    }
}

/// Opens a ``FileHandle`` for writing if the destination is a `.file`, otherwise returns `nil`.
private func openFileHandleIfNeeded(for destination: OutputDestination) throws -> FileHandle? {
    guard case let .file(path, append) = destination else {
        return nil
    }
    return try makeFileHandle(path: path, append: append)
}

private struct PipelineRunner {
    let resolved: [ResolvedCommand]

    func run() async throws -> ShellOutput {
        precondition(!resolved.isEmpty)
        return try await runPipelineStages()
    }

    private func runPipelineStages() async throws -> ShellOutput {
        let pipes = try makePipelineFileDescriptors(stageCount: resolved.count)
        let stageInputs = try resolved.indices.map { index in
            index == 0 ? nil : try duplicate(pipes[index - 1].readEnd)
        }
        let stageOutputs = try resolved.indices.map { index in
            index == resolved.count - 1 ? nil : try duplicate(pipes[index].writeEnd)
        }
        pipes.forEach { pipe in
            try? pipe.readEnd.close()
            try? pipe.writeEnd.close()
        }

        let stores = resolved.map { OutputCaptureStore(limit: $0.outputLimit) }
        let finalCommand = resolved[resolved.count - 1]
        let eventNotifier = RunEventNotifier<PipelineRunEvent>()
        let processTask = Task {
            do {
                let output = try await runPipelineProcess(
                    stageInputs: stageInputs,
                    stageOutputs: stageOutputs,
                    stores: stores,
                    eventNotifier: eventNotifier
                )
                await eventNotifier.notify(.completed(.success(output)))
                return output
            } catch {
                await eventNotifier.notify(.completed(.failure(errorDescription: String(describing: error))))
                throw error
            }
        }
        let timeoutTask = resolved.compactMap(\.timeout).min().map { timeout in
            Task {
                try? await Task.sleep(for: timeout)
                await eventNotifier.notify(.timedOut(duration: timeout))
            }
        }
        defer { timeoutTask?.cancel() }

        do {
            return try await withTaskCancellationHandler {
                try await waitForPipeline(
                    processTask: processTask,
                    stores: stores,
                    eventNotifier: eventNotifier,
                    finalCommand: finalCommand
                )
            } onCancel: {
                processTask.cancel()
                Task {
                    await eventNotifier.notify(.canceled)
                }
            }
        } catch is CancellationError {
            processTask.cancel()
            _ = await processTask.result
            let snapshot = pipelineSnapshot(stores: stores)
            throw ShellError.canceled(
                command: finalCommand.displayCommand,
                partialOutput: makeOutput(snapshot: snapshot, exitCode: -1)
            )
        }
    }

    private func runPipelineProcess(
        stageInputs: [FileDescriptor?],
        stageOutputs: [FileDescriptor?],
        stores: [OutputCaptureStore],
        eventNotifier: RunEventNotifier<PipelineRunEvent>
    ) async throws -> ShellOutput {
        let finalCommand = resolved[resolved.count - 1]

        do {
            return try await withThrowingTaskGroup(of: PipelineTaskResult.self, returning: ShellOutput.self) { group in
                for index in resolved.indices {
                    let command = resolved[index]
                    let input = stageInputs[index]
                    let output = stageOutputs[index]
                    let store = stores[index]

                    group.addTask {
                        do {
                            return .stage(
                                try await runPipelineStage(
                                    index: index,
                                    command: command,
                                    input: input,
                                    pipedOutput: output,
                                    store: store,
                                    eventNotifier: eventNotifier
                                )
                            )
                        } catch is CaptureLimitExceeded {
                            await eventNotifier.notify(
                                .earlyTerminated(
                                    .outputLimitExceeded(command: command.displayCommand, limit: command.outputLimit)
                                )
                            )
                            return .captureLimitExceeded(index: index)
                        } catch is CancellationError {
                            return .canceled(index: index)
                        } catch let error as ShellError {
                            return .failure(index: index, error: error)
                        } catch let error as SubprocessError {
                            // On Linux, a cancelled task can receive a SubprocessError
                            // from swift-subprocess during spawn teardown rather than a
                            // CancellationError. Treat it as cancellation so a legitimate
                            // first-stage failure (already recorded in firstFailure) is
                            // not masked by a spawn error from a subsequently-cancelled stage.
                            if Task.isCancelled {
                                return .canceled(index: index)
                            }
                            return .failure(
                                index: index,
                                error: mapSubprocessError(
                                    error,
                                    command: command.displayCommand,
                                    limit: command.outputLimit
                                )
                            )
                        } catch {
                            if Task.isCancelled {
                                return .canceled(index: index)
                            }
                            return .failure(
                                index: index,
                                error: ShellError.spawnError(
                                    command: command.displayCommand,
                                    reason: String(describing: error)
                                )
                            )
                        }
                    }
                }

                // Timeout is handled by the outer timeoutTask in runPipelineStages, which
                // notifies via eventNotifier and cancels the processTask. Do not add an inner
                // timeout task here: when a stage exits with a signal (e.g. SIGKILL / exit 137
                // on Linux) due to pipe closure after the first stage is torn down, the inner
                // timeout task would be cancelled by group.cancelAll() before it can return
                // .timedOut, causing the pipeline to surface exitFailure instead of timeout.

                var stageResults: [PipelineStageResult] = []
                var firstFailure: PipelineStageResult?
                var firstThrownFailure: ShellError?
                var firstCaptureLimitIndex: Int?

                while let result = try await group.next() {
                    switch result {
                    case let .stage(stageResult):
                        stageResults.append(stageResult)
                        // Only treat a non-zero exit as a failure when this task has not
                        // been cancelled. On Linux, when the outer timeout fires,
                        // waitForPipeline cancels processTask, and each stage's cancelled run()
                        // tears down its process group. Downstream stages that are SIGKILLed
                        // (exit 137) return a PipelineStageResult before the CancellationError
                        // propagates through the stage task. Checking Task.isCancelled here prevents those
                        // signal-induced exits from masking the ShellError.timeout that
                        // waitForPipeline already threw.
                        // A non-final stage killed by SIGPIPE only means a downstream stage
                        // stopped reading early (`yes | head -n 1`); the shell treats that as
                        // success, so it is not a pipeline failure here either.
                        let isBenignBrokenPipe = stageResult.brokePipe && stageResult.index < resolved.count - 1
                        if stageResult.exitCode != 0, !isBenignBrokenPipe, firstFailure == nil, !Task.isCancelled {
                            firstFailure = stageResult
                            group.cancelAll()
                        }
                    case .canceled:
                        break
                    case let .failure(_, error):
                        if firstThrownFailure == nil, !Task.isCancelled {
                            firstThrownFailure = error
                            group.cancelAll()
                        }
                    case let .captureLimitExceeded(index):
                        if firstCaptureLimitIndex == nil {
                            firstCaptureLimitIndex = index
                            group.cancelAll()
                        }
                    }
                }

                let snapshot = pipelineSnapshot(stores: stores)

                if Task.isCancelled {
                    throw ShellError.canceled(
                        command: finalCommand.displayCommand,
                        partialOutput: makeOutput(snapshot: snapshot, exitCode: -1)
                    )
                }

                if let firstThrownFailure {
                    throw firstThrownFailure
                }

                let output = makeOutput(
                    snapshot: snapshot,
                    exitCode: stageResults.first { $0.index == resolved.count - 1 }?.exitCode ?? 0
                )

                if let firstCaptureLimitIndex {
                    let command = resolved[firstCaptureLimitIndex]
                    throw ShellError.outputLimitExceeded(
                        command: command.displayCommand,
                        limit: command.outputLimit,
                        partialOutput: output
                    )
                }

                if let firstFailure {
                    throw ShellError.exitFailure(
                        command: firstFailure.command.displayCommand,
                        output: ShellOutput(
                            stdoutData: output.stdoutData,
                            stderrData: output.stderrData,
                            exitCode: firstFailure.exitCode
                        )
                    )
                }

                return output
            }
        } catch is CancellationError {
            let snapshot = pipelineSnapshot(stores: stores)
            throw ShellError.canceled(
                command: finalCommand.displayCommand,
                partialOutput: makeOutput(snapshot: snapshot, exitCode: -1)
            )
        }
    }

    private func waitForPipeline(
        processTask: Task<ShellOutput, any Error>,
        stores: [OutputCaptureStore],
        eventNotifier: RunEventNotifier<PipelineRunEvent>,
        finalCommand: ResolvedCommand
    ) async throws -> ShellOutput {
        switch await eventNotifier.wait() {
        case let .completed(.success(output)):
            return output
        case .completed(.failure):
            return try await processTask.value
        case let .timedOut(duration):
            processTask.cancel()
            _ = await processTask.result
            let snapshot = pipelineSnapshot(stores: stores)
            throw ShellError.timeout(
                command: finalCommand.displayCommand,
                duration: duration,
                partialOutput: makeOutput(snapshot: snapshot, exitCode: -1)
            )
        case let .earlyTerminated(reason):
            processTask.cancel()
            _ = await processTask.result
            switch reason {
            case let .outputLimitExceeded(command, limit):
                let output = makeOutput(snapshot: pipelineSnapshot(stores: stores), exitCode: -1)
                throw ShellError.outputLimitExceeded(command: command, limit: limit, partialOutput: output)
            }
        case .canceled:
            processTask.cancel()
            _ = await processTask.result
            let snapshot = pipelineSnapshot(stores: stores)
            throw ShellError.canceled(
                command: finalCommand.displayCommand,
                partialOutput: makeOutput(snapshot: snapshot, exitCode: -1)
            )
        }
    }
}

private enum PipelineProcessCompletion: Sendable {
    case success(ShellOutput)
    case failure(errorDescription: String)
}

private enum PipelineRunEvent: Sendable {
    case completed(PipelineProcessCompletion)
    case timedOut(duration: Duration)
    case earlyTerminated(EarlyTerminationReason)
    case canceled
}

private struct PipelinePipe: Sendable {
    let readEnd: FileDescriptor
    let writeEnd: FileDescriptor
}

private struct PipelineStageResult: Sendable {
    let index: Int
    let command: ResolvedCommand
    let exitCode: Int32
    /// Whether the stage was terminated by `SIGPIPE` after its reader went away.
    let brokePipe: Bool

    init(index: Int, command: ResolvedCommand, terminationStatus: TerminationStatus) {
        self.index = index
        self.command = command
        self.exitCode = terminationStatus.swiftyShellExitCode
        self.brokePipe = terminationStatus.isBrokenPipe
    }
}

private enum PipelineTaskResult: Sendable {
    case stage(PipelineStageResult)
    case canceled(index: Int)
    case failure(index: Int, error: ShellError)
    case captureLimitExceeded(index: Int)
}

private func makePipelineFileDescriptors(stageCount: Int) throws -> [PipelinePipe] {
    guard stageCount > 1 else { return [] }
    return try (0..<(stageCount - 1)).map { _ in
        let pipe = try FileDescriptor.pipe()
        return PipelinePipe(readEnd: pipe.readEnd, writeEnd: pipe.writeEnd)
    }
}

private func duplicate(_ fileDescriptor: FileDescriptor) throws -> FileDescriptor {
    try FileDescriptor(rawValue: fileDescriptor.rawValue).duplicate()
}

private func pipelineSnapshot(stores: [OutputCaptureStore]) -> CaptureSnapshot {
    var finalStdout = Data()
    var stderr = Data()
    for (index, store) in stores.enumerated() {
        let snapshot = store.snapshot()
        if index == stores.count - 1 {
            finalStdout = snapshot.stdout
        }
        stderr.append(snapshot.stderr)
    }
    return CaptureSnapshot(stdout: finalStdout, stderr: stderr)
}

private func runPipelineStage(
    index: Int,
    command: ResolvedCommand,
    input: FileDescriptor?,
    pipedOutput: FileDescriptor?,
    store: OutputCaptureStore,
    eventNotifier: RunEventNotifier<PipelineRunEvent>
) async throws -> PipelineStageResult {
    // Pipes to neighboring stages replace a stage's own stdin source and stdout destination.
    let stdinRoute: StdinRoute
    let stdoutRoute: StreamRoute
    let stderrRoute: StreamRoute
    do {
        let routes = try makeRoutes(
            stdin: input == nil ? command.stdinSource : .none,
            stdout: pipedOutput == nil ? command.stdoutDestination : .discard,
            stderr: command.stderrDestination
        )
        stdinRoute = input.map { .descriptor($0) } ?? routes.stdin
        stdoutRoute = pipedOutput.map { .descriptor($0) } ?? routes.stdout
        stderrRoute = routes.stderr
    } catch {
        try? input?.close()
        try? pipedOutput?.close()
        throw error
    }

    func capture(stdout: SubprocessOutputSequence?, stderr: SubprocessOutputSequence?) async throws {
        try await captureStreams(stdout: stdout, stderr: stderr, of: command, into: store) {
            await eventNotifier.notify(
                .earlyTerminated(.outputLimitExceeded(command: command.displayCommand, limit: command.outputLimit))
            )
        }
    }

    let terminationStatus = try await runRouted(
        command.configuration,
        stdin: stdinRoute,
        stdout: stdoutRoute,
        stderr: stderrRoute,
        body: capture
    )
    return PipelineStageResult(index: index, command: command, terminationStatus: terminationStatus)
}

private let forcedTeardownSequence: [TeardownStep] = [
    .send(signal: .kill, toProcessGroup: true, allowedDurationToNextStep: .seconds(1))
]

/// Makes every subprocess the leader of its own process group, so a group-targeted teardown
/// reaches only that command's process tree and never SwiftyShell's own group.
///
/// swift-subprocess runs `teardownSequence` itself whenever the task awaiting `run` is cancelled
/// or the body closure throws. On the body-throws path it tears down before reaping the leader;
/// on the cancellation path teardown runs concurrently with the reap, so the first group signal
/// is sent while the leader is still alive but a later step is not guaranteed to be.
private func subprocessPlatformOptions(teardownSequence: [TeardownStep]) -> PlatformOptions {
    var options = PlatformOptions()
    options.processGroupID = 0
    options.teardownSequence = teardownSequence
    return options
}

private extension TeardownStrategy {
    var subprocessSteps: [TeardownStep] {
        // swift-subprocess's implicit final kill inherits the last step's process-group targeting,
        // so an empty strategy needs an explicit group kill to reach descendants.
        guard !steps.isEmpty else { return forcedTeardownSequence }
        return steps.map { step in
            // Signal the whole process group (the child leads its own group) so wrappers such as
            // `sh -c` or `npm run` do not leave their descendants running.
            TeardownStep.send(
                signal: step.signal.subprocessSignal,
                toProcessGroup: true,
                allowedDurationToNextStep: step.gracePeriod
            )
        }
    }
}

private extension ProcessSignal {
    var subprocessSignal: Signal {
        switch self {
        case .interrupt:
            .interrupt
        case .terminate:
            .terminate
        case .kill:
            .kill
        case .hangup:
            .terminalClosed
        case .quit:
            .quit
        }
    }
}

private func makeOutput(snapshot: CaptureSnapshot, exitCode: Int32) -> ShellOutput {
    ShellOutput(stdoutData: snapshot.stdout, stderrData: snapshot.stderr, exitCode: exitCode)
}

private func mapSubprocessError(_ error: SubprocessError, command: String, limit: Int) -> ShellError {
    switch error.code {
    case .executableNotFound:
        return .commandNotFound(command)
    case .outputLimitExceeded:
        return .outputLimitExceeded(
            command: command,
            limit: limit,
            partialOutput: ShellOutput(stdout: "", stderr: "", exitCode: -1)
        )
    default:
        return .spawnError(command: command, reason: error.description)
    }
}

private func makeFileHandle(path: String, append: Bool) throws -> FileHandle {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path) {
        _ = fileManager.createFile(atPath: path, contents: nil)
    }
    let url = URL(fileURLWithPath: path)
    let handle = try FileHandle(forWritingTo: url)
    if append {
        _ = try handle.seekToEnd()
    } else {
        try handle.truncate(atOffset: 0)
        try handle.seek(toOffset: 0)
    }
    return handle
}

extension TerminationStatus {
    /// Whether the process was killed by `SIGPIPE`.
    fileprivate var isBrokenPipe: Bool {
        guard case let .signaled(signal) = self else { return false }
        return signal == SIGPIPE
    }

    fileprivate var swiftyShellExitCode: Int32 {
        switch self {
        case let .exited(code):
            Int32(code)
        case let .signaled(signal):
            128 + Int32(signal)
        }
    }
}

private extension String {
    var key: Environment.Key {
        Environment.Key(stringLiteral: self)
    }
}
