import Foundation

/// A handle to a process spawned without waiting for completion.
///
/// Use ``Command/spawn(in:teardown:)`` for long-running commands such as
/// servers, watchers, and recorders. Short-lived commands should continue to use
/// ``Command/run(in:)``.
///
/// > Important: Call ``teardownAndWait()`` or ``waitForExit()`` when you need
/// > deterministic shutdown and final output collection. Dropping the handle
/// > triggers best-effort teardown through the configured ``TeardownStrategy``,
/// > but that asynchronous cleanup is not a substitute for awaiting process
/// > completion in normal control flow.
public protocol SpawnedProcess: Sendable {
    /// The operating-system process identifier.
    var processIdentifier: Int32 { get }

    /// Real-time stdout chunks as UTF-8 text.
    ///
    /// Chunks have arbitrary sizes and are not split on line boundaries, but a chunk never ends
    /// inside a multi-byte UTF-8 character. The built-in executor keeps the 1,024 most recent unread
    /// chunks and drops older ones, so an unread stream cannot grow without limit.
    var standardOutput: AsyncStream<String> { get }

    /// Real-time stderr chunks as UTF-8 text.
    ///
    /// Chunking and buffering behave like ``standardOutput``.
    var standardError: AsyncStream<String> { get }

    /// Real-time stdout chunks as raw bytes, for binary output.
    ///
    /// Carries the same bytes as ``standardOutput`` without decoding them, with the same bounded
    /// buffering. Conformers that do not provide bytes inherit an empty stream.
    var standardOutputData: AsyncStream<Data> { get }

    /// Real-time stderr chunks as raw bytes.
    ///
    /// Behaves like ``standardOutputData``.
    var standardErrorData: AsyncStream<Data> { get }

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
    /// An empty byte stream, for conformers that only provide text streams.
    var standardOutputData: AsyncStream<Data> { AsyncStream { $0.finish() } }

    /// An empty byte stream, for conformers that only provide text streams.
    var standardErrorData: AsyncStream<Data> { AsyncStream { $0.finish() } }

    /// Sends ``ProcessSignal/interrupt``.
    func interrupt() async throws {
        try await send(.interrupt)
    }

    /// Sends ``ProcessSignal/terminate``.
    func terminate() async throws {
        try await send(.terminate)
    }
}
