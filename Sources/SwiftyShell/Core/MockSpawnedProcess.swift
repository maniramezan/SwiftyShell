/// A test double for ``SpawnedProcess`` returned by ``MockExecutor``.
///
/// `MockSpawnedProcess` wraps an actor for thread-safe state tracking while
/// remaining a value type. Use ``signalHistory`` and ``didTeardown`` to assert
/// that your code sends the expected signals and tears down the process.
///
/// ```swift
/// let context = ShellContext(executor: MockExecutor(stdout: "ready\n"))
/// let process = try await Command("server").spawn(in: context)
/// guard let mock = process as? MockSpawnedProcess else { return }
///
/// try await process.interrupt()
/// #expect(await mock.signalHistory == [.interrupt])
/// ```
public struct MockSpawnedProcess: SpawnedProcess, Sendable {
    public let processIdentifier: Int32
    public let standardOutput: AsyncStream<String>
    public let standardError: AsyncStream<String>

    private let state: MockSpawnedProcessState

    /// Creates a mock spawned process with preset output.
    ///
    /// - Parameters:
    ///   - processIdentifier: The fake PID to expose. Defaults to `1`.
    ///   - teardown: The ``TeardownStrategy`` passed to ``Command/spawn(in:teardown:)``.
    ///     Stored so tests can verify the strategy that was configured.
    ///   - output: The ``ShellOutput`` returned by ``waitForExit()`` and
    ///     ``teardownAndWait()``. Defaults to a zero-exit-code output.
    public init(
        processIdentifier: Int32 = 1,
        teardown: TeardownStrategy = .graceful,
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
        self.configuredTeardown = teardown
    }

    /// Signals sent to this process, in order.
    public var signalHistory: [ProcessSignal] {
        get async { await state.signalHistory }
    }

    /// Whether ``teardownAndWait()`` has been called.
    public var didTeardown: Bool {
        get async { await state.didTeardown }
    }

    /// The ``TeardownStrategy`` that was configured when the process was spawned.
    public let configuredTeardown: TeardownStrategy

    /// Sends a signal to this mock process, recording it in ``signalHistory``.
    public func send(_ signal: ProcessSignal) async throws {
        await state.record(signal)
    }

    /// Records teardown and returns the preset ``ShellOutput``.
    public func teardownAndWait() async -> ShellOutput {
        await state.teardownAndWait()
    }

    /// Returns the preset ``ShellOutput``.
    public func waitForExit() async -> ShellOutput {
        await state.waitForExit()
    }
}

private actor MockSpawnedProcessState {
    private let output: ShellOutput
    var signalHistory: [ProcessSignal] = []
    var didTeardown = false

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
