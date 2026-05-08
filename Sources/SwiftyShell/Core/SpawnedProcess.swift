import Foundation

/// A handle to a process spawned without waiting for completion.
///
/// Use ``Command/spawn(in:teardown:)`` for long-running commands such as
/// servers, watchers, and recorders. Short-lived commands should continue to use
/// ``Command/run(in:)``.
public protocol SpawnedProcess: Sendable {
    /// The operating-system process identifier.
    var processIdentifier: Int32 { get }

    /// Real-time stdout chunks as UTF-8 text.
    var standardOutput: AsyncStream<String> { get }

    /// Real-time stderr chunks as UTF-8 text.
    var standardError: AsyncStream<String> { get }

    /// Sends a signal to the running process.
    func send(_ signal: ProcessSignal) async throws

    /// Sends ``ProcessSignal/interrupt``.
    func interrupt() async throws

    /// Sends ``ProcessSignal/terminate``.
    func terminate() async throws

    /// Applies the configured ``TeardownStrategy`` and waits for exit.
    func teardownAndWait() async -> ShellOutput

    /// Waits for the process to exit naturally.
    func waitForExit() async -> ShellOutput
}

public extension SpawnedProcess {
    /// Sends ``ProcessSignal/interrupt``.
    func interrupt() async throws {
        try await send(.interrupt)
    }

    /// Sends ``ProcessSignal/terminate``.
    func terminate() async throws {
        try await send(.terminate)
    }
}
