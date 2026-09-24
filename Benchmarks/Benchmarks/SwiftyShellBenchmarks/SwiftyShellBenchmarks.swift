import Benchmark
import Foundation
import SwiftyShell

/// Bytes each output-routing benchmark pushes through the executor.
private let payloadBytes = 64 * 1024 * 1024

/// A command that writes `payloadBytes` zero bytes to stdout.
private let producer = Command("head", arguments: "-c", "\(payloadBytes)", "/dev/zero")

nonisolated(unsafe) let benchmarks: @Sendable () -> Void = {
    let processConfiguration = Benchmark.Configuration(
        metrics: [.wallClock, .cpuTotal, .mallocCountTotal, .peakMemoryResident],
        warmupIterations: 2,
        maxDuration: .seconds(5),
        maxIterations: 50
    )

    // Per-process overhead: resolve, spawn, capture, and reap a command that does nothing.
    Benchmark("run/true", configuration: processConfiguration) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await Command("true").run())
        }
    }

    // Output routing throughput for 64 MiB through each OutputDestination.
    Benchmark("output/capture-64MiB", configuration: processConfiguration) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await producer.run())
        }
    }

    Benchmark("output/discard-64MiB", configuration: processConfiguration) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await producer.stdout(.discard).run())
        }
    }

    Benchmark("output/file-64MiB", configuration: processConfiguration) { benchmark in
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftyshell-benchmark-\(UUID().uuidString)").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        for _ in benchmark.scaledIterations {
            blackHole(try await producer.stdout(.file(path: path, append: false)).run())
        }
    }

    // Three processes connected by pipes, capturing only the final stage's small output.
    Benchmark("pipeline/3-stage-64MiB", configuration: processConfiguration) { benchmark in
        for _ in benchmark.scaledIterations {
            blackHole(try await producer.pipe(to: Command("cat")).pipe(to: Command("wc", arguments: "-c")).run())
        }
    }

    // Pure builder cost: no process is spawned.
    Benchmark(
        "builder/command-20-args",
        configuration: .init(metrics: [.wallClock, .mallocCountTotal], maxDuration: .seconds(2))
    ) { benchmark in
        for _ in benchmark.scaledIterations {
            var command = Command("tool")
            for index in 0..<20 {
                command = command.arg("--flag-\(index)")
            }
            blackHole(
                command
                    .env("CI", "1")
                    .workingDirectory("/tmp")
                    .outputLimit(1024)
                    .stdout(.discard)
                    .description
            )
        }
    }
}
