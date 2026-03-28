import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// The default executor that runs commands using `Process`.
public struct SubprocessExecutor: CommandExecutor {
    /// Creates a subprocess-backed command executor.
    public init() {}

    /// Executes a single command in the given shell context.
    public func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
        let resolved = try ResolvedCommand(command: command, context: context)
        return try await SingleCommandRunner(resolved: resolved).run()
    }

    /// Executes a pipeline in the given shell context.
    public func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput {
        let resolved = try pipeline.stages.map { try ResolvedCommand(command: $0, context: context) }
        return try await PipelineRunner(resolved: resolved).run()
    }
}

private struct ResolvedCommand {
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
        self.stdoutDestination = command.stdoutDestination
        self.stderrDestination = command.stderrDestination
        self.displayCommand = command.displayString(using: executablePath)
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

private struct CaptureResult: Sendable {
    let data: Data
    let overflowed: Bool

    static let empty = CaptureResult(data: Data(), overflowed: false)
}

private enum ExecutionOutcome {
    case completed(Int32)
    case timedOut
}

private final class ProcessBox: @unchecked Sendable {
    let process: Process

    init(_ process: Process) {
        self.process = process
    }
}

private final class FileHandleBox: @unchecked Sendable {
    let handle: FileHandle

    init(_ handle: FileHandle) {
        self.handle = handle
    }
}

// Registers `terminationHandler` on `process` before `process.run()` is called,
// eliminating the race where the process exits before the handler is set.
private final class ProcessExitWaiter: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: CheckedContinuation<Int32, Never>?
    private var exitCode: Int32?

    /// Must be called before `process.run()`.
    init(process: Process) {
        process.terminationHandler = { [weak self] p in
            guard let self else { return }
            let status = p.terminationStatus
            lock.lock()
            let cont = pending
            if cont == nil { exitCode = status }
            lock.unlock()
            cont?.resume(returning: status)
        }
    }

    func wait() async -> Int32 {
        await withCheckedContinuation { cont in
            lock.lock()
            if let code = exitCode {
                lock.unlock()
                cont.resume(returning: code)
            } else {
                pending = cont
                lock.unlock()
            }
        }
    }
}

private final class ProcessTerminator: @unchecked Sendable {
    private let lock = NSLock()
    private var processes: [Process] = []

    func register(_ process: Process) {
        lock.lock()
        processes.append(process)
        lock.unlock()
    }

    func terminateAll(except excluded: Process? = nil) {
        lock.lock()
        let processes = self.processes
        lock.unlock()

        for process in processes where process !== excluded {
            terminate(process)
        }
    }

    private func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()

        let box = ProcessBox(process)
        Task.detached {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if box.process.isRunning {
                _ = swiftyShellKill(box.process.processIdentifier, signal: SIGKILL)
            }
        }
    }
}

private struct SingleCommandRunner {
    let resolved: ResolvedCommand

    func run() async throws -> ShellOutput {
        let process = Process()
        let terminator = ProcessTerminator()
        terminator.register(process)

        process.executableURL = URL(fileURLWithPath: resolved.executablePath)
        process.arguments = resolved.arguments
        process.environment = resolved.environment
        if let workingDirectory = resolved.workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        }

        let nullInput = try makeReadNullHandle()
        defer { try? nullInput.close() }
        process.standardInput = nullInput

        let stdoutBinding = try StreamBinding.make(destination: resolved.stdoutDestination)
        let stderrBinding = try StreamBinding.make(destination: resolved.stderrDestination)
        defer {
            stdoutBinding.closeForParent()
            stderrBinding.closeForParent()
        }

        process.standardOutput = stdoutBinding.standardHandle
        process.standardError = stderrBinding.standardHandle

        // Register exit waiter BEFORE process.run() to avoid the race where the
        // process exits before terminationHandler is set.
        let exitWaiter = ProcessExitWaiter(process: process)

        do {
            try process.run()
        } catch {
            throw ShellError.spawnError(command: resolved.displayCommand, reason: String(describing: error))
        }

        stdoutBinding.closeWriteEndIfNeeded()
        stderrBinding.closeWriteEndIfNeeded()

        let stdoutTask = stdoutBinding.makeCaptureTask(limit: resolved.outputLimit)
        let stderrTask = stderrBinding.makeCaptureTask(limit: resolved.outputLimit)

        do {
            let outcome = try await awaitProcessExit(
                waiter: exitWaiter,
                timeout: resolved.timeout,
                terminator: terminator
            )
            let stdoutCapture = try await stdoutTask?.value ?? .empty
            let stderrCapture = try await stderrTask?.value ?? .empty
            let output = try decodeOutput(stdoutCapture: stdoutCapture, stderrCapture: stderrCapture, exitCode: process.terminationStatus)

            if stdoutCapture.overflowed || stderrCapture.overflowed {
                throw ShellError.outputLimitExceeded(
                    command: resolved.displayCommand,
                    limit: resolved.outputLimit,
                    partialOutput: output
                )
            }

            switch outcome {
            case let .completed(exitCode):
                if exitCode != 0 {
                    throw ShellError.exitFailure(command: resolved.displayCommand, output: output)
                }
                return output
            case .timedOut:
                throw ShellError.timeout(
                    command: resolved.displayCommand,
                    duration: resolved.timeout ?? 0,
                    partialOutput: output
                )
            }
        } catch is CancellationError {
            terminator.terminateAll()
            let stdoutCapture = (try? await stdoutTask?.value) ?? .empty
            let stderrCapture = (try? await stderrTask?.value) ?? .empty
            let output = lossyOutput(stdoutCapture: stdoutCapture, stderrCapture: stderrCapture, exitCode: process.terminationStatus)
            throw ShellError.cancelled(command: resolved.displayCommand, partialOutput: output)
        } catch let error as ShellError {
            throw error
        } catch {
            throw ShellError.spawnError(command: resolved.displayCommand, reason: String(describing: error))
        }
    }
}

private struct PipelineRunner {
    let resolved: [ResolvedCommand]

    func run() async throws -> ShellOutput {
        precondition(!resolved.isEmpty)

        let terminator = ProcessTerminator()
        var processes: [Process] = []
        var processBoxes: [ProcessBox] = []
        var exitWaiters: [ProcessExitWaiter] = []
        var retainedHandles: [FileHandle] = []
        var internalPipes: [Pipe] = []
        var stderrBindings: [StreamBinding] = []

        let finalCommand = resolved[resolved.count - 1]
        let finalStdoutBinding = try StreamBinding.make(destination: finalCommand.stdoutDestination)
        defer {
            finalStdoutBinding.closeForParent()
            stderrBindings.forEach { $0.closeForParent() }
            internalPipes.forEach {
                try? $0.fileHandleForReading.close()
                try? $0.fileHandleForWriting.close()
            }
            retainedHandles.forEach { try? $0.close() }
        }

        for (index, command) in resolved.enumerated() {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command.executablePath)
            process.arguments = command.arguments
            process.environment = command.environment
            if let workingDirectory = command.workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
            }

            if index == 0 {
                let nullInput = try makeReadNullHandle()
                retainedHandles.append(nullInput)
                process.standardInput = nullInput
            } else {
                process.standardInput = internalPipes[index - 1].fileHandleForReading
            }

            if index == resolved.count - 1 {
                process.standardOutput = finalStdoutBinding.standardHandle
            } else {
                let pipe = Pipe()
                internalPipes.append(pipe)
                process.standardOutput = pipe.fileHandleForWriting
            }

            let stderrBinding = try StreamBinding.make(destination: command.stderrDestination)
            stderrBindings.append(stderrBinding)
            process.standardError = stderrBinding.standardHandle

            // Register exit waiter BEFORE process.run() to avoid the race where
            // the process exits before terminationHandler is set.
            let exitWaiter = ProcessExitWaiter(process: process)

            do {
                try process.run()
            } catch {
                terminator.terminateAll()
                throw ShellError.spawnError(command: command.displayCommand, reason: String(describing: error))
            }

            terminator.register(process)
            processes.append(process)
            processBoxes.append(ProcessBox(process))
            exitWaiters.append(exitWaiter)
        }

        finalStdoutBinding.closeWriteEndIfNeeded()
        stderrBindings.forEach { $0.closeWriteEndIfNeeded() }
        internalPipes.forEach {
            try? $0.fileHandleForWriting.close()
        }

        let stdoutTask = finalStdoutBinding.makeCaptureTask(limit: finalCommand.outputLimit)
        let stderrTasks = zip(stderrBindings, resolved).map { binding, command in
            (binding.makeCaptureTask(limit: command.outputLimit), command)
        }

        do {
            let outcome = try await awaitPipelineExit(
                processes: processBoxes,
                exitWaiters: exitWaiters,
                commands: resolved,
                timeout: resolved.compactMap(\.timeout).min(),
                terminator: terminator
            )

            let stdoutCapture = try await stdoutTask?.value ?? .empty
            let stderrCaptures = try await stderrTasks.asyncMap { task, _ in
                try await task?.value ?? .empty
            }
            let stderrData = stderrCaptures.reduce(into: Data()) { partial, capture in
                partial.append(capture.data)
            }

            let output = try decodeOutput(
                stdoutCapture: stdoutCapture,
                stderrCapture: CaptureResult(data: stderrData, overflowed: stderrCaptures.contains(where: \.overflowed)),
                exitCode: processes.last?.terminationStatus ?? 0
            )

            if stdoutCapture.overflowed {
                throw ShellError.outputLimitExceeded(
                    command: finalCommand.displayCommand,
                    limit: finalCommand.outputLimit,
                    partialOutput: output
                )
            }

            for (capture, command) in zip(stderrCaptures, resolved) where capture.overflowed {
                throw ShellError.outputLimitExceeded(
                    command: command.displayCommand,
                    limit: command.outputLimit,
                    partialOutput: output
                )
            }

            switch outcome {
            case .completed:
                return output
            case let .failed(command, exitCode):
                throw ShellError.exitFailure(
                    command: command.displayCommand,
                    output: ShellOutput(stdout: output.stdout, stderr: output.stderr, exitCode: exitCode)
                )
            case .timedOut:
                throw ShellError.timeout(
                    command: finalCommand.displayCommand,
                    duration: resolved.compactMap(\.timeout).min() ?? 0,
                    partialOutput: output
                )
            }
        } catch is CancellationError {
            terminator.terminateAll()
            let stdoutCapture = (try? await stdoutTask?.value) ?? .empty
            let stderrCaptures = await stderrTasks.asyncMap { task, _ in
                (try? await task?.value) ?? .empty
            }
            let stderrData = stderrCaptures.reduce(into: Data()) { partial, capture in
                partial.append(capture.data)
            }
            let output = lossyOutput(
                stdoutCapture: stdoutCapture,
                stderrCapture: CaptureResult(data: stderrData, overflowed: stderrCaptures.contains(where: \.overflowed)),
                exitCode: processes.last?.terminationStatus ?? -1
            )
            throw ShellError.cancelled(command: finalCommand.displayCommand, partialOutput: output)
        } catch let error as ShellError {
            throw error
        } catch {
            throw ShellError.spawnError(command: finalCommand.displayCommand, reason: String(describing: error))
        }
    }
}

private enum PipelineOutcome {
    case completed
    case failed(command: ResolvedCommand, exitCode: Int32)
    case timedOut
}

private func awaitProcessExit(
    waiter: ProcessExitWaiter,
    timeout: TimeInterval?,
    terminator: ProcessTerminator
) async throws -> ExecutionOutcome {
    try await withTaskCancellationHandler {
        do {
            if let timeout {
                let outcome = try await withThrowingTaskGroup(of: ExecutionOutcome.self) { group in
                    group.addTask {
                        let exitCode = await waiter.wait()
                        return .completed(exitCode)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        terminator.terminateAll()
                        return .timedOut
                    }
                    let outcome = try await group.next() ?? .completed(0)
                    group.cancelAll()
                    return outcome
                }
                if Task.isCancelled {
                    throw CancellationError()
                }
                return outcome
            } else {
                let outcome = ExecutionOutcome.completed(await waiter.wait())
                if Task.isCancelled {
                    throw CancellationError()
                }
                return outcome
            }
        } catch is CancellationError {
            terminator.terminateAll()
            throw CancellationError()
        }
    } onCancel: {
        terminator.terminateAll()
    }
}

private func awaitPipelineExit(
    processes: [ProcessBox],
    exitWaiters: [ProcessExitWaiter],
    commands: [ResolvedCommand],
    timeout: TimeInterval?,
    terminator: ProcessTerminator
) async throws -> PipelineOutcome {
    try await withTaskCancellationHandler {
        do {
            if let timeout {
                let outcome = try await withThrowingTaskGroup(of: PipelineOutcome.self) { group in
                    group.addTask {
                        await waitForPipelineProcesses(
                            processes: processes,
                            exitWaiters: exitWaiters,
                            commands: commands,
                            terminator: terminator
                        )
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        terminator.terminateAll()
                        return .timedOut
                    }
                    let outcome = try await group.next() ?? .completed
                    group.cancelAll()
                    return outcome
                }
                if Task.isCancelled {
                    throw CancellationError()
                }
                return outcome
            } else {
                let outcome = await waitForPipelineProcesses(
                    processes: processes,
                    exitWaiters: exitWaiters,
                    commands: commands,
                    terminator: terminator
                )
                if Task.isCancelled {
                    throw CancellationError()
                }
                return outcome
            }
        } catch is CancellationError {
            terminator.terminateAll()
            throw CancellationError()
        }
    } onCancel: {
        terminator.terminateAll()
    }
}

private func waitForPipelineProcesses(
    processes: [ProcessBox],
    exitWaiters: [ProcessExitWaiter],
    commands: [ResolvedCommand],
    terminator: ProcessTerminator
) async -> PipelineOutcome {
    await withTaskGroup(of: (Int, Int32).self, returning: PipelineOutcome.self) { group in
        for (index, waiter) in exitWaiters.enumerated() {
            group.addTask {
                (index, await waiter.wait())
            }
        }

        var firstFailure: (Int, Int32)?
        while let result = await group.next() {
            if result.1 != 0, firstFailure == nil {
                firstFailure = result
                terminator.terminateAll(except: processes[result.0].process)
            }
        }

        if let firstFailure {
            return .failed(command: commands[firstFailure.0], exitCode: firstFailure.1)
        }
        return .completed
    }
}

private func decodeOutput(stdoutCapture: CaptureResult, stderrCapture: CaptureResult, exitCode: Int32) throws -> ShellOutput {
    let stdout = try decodeStrict(stdoutCapture.data, stream: .stdout, command: nil)
    let stderr = try decodeStrict(stderrCapture.data, stream: .stderr, command: nil)
    return ShellOutput(stdout: stdout, stderr: stderr, exitCode: exitCode)
}

private func lossyOutput(stdoutCapture: CaptureResult, stderrCapture: CaptureResult, exitCode: Int32) -> ShellOutput {
    ShellOutput(
        stdout: String(decoding: stdoutCapture.data, as: UTF8.self),
        stderr: String(decoding: stderrCapture.data, as: UTF8.self),
        exitCode: exitCode
    )
}

private func decodeStrict(_ data: Data, stream: StreamKind, command: String?) throws -> String {
    guard let string = String(data: data, encoding: .utf8) else {
        throw ShellError.decodingError(command: command ?? "<unknown>", stream: stream)
    }
    return string
}

private struct StreamBinding {
    let destination: OutputDestination
    let standardHandle: Any
    let capturePipe: Pipe?
    let fileHandle: FileHandle?

    static func make(destination: OutputDestination) throws -> StreamBinding {
        switch destination {
        case .capture:
            let pipe = Pipe()
            return StreamBinding(destination: destination, standardHandle: pipe, capturePipe: pipe, fileHandle: nil)
        case .discard:
            let handle = try makeWriteNullHandle()
            return StreamBinding(destination: destination, standardHandle: handle, capturePipe: nil, fileHandle: handle)
        case let .file(path, append):
            let handle = try makeFileHandle(path: path, append: append)
            return StreamBinding(destination: destination, standardHandle: handle, capturePipe: nil, fileHandle: handle)
        }
    }

    func makeCaptureTask(limit: Int) -> Task<CaptureResult, Error>? {
        guard let capturePipe else { return nil }
        let box = FileHandleBox(capturePipe.fileHandleForReading)
        return Task.detached {
            try readToEnd(handle: box.handle, limit: limit)
        }
    }

    func closeWriteEndIfNeeded() {
        guard case .capture = destination, let capturePipe else { return }
        try? capturePipe.fileHandleForWriting.close()
    }

    func closeForParent() {
        try? fileHandle?.close()
        try? capturePipe?.fileHandleForReading.close()
        try? capturePipe?.fileHandleForWriting.close()
    }
}

private func readToEnd(handle: FileHandle, limit: Int) throws -> CaptureResult {
    let chunkSize = 65_536
    var buffer = Data()
    var overflowed = false

    while true {
        let chunk = handle.readData(ofLength: chunkSize)
        if chunk.isEmpty { break }

        let remaining = limit - buffer.count
        if chunk.count >= remaining {
            buffer.append(chunk.prefix(remaining))
            overflowed = true
            break
        }
        buffer.append(chunk)
    }

    return CaptureResult(data: buffer, overflowed: overflowed)
}

private func makeReadNullHandle() throws -> FileHandle {
    guard let handle = FileHandle(forReadingAtPath: "/dev/null") else {
        throw ShellError.spawnError(command: "/dev/null", reason: "Unable to open null device for reading")
    }
    return handle
}

private func makeWriteNullHandle() throws -> FileHandle {
    guard let handle = FileHandle(forWritingAtPath: "/dev/null") else {
        throw ShellError.spawnError(command: "/dev/null", reason: "Unable to open null device for writing")
    }
    return handle
}

private func makeFileHandle(path: String, append: Bool) throws -> FileHandle {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path) {
        fileManager.createFile(atPath: path, contents: nil)
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

private func swiftyShellKill(_ pid: Int32, signal: Int32) -> Int32 {
    #if canImport(Darwin)
    return Darwin.kill(pid, signal)
    #elseif canImport(Glibc)
    return Glibc.kill(pid, signal)
    #else
    return -1
    #endif
}

private extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T
    ) async rethrows -> [T] {
        var results: [T] = []
        for element in self {
            results.append(try await transform(element))
        }
        return results
    }
}
