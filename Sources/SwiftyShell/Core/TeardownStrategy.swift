/// One graceful teardown step for a spawned process.
///
/// Each step sends a ``ProcessSignal`` and waits a grace period before the next
/// step runs. Use ``TeardownStrategy/init(steps:)`` to compose custom sequences.
///
/// ```swift
/// let step = ProcessTeardownStep(signal: .interrupt, gracePeriod: .seconds(3))
/// let strategy = TeardownStrategy(steps: [step])
/// ```
public struct ProcessTeardownStep: Sendable, Hashable {
    /// The signal sent at this step.
    public let signal: ProcessSignal

    /// How long to wait before moving to the next step.
    public let gracePeriod: Duration

    /// Creates a teardown step.
    public init(signal: ProcessSignal, gracePeriod: Duration) {
        self.signal = signal
        self.gracePeriod = gracePeriod
    }
}

/// Describes how SwiftyShell should stop a spawned process.
///
/// Strategies are used by ``SpawnedProcess/teardownAndWait()`` and by the
/// safety cleanup path when a spawned-process handle is released before the
/// process exits. The subprocess backend appends a final kill step after the
/// configured graceful steps, so every strategy eventually guarantees cleanup.
public struct TeardownStrategy: Sendable, Hashable {
    /// The graceful steps to run before the backend's final kill step.
    public let steps: [ProcessTeardownStep]

    /// Creates a custom teardown strategy.
    public init(steps: [ProcessTeardownStep]) {
        self.steps = steps
    }

    /// Sends `SIGTERM`, waits five seconds, then kills if still running.
    public static let graceful = TeardownStrategy(steps: [
        ProcessTeardownStep(signal: .terminate, gracePeriod: .seconds(5))
    ])

    /// Sends `SIGINT`, waits five seconds, sends `SIGTERM`, waits two seconds,
    /// then kills if still running.
    ///
    /// This is useful for tools such as video recorders that finalize output
    /// files on interrupt rather than terminate.
    public static let interruptThenTerminate = TeardownStrategy(steps: [
        ProcessTeardownStep(signal: .interrupt, gracePeriod: .seconds(5)),
        ProcessTeardownStep(signal: .terminate, gracePeriod: .seconds(2)),
    ])

    /// Kills the process immediately.
    public static let immediate = TeardownStrategy(steps: [])
}
