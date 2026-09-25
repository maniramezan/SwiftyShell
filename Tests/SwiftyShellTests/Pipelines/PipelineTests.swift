import Foundation
import Testing
@testable import SwiftyShell

/// Polls for a marker file written by a test subprocess.
///
/// The deadline is generous because process startup can take seconds on loaded CI runners
/// (notably the coverage job); the wait returns as soon as the file appears.
private func waitForFile(at path: String, timeout: Duration = .seconds(10)) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if FileManager.default.fileExists(atPath: path) {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for marker file at \(path)")
}

private actor InvocationRecorder {
    private var invocations: [String] = []

    func record(_ executable: String) {
        invocations.append(executable)
    }

    func snapshot() -> [String] {
        invocations
    }
}

struct PipelineTests {
    @Test func pipelineDescriptionRendersShellStyleStages() {
        let pipeline = Command("printf", arguments: "alpha\nbeta\n")
            .pipe(to: Command("grep", arguments: "beta"))
            .pipe(to: Command("wc", arguments: "-l"))

        #expect(pipeline.description.contains("printf"))
        #expect(pipeline.description.contains("grep beta"))
        #expect(pipeline.description.contains("wc -l"))
        #expect(pipeline.description.contains(" | "))
    }

    @Test func pipelineDebugDescriptionIncludesStageDebugStrings() {
        let pipeline = Command("echo", arguments: "hello world")
            .pipe(to: Command("grep", arguments: "hello"))

        #expect(pipeline.debugDescription.contains("Pipeline("))
        #expect(pipeline.debugDescription.contains("Command("))
        #expect(pipeline.debugDescription.contains("hello world"))
        #expect(pipeline.debugDescription.contains("grep hello"))
    }

    @Test func mockPipelineStopsOnFirstFailure() async throws {
        let recorder = InvocationRecorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command.executableName)
                if command.executableName == "first" {
                    return ShellOutput(stdout: "", stderr: "boom", exitCode: 9)
                }
                return ShellOutput(stdout: command.executableName, stderr: "", exitCode: 0)
            }
        )

        do {
            _ = try await Command("first")
                .pipe(to: Command("second"))
                .run(in: context)
            Issue.record("Expected exitFailure")
        } catch let error as ShellError {
            guard case let .exitFailure(command, output) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command == "first")
            #expect(output.exitCode == 9)
            #expect(output.stderr == "boom")
            #expect(await recorder.snapshot() == ["first"])
        }
    }

    @Test func pipelineSucceeds() async throws {
        let output = try await Command("printf", arguments: "alpha\nbeta\n")
            .pipe(to: Command("grep", arguments: "beta"))
            .run(in: ShellContext())

        #expect(output.stdout == "beta\n")
    }

    @Test func pipelineCapturesStandardErrorFromEveryStage() async throws {
        let output = try await Command("/bin/sh", arguments: "-c", "printf 'first-err' >&2; printf 'data'")
            .pipe(to: Command("/bin/sh", arguments: "-c", "cat; printf 'second-err' >&2"))
            .run(in: ShellContext())

        #expect(output.stdout == "data")
        #expect(output.stderr.contains("first-err"))
        #expect(output.stderr.contains("second-err"))
    }

    @Test func pipelineToleratesUpstreamBrokenPipe() async throws {
        let output = try await Command("yes")
            .pipe(to: Command("head", arguments: "-n", "1"))
            .run(in: ShellContext())

        #expect(output.stdout == "y\n")
        #expect(output.exitCode == 0)
    }

    @Test func pipelineToleratesIntermediateStageKilledBySIGPIPE() async throws {
        let output = try await Command("/bin/sh", arguments: "-c", "printf 'data'; kill -PIPE $$")
            .pipe(to: Command("cat"))
            .run(in: ShellContext())

        #expect(output.stdout == "data")
    }

    @Test func pipelineFailsWhenFinalStageIsKilledBySIGPIPE() async throws {
        do {
            _ = try await Command("printf", arguments: "data")
                .pipe(to: Command("/bin/sh", arguments: "-c", "cat; kill -PIPE $$"))
                .run(in: ShellContext())
            Issue.record("Expected exitFailure")
        } catch let error as ShellError {
            guard case let .exitFailure(_, output) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(output.exitCode == 128 + SIGPIPE)
        }
    }

    @Test func pipelineFailsOnIntermediateStage() async throws {
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf 'broken' >&2; exit 9")
                .pipe(to: Command("cat"))
                .run(in: ShellContext())
            Issue.record("Expected exitFailure")
        } catch let error as ShellError {
            guard case let .exitFailure(command, output) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command.contains("/bin/sh"))
            #expect(output.stderr.contains("broken"))
            #expect(output.exitCode == 9)
        }
    }

    @Test func pipelineTimeoutPreservesPartialOutput() async throws {
        let marker = "/tmp/swiftyshell-pipeline-timeout-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: marker) }

        let task = Task {
            // The timeout clock starts when `run` is called, so it must cover process startup on a
            // slow runner; a 1-second timeout could fire before `start` was written.
            try await Command("/bin/sh", arguments: "-c", "printf 'start'; exec sleep 30")
                .timeout(.seconds(3))
                .pipe(
                    to: Command(
                        "/bin/sh",
                        arguments: "-c",
                        "chunk=$(dd bs=5 count=1 2>/dev/null); printf '%s' \"$chunk\"; touch '\(marker)'; exec sleep 30"
                    )
                )
                .run(in: ShellContext())
        }

        try await waitForFile(at: marker)

        do {
            _ = try await task.value
            Issue.record("Expected timeout")
        } catch let error as ShellError {
            guard case let .timeout(_, _, partialOutput) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(partialOutput.stdout == "start")
        }
    }

    @Test func pipelineCancellationPreservesPartialOutput() async throws {
        let marker = "/tmp/swiftyshell-pipeline-cancel-\(UUID().uuidString)"
        let outputMarker = "\(marker)-output"
        defer { try? FileManager.default.removeItem(atPath: marker) }
        defer { try? FileManager.default.removeItem(atPath: outputMarker) }
        let task = Task {
            try await Command("/bin/sh", arguments: "-c", "printf 'start'; exec sleep 30")
                .pipe(
                    to: Command(
                        "/bin/sh",
                        arguments: "-c",
                        "chunk=$(dd bs=5 count=1 2>/dev/null); printf '%s' \"$chunk\"; touch '\(outputMarker)'; touch '\(marker)'; exec sleep 30"
                    )
                )
                .run(in: ShellContext())
        }

        try await waitForFile(at: marker)
        try await waitForFile(at: outputMarker)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as ShellError {
            guard case let .canceled(_, partialOutput) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(partialOutput.stdout == "start")
        }
    }

    @Test func pipelineOutputLimitExceededPreservesPartialOutput() async throws {
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf 'abcdef'")
                .pipe(to: Command("cat"))
                .run(in: ShellContext(defaultOutputLimit: 4))
            Issue.record("Expected outputLimitExceeded")
        } catch let error as ShellError {
            guard case let .outputLimitExceeded(_, limit, partialOutput) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(limit == 4)
            #expect(partialOutput.stdout == "abcd")
        }
    }

    @Test func threeStagesPipeline() async throws {
        let output = try await Command("printf", arguments: "alpha\nbeta\ngamma\n")
            .pipe(to: Command("grep", arguments: "-v", "beta"))
            .pipe(to: Command("tr", arguments: "a-z", "A-Z"))
            .run(in: ShellContext())
        #expect(output.stdout == "ALPHA\nGAMMA\n")
    }

    @Test func pipelineExtensionOnPipelineType() async throws {
        let pipeline = Command("printf", arguments: "1\n2\n3\n")
            .pipe(to: Command("grep", arguments: "2"))
        let output =
            try await pipeline
            .pipe(to: Command("cat"))
            .run(in: ShellContext())
        #expect(output.stdout == "2\n")
    }
}
