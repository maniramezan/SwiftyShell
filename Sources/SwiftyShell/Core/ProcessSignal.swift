/// A Unix process signal that can be sent to a spawned process.
///
/// `ProcessSignal` is used with ``SpawnedProcess/send(_:)`` and
/// ``TeardownStrategy``. SwiftyShell currently targets macOS and Linux, so this
/// type exposes Unix signal semantics.
public enum ProcessSignal: Int32, Sendable, Hashable {
    /// Interrupts a process (`SIGINT`).
    case interrupt = 2

    /// Requests graceful termination (`SIGTERM`).
    case terminate = 15

    /// Kills a process immediately (`SIGKILL`).
    case kill = 9

    /// Notifies a process that its terminal closed (`SIGHUP`).
    case hangup = 1

    /// Requests quit/core-dump behavior (`SIGQUIT`).
    case quit = 3
}
