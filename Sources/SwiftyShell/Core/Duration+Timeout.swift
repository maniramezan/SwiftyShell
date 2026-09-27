import Foundation

extension Duration {
    /// Converts a deprecated `TimeInterval` timeout into a `Duration` without trapping.
    ///
    /// `Duration.seconds(_:)` traps on NaN, infinity, and out-of-range values. Those inputs were
    /// previously rejected at execution time with ``ShellError/invalidConfiguration(description:)``,
    /// so non-finite values map to a negative duration that the executors still reject, and
    /// oversized values clamp to the largest representable duration.
    init(timeoutSeconds seconds: TimeInterval) {
        guard seconds.isFinite else {
            self = .seconds(-1)
            return
        }
        let maximumSeconds = Double(Int64.max) / 1_000_000_000
        if seconds >= maximumSeconds {
            self = .nanoseconds(Int64.max)
        } else if seconds <= -maximumSeconds {
            self = .nanoseconds(Int64.min)
        } else {
            self = .nanoseconds(Int64(seconds * 1_000_000_000))
        }
    }
}
