import Foundation

/// A test double for ``SpawnedProcess`` returned by ``MockExecutor``.
public final class MockSpawnedProcess: SpawnedProcess {
    public let processIdentifier: Int32
    public let standardOutput: AsyncStream<String>
    public let standardError: AsyncStream<String>

    private let state: MockSpawnedProcessState

    /// Creates a mock spawned process with preset output.
    public init(
        processIdentifier: Int32 = 1,
        output: ShellOutput = ShellOutput(exitCode: 0)
    ) {
        self.processIdentifier = processIdentifier
        self.standardOutput = AsyncStream { continuation in
            if !output.stdout.isEmpty { continuation.yield(output.stdout) }
            continuation.finish()
        }
        self.standardError = AsyncStream { continuation in
            if !output.stderr.isEmpty { continuation.yield(output.stderr) }
            continuation.finish()
        }
        self.state = MockSpawnedProcessState(output: output)
    }

    /// Signals sent to this process, in order.
    public var signalHistory: [ProcessSignal] {
        get async { await state.signalHistory }
    }

    /// Whether ``teardownAndWait()`` has been called.
    public var didTeardown: Bool {
        get async { await state.didTeardown }
    }

    public func send(_ signal: ProcessSignal) async throws {
        await state.record(signal)
    }

    public func teardownAndWait() async -> ShellOutput {
        await state.teardownAndWait()
    }

    public func waitForExit() async -> ShellOutput {
        await state.waitForExit()
    }
}

private actor MockSpawnedProcessState {
    private let output: ShellOutput
    private(set) var signalHistory: [ProcessSignal] = []
    private(set) var didTeardown = false

    init(output: ShellOutput) {
        self.output = output
    }

    func record(_ signal: ProcessSignal) {
        signalHistory.append(signal)
    }

    func teardownAndWait() -> ShellOutput {
        didTeardown = true
        return output
    }

    func waitForExit() -> ShellOutput {
        output
    }
}
