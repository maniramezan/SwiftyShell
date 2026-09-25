import Foundation
import Testing

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct ProcessExitTimeout: Error {}

/// Returns whether `processIdentifier` names a live (non-zombie) process.
///
/// An orphaned descendant that has been killed stays a zombie until its new parent reaps it. In
/// containers whose PID 1 does not reap orphans (GitHub Actions' Linux job container, or
/// `docker run` without `--init`), that never happens, so `kill(pid, 0)` alone would keep reporting
/// it as alive.
func processIsRunning(_ processIdentifier: Int32) -> Bool {
    if kill(processIdentifier, 0) == -1, errno == ESRCH {
        return false
    }

    #if canImport(Glibc)
    if let stat = try? String(contentsOfFile: "/proc/\(processIdentifier)/stat", encoding: .utf8),
        let closeParen = stat.lastIndex(of: ")")
    {
        let remainder = stat[stat.index(after: closeParen)...].trimmingCharacters(in: .whitespacesAndNewlines)
        if remainder.first == "Z" {
            return false
        }
    }
    #endif

    return true
}

/// Polls until `processIdentifier` has exited (or become a zombie), recording an issue and throwing
/// ``ProcessExitTimeout`` if it is still running after `timeout`.
func waitForProcessExit(processIdentifier: Int32, timeout: Duration = .seconds(12)) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if !processIsRunning(processIdentifier) {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }

    Issue.record("Timed out waiting for process exit for pid \(processIdentifier)")
    throw ProcessExitTimeout()
}
