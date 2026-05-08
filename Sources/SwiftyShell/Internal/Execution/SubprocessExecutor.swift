import Foundation
import Subprocess

#if canImport(System)
import System
#else
import SystemPackage
#endif

/// The default ``CommandExecutor`` that runs commands using Swift's `Subprocess` package.
///
/// `SubprocessExecutor` is what ``ShellContext/init(executor:searchPaths:environment:workingDirectory:defaultTimeout:defaultOutputLimit:)``
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
    let timeout: TimeInterval?
    let outputLimit: Int
    let stdoutDestination: OutputDestination
    let stderrDestination: OutputDestination
    let displayCommand: String

    init(command: Command, context: ShellContext) throws {
        self.original = command
        self.executablePath = try Self.resolveExecutable(
            command.executableOverride ?? command.executableName,
            searchPaths: context.searchPaths
        )
        self.arguments = command.arguments
        self.environment = context.environment.merging(command.environmentOverrides) { _, new in new }
        self.workingDirectory = command.workingDirectoryOverride ?? context.workingDirectory
        self.timeout = command.timeoutOverride ?? context.defaultTimeout
        self.outputLimit = command.outputLimitOverride ?? context.defaultOutputLimit
        if let timeout, timeout < 0 || timeout.isFinite == false {
            throw ShellError.invalidConfiguration(description: "Timeout must be greater than or equal to zero seconds")
        }
        guard outputLimit >= 0 else {
            throw ShellError.invalidConfiguration(
                description: "Output limit must be greater than or equal to zero bytes"
            )
        }
        self.stdoutDestination = command.stdoutDestination
        self.stderrDestination = command.stderrDestination
        self.displayCommand = command.displayString(using: executablePath)
    }

    var configuration: Configuration {
        Configuration(
            .path(FilePath(executablePath)),
            arguments: Arguments(arguments),
            environment: .custom(Dictionary(uniqueKeysWithValues: environment.map { ($0.key.key, $0.value) })),
            workingDirectory: workingDirectory.map { FilePath($0) },
            platformOptions: subprocessPlatformOptions()
        )
    }

    private static func resolveExecutable(_ executable: String, searchPaths: [String]) throws -> String {
        if executable.contains("/") {
            guard FileManager.default.isExecutableFile(atPath: executable) else {
                throw ShellError.commandNotFound(executable)
            }
            return executable
        }

        for directory in searchPaths {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(executable).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw ShellError.commandNotFound(executable)
    }
}

private struct TimeoutExceeded: Error, Sendable {}

private struct CaptureLimitExceeded: Error, Sendable {}

private let partialOutputFlushGrace: Duration = .milliseconds(75)

private enum EarlyTerminationReason: Sendable {
    case outputLimitExceeded(command: String, limit: Int)
}

private actor ExecutionRegistry {
    private var executions: [Execution] = []
    private var shouldTeardown = false

    func register(_ execution: Execution) async {
        if shouldTeardown {
            await execution.swiftyShellTeardown()
        } else {
            executions.append(execution)
        }
    }

    func teardownAll() async {
        shouldTeardown = true
        let executions = executions
        await withTaskGroup(of: Void.self) { group in
            for execution in executions {
                group.addTask {
                    await execution.swiftyShellTeardown()
                }
            }
        }
    }
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
/// A lock serializes access so concurrent stream tasks can safely append data.
/// When the total captured byte count exceeds the limit, ``append(_:to:)`` throws
/// ``CaptureLimitExceeded`` after storing as many bytes as will fit.
private final class OutputCaptureStore: @unchecked Sendable {
    private let limit: Int
    private let lock = NSLock()
    private var capturedByteCount = 0
    private var stdout = Data()
    private var stderr = Data()

    init(limit: Int) {
        self.limit = limit
    }

    func append(_ data: Data, to stream: StreamKind) throws {
        lock.lock()
        defer { lock.unlock() }

        let remaining = limit - capturedByteCount
        guard remaining > 0 else {
            throw CaptureLimitExceeded()
        }

        if data.count > remaining {
            appendCaptured(data.prefix(remaining), to: stream)
            capturedByteCount += remaining
            throw CaptureLimitExceeded()
        }

        appendCaptured(data[...], to: stream)
        capturedByteCount += data.count
    }

    func snapshot() -> CaptureSnapshot {
        lock.lock()
        defer { lock.unlock() }

        return CaptureSnapshot(stdout: stdout, stderr: stderr)
    }

    private func appendCaptured(_ data: Data.SubSequence, to stream: StreamKind) {
        switch stream {
        case .stdout:
            stdout.append(contentsOf: data)
        case .stderr:
            stderr.append(contentsOf: data)
        }
    }
}

private struct SingleCommandRunner {
    let resolved: ResolvedCommand

    func run() async throws -> ShellOutput {
        let store = OutputCaptureStore(limit: resolved.outputLimit)
        let registry = ExecutionRegistry()
        let eventNotifier = RunEventNotifier<SingleCommandRunEvent>()
        let processTask = Task {
            do {
                let output = try await runSubprocess(store: store, registry: registry, eventNotifier: eventNotifier)
                await eventNotifier.notify(.completed(.success(output)))
                return output
            } catch {
                await eventNotifier.notify(.completed(.failure(errorDescription: String(describing: error))))
                throw error
            }
        }
        let timeoutTask = resolved.timeout.map { timeout in
            Task {
                try? await Task.sleep(for: durationFromSeconds(timeout))
                await eventNotifier.notify(.timedOut)
            }
        }
        defer { timeoutTask?.cancel() }

        do {
            return try await withTaskCancellationHandler {
                try await waitForSubprocess(
                    processTask: processTask,
                    store: store,
                    registry: registry,
                    eventNotifier: eventNotifier
                )
            } onCancel: {
                processTask.cancel()
                Task {
                    await eventNotifier.notify(.canceled)
                    await registry.teardownAll()
                }
            }
        } catch is CancellationError {
            processTask.cancel()
            await waitForPartialOutputFlush()
            let output = lossyOutput(snapshot: store.snapshot(), exitCode: -1)
            await registry.teardownAll()
            throw ShellError.canceled(command: resolved.displayCommand, partialOutput: output)
        }
    }

    private func runSubprocess(
        store: OutputCaptureStore,
        registry: ExecutionRegistry,
        eventNotifier: RunEventNotifier<SingleCommandRunEvent>
    ) async throws -> ShellOutput {
        let stdoutHandle = try openFileHandleIfNeeded(for: resolved.stdoutDestination)
        let stderrHandle = try openFileHandleIfNeeded(for: resolved.stderrDestination)
        defer {
            try? stdoutHandle?.close()
            try? stderrHandle?.close()
        }

        do {
            let outcome = try await Subprocess.run(
                resolved.configuration,
                preferredBufferSize: nil
            ) {
                execution,
                inputWriter,
                outputSequence,
                errorSequence in
                await registry.register(execution)
                try await runWithProcessGroupTeardownOnCancellation(execution: execution) {
                    try await inputWriter.finish()
                    try await withThrowingTaskGroup(of: SingleCommandTaskResult.self) { group in
                        group.addTask {
                            try await routeStream(
                                outputSequence,
                                stream: .stdout,
                                destination: resolved.stdoutDestination,
                                fileHandle: stdoutHandle,
                                store: store
                            )
                            return .streamComplete
                        }
                        group.addTask {
                            try await routeStream(
                                errorSequence,
                                stream: .stderr,
                                destination: resolved.stderrDestination,
                                fileHandle: stderrHandle,
                                store: store
                            )
                            return .streamComplete
                        }
                        if let timeout = resolved.timeout {
                            group.addTask {
                                do {
                                    try await Task.sleep(for: durationFromSeconds(timeout))
                                    return .timedOut
                                } catch {
                                    return .streamComplete
                                }
                            }
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
                                case .timedOut:
                                    await execution.swiftyShellTeardown()
                                    group.cancelAll()
                                    throw TimeoutExceeded()
                                }
                            }
                        } catch is CaptureLimitExceeded {
                            await eventNotifier.notify(
                                .earlyTerminated(
                                    .outputLimitExceeded(command: resolved.displayCommand, limit: resolved.outputLimit)
                                )
                            )
                            await execution.swiftyShellTeardown()
                            group.cancelAll()
                            throw CaptureLimitExceeded()
                        }
                    }
                }
            }

            let snapshot = store.snapshot()
            let output = try decodeOutput(
                command: resolved.displayCommand,
                snapshot: snapshot,
                exitCode: outcome.terminationStatus.swiftyShellExitCode
            )

            if Task.isCancelled {
                throw ShellError.canceled(command: resolved.displayCommand, partialOutput: output)
            }

            if !outcome.terminationStatus.isSuccess {
                throw ShellError.exitFailure(command: resolved.displayCommand, output: output)
            }

            return output
        } catch is TimeoutExceeded {
            let output = lossyOutput(snapshot: store.snapshot(), exitCode: -1)
            throw ShellError.timeout(
                command: resolved.displayCommand,
                duration: resolved.timeout ?? 0,
                partialOutput: output
            )
        } catch is CaptureLimitExceeded {
            let output = try decodeOutput(
                command: resolved.displayCommand,
                snapshot: store.snapshot(),
                exitCode: -1
            )
            throw ShellError.outputLimitExceeded(
                command: resolved.displayCommand,
                limit: resolved.outputLimit,
                partialOutput: output
            )
        } catch is CancellationError {
            let output = lossyOutput(snapshot: store.snapshot(), exitCode: -1)
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
        registry: ExecutionRegistry,
        eventNotifier: RunEventNotifier<SingleCommandRunEvent>
    ) async throws -> ShellOutput {
        switch await eventNotifier.wait() {
        case let .completed(.success(output)):
            return output
        case .completed(.failure):
            return try await processTask.value
        case .timedOut:
            processTask.cancel()
            await waitForPartialOutputFlush()
            let output = lossyOutput(snapshot: store.snapshot(), exitCode: -1)
            await registry.teardownAll()
            throw ShellError.timeout(
                command: resolved.displayCommand,
                duration: resolved.timeout ?? 0,
                partialOutput: output
            )
        case let .earlyTerminated(reason):
            processTask.cancel()
            switch reason {
            case let .outputLimitExceeded(command, limit):
                let output = try decodeOutput(
                    command: command,
                    snapshot: store.snapshot(),
                    exitCode: -1
                )
                await registry.teardownAll()
                throw ShellError.outputLimitExceeded(command: command, limit: limit, partialOutput: output)
            }
        case .canceled:
            processTask.cancel()
            await waitForPartialOutputFlush()
            let output = lossyOutput(snapshot: store.snapshot(), exitCode: -1)
            await registry.teardownAll()
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

private func runWithProcessGroupTeardownOnCancellation<Value: Sendable>(
    execution: Execution,
    operation: @escaping @Sendable () async throws -> Value
) async throws -> Value {
    try await withTaskCancellationHandler {
        try await operation()
    } onCancel: {
        Task {
            await execution.swiftyShellTeardown()
        }
    }
}

private extension Execution {
    /// Kills the subprocess immediately by sending SIGKILL.
    ///
    /// Sends the signal directly to the process (not the process group) to avoid the TOCTOU
    /// race on Linux where a recycled PGID could let the signal reach an unrelated process.
    /// Each spawned subprocess is its own process group leader
    /// (``subprocessPlatformOptions`` sets `processGroupID = 0`), so targeting the process
    /// directly is equivalent to targeting its group.
    ///
    /// No SIGTERM grace period is used. Partial output is captured in ``OutputCaptureStore``
    /// before teardown is triggered, so there is nothing to flush. A delayed SIGKILL from a
    /// grace period causes cross-test signal bleed on Linux: under `--no-parallel` the next
    /// test can spawn a subprocess that recycles the same PID within the grace window and
    /// then receives the stale SIGKILL.
    ///
    func swiftyShellTeardown() async {
        try? send(signal: .kill, toProcessGroup: false)
    }
}

private enum SingleCommandTaskResult: Sendable {
    case streamComplete
    case timedOut
}

private enum SpawnedCommandTaskResult: Sendable {
    case streamComplete
}

private struct SpawnedCommandRunner: Sendable {
    let resolved: ResolvedCommand
    let teardown: TeardownStrategy

    func spawn() async throws -> any SpawnedProcess {
        let stdoutStream = AsyncStream.makeStream(of: String.self)
        let stderrStream = AsyncStream.makeStream(of: String.self)
        let state = SubprocessSpawnedProcessState(teardown: teardown)
        let task = Task<ShellOutput, Never> {
            await runSpawnedProcess(
                state: state,
                stdoutContinuation: stdoutStream.continuation,
                stderrContinuation: stderrStream.continuation
            )
        }
        await state.attachTask(task)
        let execution = try await state.waitForExecution()
        return SubprocessSpawnedProcess(
            processIdentifier: Int32(execution.processIdentifier.value),
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

            let outcome = try await Subprocess.run(
                resolved.configuration,
                preferredBufferSize: nil
            ) { execution, inputWriter, outputSequence, errorSequence in
                await state.setExecution(execution)
                try await inputWriter.finish()
                try await withThrowingTaskGroup(of: SpawnedCommandTaskResult.self) { group in
                    group.addTask {
                        try await routeSpawnStream(
                            outputSequence,
                            stream: .stdout,
                            destination: resolved.stdoutDestination,
                            fileHandle: stdoutHandle,
                            store: store,
                            continuation: stdoutContinuation
                        )
                        return .streamComplete
                    }
                    group.addTask {
                        try await routeSpawnStream(
                            errorSequence,
                            stream: .stderr,
                            destination: resolved.stderrDestination,
                            fileHandle: stderrHandle,
                            store: store,
                            continuation: stderrContinuation
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
                        await execution.teardown(using: teardown.subprocessSteps)
                        group.cancelAll()
                        throw CaptureLimitExceeded()
                    }
                }
            }

            return lossyOutput(snapshot: store.snapshot(), exitCode: outcome.terminationStatus.swiftyShellExitCode)
        } catch is CaptureLimitExceeded {
            return lossyOutput(snapshot: store.snapshot(), exitCode: -1)
        } catch {
            await state.failStartupIfNeeded(error)
            return lossyOutput(snapshot: store.snapshot(), exitCode: -1)
        }
    }
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
    private var executionResult: Result<Execution, any Error>?
    private var executionContinuations: [CheckedContinuation<Result<Execution, any Error>, Never>] = []
    private var didTeardown = false

    init(teardown: TeardownStrategy) {
        self.teardown = teardown
    }

    func attachTask(_ task: Task<ShellOutput, Never>) {
        self.task = task
    }

    func setExecution(_ execution: Execution) {
        guard executionResult == nil else { return }
        executionResult = .success(execution)
        resumeExecutionContinuations(with: .success(execution))
    }

    func failStartupIfNeeded(_ error: any Error) {
        guard executionResult == nil else { return }
        executionResult = .failure(error)
        resumeExecutionContinuations(with: .failure(error))
    }

    func waitForExecution() async throws -> Execution {
        let result: Result<Execution, any Error>
        if let executionResult {
            result = executionResult
        } else {
            result = await withCheckedContinuation { continuation in
                executionContinuations.append(continuation)
            }
        }
        return try result.get()
    }

    private func resumeExecutionContinuations(with result: Result<Execution, any Error>) {
        let continuations = executionContinuations
        executionContinuations.removeAll(keepingCapacity: false)
        for continuation in continuations {
            continuation.resume(returning: result)
        }
    }

    func send(_ signal: ProcessSignal) async throws {
        let execution = try await waitForExecution()
        try execution.sendSwiftyShell(signal)
    }

    func teardownAndWait() async -> ShellOutput {
        if !didTeardown {
            didTeardown = true
            if let execution = try? await waitForExecution() {
                await execution.teardown(using: teardown.subprocessSteps)
            }
        }
        return await output()
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
    _ sequence: AsyncBufferSequence,
    stream: StreamKind,
    destination: OutputDestination,
    fileHandle: FileHandle?,
    store: OutputCaptureStore,
    continuation: AsyncStream<String>.Continuation
) async throws {
    for try await buffer in sequence {
        let data = buffer.withUnsafeBytes { Data($0) }
        if !data.isEmpty {
            continuation.yield(String(decoding: data, as: UTF8.self))
        }
        try routeData(data, stream: stream, destination: destination, fileHandle: fileHandle, store: store)
    }
}

/// Routes each buffer from an ``AsyncBufferSequence`` to the appropriate destination:
/// captured in memory, written to a file handle, or discarded.
private func routeStream(
    _ sequence: AsyncBufferSequence,
    stream: StreamKind,
    destination: OutputDestination,
    fileHandle: FileHandle?,
    store: OutputCaptureStore
) async throws {
    for try await buffer in sequence {
        let data = buffer.withUnsafeBytes { Data($0) }
        try routeData(data, stream: stream, destination: destination, fileHandle: fileHandle, store: store)
    }
}

private func routeFileDescriptor(
    _ fileDescriptor: FileDescriptor,
    stream: StreamKind,
    destination: OutputDestination,
    fileHandle: FileHandle?,
    store: OutputCaptureStore
) async throws {
    try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let fileDescriptor = fileDescriptor
            DispatchQueue.global(qos: .utility).async {
                do {
                    defer { try? fileDescriptor.close() }
                    var buffer = [UInt8](repeating: 0, count: 65_536)

                    while true {
                        let count = try buffer.withUnsafeMutableBytes { rawBuffer in
                            try fileDescriptor.read(into: rawBuffer)
                        }
                        if count == 0 {
                            continuation.resume()
                            return
                        }
                        try routeData(
                            Data(buffer.prefix(count)),
                            stream: stream,
                            destination: destination,
                            fileHandle: fileHandle,
                            store: store
                        )
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    } onCancel: {
        DispatchQueue.global(qos: .utility).async {
            try? fileDescriptor.close()
        }
    }
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
        let registry = ExecutionRegistry()
        let eventNotifier = RunEventNotifier<PipelineRunEvent>()
        let processTask = Task {
            do {
                let output = try await runPipelineProcess(
                    stageInputs: stageInputs,
                    stageOutputs: stageOutputs,
                    stores: stores,
                    registry: registry,
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
                try? await Task.sleep(for: durationFromSeconds(timeout))
                await eventNotifier.notify(.timedOut(duration: timeout))
            }
        }
        defer { timeoutTask?.cancel() }

        do {
            return try await withTaskCancellationHandler {
                try await waitForPipeline(
                    processTask: processTask,
                    stores: stores,
                    registry: registry,
                    eventNotifier: eventNotifier,
                    finalCommand: finalCommand
                )
            } onCancel: {
                processTask.cancel()
                Task {
                    await eventNotifier.notify(.canceled)
                    await registry.teardownAll()
                }
            }
        } catch is CancellationError {
            processTask.cancel()
            await waitForPartialOutputFlush()
            let snapshot = pipelineSnapshot(stores: stores)
            await registry.teardownAll()
            throw ShellError.canceled(
                command: finalCommand.displayCommand,
                partialOutput: lossyOutput(snapshot: snapshot, exitCode: -1)
            )
        }
    }

    private func runPipelineProcess(
        stageInputs: [FileDescriptor?],
        stageOutputs: [FileDescriptor?],
        stores: [OutputCaptureStore],
        registry: ExecutionRegistry,
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
                                    registry: registry,
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
                        // waitForPipeline cancels processTask and calls registry.teardownAll().
                        // Downstream stages that are SIGKILLed (exit 137) return a
                        // PipelineStageResult before the CancellationError propagates through
                        // the stage task. Checking Task.isCancelled here prevents those
                        // signal-induced exits from masking the ShellError.timeout that
                        // waitForPipeline already threw.
                        if stageResult.exitCode != 0, firstFailure == nil, !Task.isCancelled {
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
                        partialOutput: lossyOutput(snapshot: snapshot, exitCode: -1)
                    )
                }

                if let firstThrownFailure {
                    throw firstThrownFailure
                }

                let output = try decodeOutput(
                    command: finalCommand.displayCommand,
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
                            stdout: output.stdout,
                            stderr: output.stderr,
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
                partialOutput: lossyOutput(snapshot: snapshot, exitCode: -1)
            )
        }
    }

    private func waitForPipeline(
        processTask: Task<ShellOutput, any Error>,
        stores: [OutputCaptureStore],
        registry: ExecutionRegistry,
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
            await waitForPartialOutputFlush()
            let snapshot = pipelineSnapshot(stores: stores)
            await registry.teardownAll()
            throw ShellError.timeout(
                command: finalCommand.displayCommand,
                duration: duration,
                partialOutput: lossyOutput(snapshot: snapshot, exitCode: -1)
            )
        case let .earlyTerminated(reason):
            processTask.cancel()
            switch reason {
            case let .outputLimitExceeded(command, limit):
                let output = try decodeOutput(
                    command: command,
                    snapshot: pipelineSnapshot(stores: stores),
                    exitCode: -1
                )
                await registry.teardownAll()
                throw ShellError.outputLimitExceeded(command: command, limit: limit, partialOutput: output)
            }
        case .canceled:
            processTask.cancel()
            await waitForPartialOutputFlush()
            let snapshot = pipelineSnapshot(stores: stores)
            await registry.teardownAll()
            throw ShellError.canceled(
                command: finalCommand.displayCommand,
                partialOutput: lossyOutput(snapshot: snapshot, exitCode: -1)
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
    case timedOut(duration: TimeInterval)
    case earlyTerminated(EarlyTerminationReason)
    case canceled
}

private func waitForPartialOutputFlush() async {
    await Task.detached {
        try? await Task.sleep(for: partialOutputFlushGrace)
    }.value
}

private struct PipelinePipe: Sendable {
    let readEnd: FileDescriptor
    let writeEnd: FileDescriptor
}

private struct PipelineStageResult: Sendable {
    let index: Int
    let command: ResolvedCommand
    let exitCode: Int32
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
    registry: ExecutionRegistry,
    eventNotifier: RunEventNotifier<PipelineRunEvent>
) async throws -> PipelineStageResult {
    if let input {
        return try await runPipelineStageWithInput(
            index: index,
            command: command,
            input: FileDescriptorInput.fileDescriptor(input, closeAfterSpawningProcess: true),
            pipedOutput: pipedOutput,
            store: store,
            registry: registry,
            eventNotifier: eventNotifier
        )
    } else {
        return try await runPipelineStageWithInput(
            index: index,
            command: command,
            input: NoInput.none,
            pipedOutput: pipedOutput,
            store: store,
            registry: registry,
            eventNotifier: eventNotifier
        )
    }
}

private func runPipelineStageWithInput<Input: InputProtocol>(
    index: Int,
    command: ResolvedCommand,
    input: Input,
    pipedOutput: FileDescriptor?,
    store: OutputCaptureStore,
    registry: ExecutionRegistry,
    eventNotifier: RunEventNotifier<PipelineRunEvent>
) async throws -> PipelineStageResult {
    if let pipedOutput {
        return try await runPipelineStageWithPipedStdout(
            index: index,
            command: command,
            input: input,
            output: FileDescriptorOutput.fileDescriptor(pipedOutput, closeAfterSpawningProcess: true),
            store: store,
            registry: registry,
            eventNotifier: eventNotifier
        )
    }

    let stdoutHandle = try openFileHandleIfNeeded(for: command.stdoutDestination)
    defer { try? stdoutHandle?.close() }
    return try await runPipelineStageWithStreamedStdout(
        index: index,
        command: command,
        input: input,
        stdoutHandle: stdoutHandle,
        store: store,
        registry: registry,
        eventNotifier: eventNotifier
    )
}

private func runPipelineStageWithPipedStdout<Input: InputProtocol, Output: OutputProtocol>(
    index: Int,
    command: ResolvedCommand,
    input: Input,
    output: Output,
    store: OutputCaptureStore,
    registry: ExecutionRegistry,
    eventNotifier: RunEventNotifier<PipelineRunEvent>
) async throws -> PipelineStageResult where Output.OutputType == Void {
    let stderrPipe = try FileDescriptor.pipe()
    let stderrHandle = try openFileHandleIfNeeded(for: command.stderrDestination)
    defer {
        try? stderrHandle?.close()
    }

    let outcome = try await Subprocess.run(
        command.configuration,
        input: input,
        output: output,
        error: FileDescriptorOutput.fileDescriptor(stderrPipe.writeEnd, closeAfterSpawningProcess: true)
    ) { execution in
        await registry.register(execution)
        try await runWithProcessGroupTeardownOnCancellation(execution: execution) {
            do {
                try await routeFileDescriptor(
                    stderrPipe.readEnd,
                    stream: .stderr,
                    destination: command.stderrDestination,
                    fileHandle: stderrHandle,
                    store: store
                )
            } catch is CaptureLimitExceeded {
                await eventNotifier.notify(
                    .earlyTerminated(.outputLimitExceeded(command: command.displayCommand, limit: command.outputLimit))
                )
                await execution.swiftyShellTeardown()
                throw CaptureLimitExceeded()
            }
        }
    }

    return PipelineStageResult(
        index: index,
        command: command,
        exitCode: outcome.terminationStatus.swiftyShellExitCode
    )
}

private func runPipelineStageWithStreamedStdout<Input: InputProtocol>(
    index: Int,
    command: ResolvedCommand,
    input: Input,
    stdoutHandle: FileHandle?,
    store: OutputCaptureStore,
    registry: ExecutionRegistry,
    eventNotifier: RunEventNotifier<PipelineRunEvent>
) async throws -> PipelineStageResult {
    let stderrPipe = try FileDescriptor.pipe()
    let stderrHandle = try openFileHandleIfNeeded(for: command.stderrDestination)
    defer {
        try? stderrHandle?.close()
    }

    let outcome = try await Subprocess.run(
        command.configuration,
        input: input,
        error: FileDescriptorOutput.fileDescriptor(stderrPipe.writeEnd, closeAfterSpawningProcess: true),
        preferredBufferSize: nil
    ) { execution, outputSequence in
        await registry.register(execution)
        try await runWithProcessGroupTeardownOnCancellation(execution: execution) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await routeStream(
                        outputSequence,
                        stream: .stdout,
                        destination: command.stdoutDestination,
                        fileHandle: stdoutHandle,
                        store: store
                    )
                }
                group.addTask {
                    try await routeFileDescriptor(
                        stderrPipe.readEnd,
                        stream: .stderr,
                        destination: command.stderrDestination,
                        fileHandle: stderrHandle,
                        store: store
                    )
                }

                do {
                    try await group.waitForAll()
                } catch is CaptureLimitExceeded {
                    await eventNotifier.notify(
                        .earlyTerminated(
                            .outputLimitExceeded(command: command.displayCommand, limit: command.outputLimit)
                        )
                    )
                    await execution.swiftyShellTeardown()
                    group.cancelAll()
                    throw CaptureLimitExceeded()
                }
            }
        }
    }

    return PipelineStageResult(
        index: index,
        command: command,
        exitCode: outcome.terminationStatus.swiftyShellExitCode
    )
}

/// Converts a `TimeInterval` (seconds, `Double`) to a Swift `Duration`.
///
/// The public API uses `TimeInterval` for timeouts (``Command/timeout(_:)``,
/// ``ShellContext/defaultTimeout``). Internally we convert to `Duration` at the
/// boundary so all sleep calls use the modern `Task.sleep(for:)` API instead of
/// the nanosecond-based overload that requires manual overflow handling.
private func durationFromSeconds(_ seconds: TimeInterval) -> Duration {
    if seconds <= 0 { return .zero }
    let wholeSeconds = Int64(seconds)
    let fractionalNanoseconds = Int64((seconds - Double(wholeSeconds)) * 1_000_000_000)
    return .seconds(wholeSeconds) + .nanoseconds(fractionalNanoseconds)
}

private func subprocessPlatformOptions() -> PlatformOptions {
    var options = PlatformOptions()
    options.processGroupID = 0
    options.teardownSequence = []
    return options
}

private extension TeardownStrategy {
    var subprocessSteps: [TeardownStep] {
        steps.map { step in
            TeardownStep.send(signal: step.signal.subprocessSignal, allowedDurationToNextStep: step.gracePeriod)
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

private extension Execution {
    func sendSwiftyShell(_ signal: ProcessSignal) throws {
        try send(signal: signal.subprocessSignal, toProcessGroup: false)
    }
}

private func decodeOutput(command: String, snapshot: CaptureSnapshot, exitCode: Int32) throws -> ShellOutput {
    let stdout = try decodeStrict(snapshot.stdout, stream: .stdout, command: command)
    let stderr = try decodeStrict(snapshot.stderr, stream: .stderr, command: command)
    return ShellOutput(stdout: stdout, stderr: stderr, exitCode: exitCode)
}

private func lossyOutput(snapshot: CaptureSnapshot, exitCode: Int32) -> ShellOutput {
    ShellOutput(
        stdout: String(decoding: snapshot.stdout, as: UTF8.self),
        stderr: String(decoding: snapshot.stderr, as: UTF8.self),
        exitCode: exitCode
    )
}

private func decodeStrict(_ data: Data, stream: StreamKind, command: String) throws -> String {
    guard let string = String(data: data, encoding: .utf8) else {
        throw ShellError.decodingError(command: command, stream: stream)
    }
    return string
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
