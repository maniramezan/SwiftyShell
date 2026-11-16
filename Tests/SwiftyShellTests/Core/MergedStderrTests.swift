import Foundation
import TestCommons
import Testing

@testable import SwiftyShell

struct MergedStderrTests {
    private let interleaved = Command(
        "/bin/sh",
        arguments: "-c",
        "echo one; echo two >&2; echo three; echo four >&2"
    )

    @Test func runInterleavesBothStreamsInArrivalOrder() async throws {
        let output = try await interleaved.mergingStderrIntoStdout().run()
        #expect(output.stdout == "one\ntwo\nthree\nfour\n")
        #expect(output.stderr.isEmpty)
    }

    @Test func withoutMergeStreamsStaySeparate() async throws {
        let output = try await interleaved.run()
        #expect(output.stdout == "one\nthree\n")
        #expect(output.stderr == "two\nfour\n")
    }

    @Test func mergedBytesRouteThroughStdoutDestination() async throws {
        let scratch = try TemporaryDirectory()
        defer { try? scratch.remove() }
        let path = scratch.url.appendingPathComponent("merged.log").path
        let output =
            try await interleaved
            .mergingStderrIntoStdout()
            .stdout(.log(path: path, append: false, tailBytes: 8))
            .run()
        let log = try String(contentsOfFile: path, encoding: .utf8)
        #expect(log == "one\ntwo\nthree\nfour\n")
        #expect(output.stdout == "ee\nfour\n")
        #expect(output.stderr.isEmpty)
    }

    @Test func mergedStdoutCanGoToAFile() async throws {
        let scratch = try TemporaryDirectory()
        defer { try? scratch.remove() }
        let path = scratch.url.appendingPathComponent("merged.txt").path
        _ = try await interleaved.mergingStderrIntoStdout().stdout(.file(path: path, append: false)).run()
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "one\ntwo\nthree\nfour\n")
    }

    @Test func mergedOutputCountsTowardOneLimit() async {
        await #expect {
            try await interleaved.mergingStderrIntoStdout().outputLimit(10).run()
        } throws: { error in
            guard case .outputLimitExceeded = error as? ShellError else { return false }
            return true
        }
    }

    @Test func stageStderrFlowsIntoNextStageWhenMerged() async throws {
        let pipeline = Command("/bin/sh", arguments: "-c", "echo out; echo err >&2")
            .mergingStderrIntoStdout()
            .pipe(to: Command("sort"))
        let output = try await pipeline.run()
        #expect(output.stdout == "err\nout\n")
        #expect(output.stderr.isEmpty)
    }

    @Test func spawnDeliversMergedBytesOnStdoutStream() async throws {
        let process = try await interleaved.mergingStderrIntoStdout().spawn(captureOutput: true)
        var text = ""
        for await chunk in process.standardOutput { text += chunk }
        var errorText = ""
        for await chunk in process.standardError { errorText += chunk }
        let output = await process.waitForExit()
        #expect(text == "one\ntwo\nthree\nfour\n")
        #expect(errorText.isEmpty)
        #expect(output.stdout == text)
    }

    @Test func separateStderrDestinationIsRejected() async {
        await #expect {
            try await interleaved.mergingStderrIntoStdout().stderr(.discard).run()
        } throws: { error in
            guard case .invalidConfiguration = error as? ShellError else { return false }
            return true
        }
    }

    @Test func detachedLaunchIsRejected() async {
        await #expect(throws: ShellError.self) {
            _ = try await Command("true").mergingStderrIntoStdout().spawnDetached()
        }
    }

    @Test func mockMergesStderrAfterStdout() async throws {
        let context = ShellContext(executor: MockExecutor(stdout: "a\n", stderr: "b\n"))
        let output = try await Command("tool").mergingStderrIntoStdout().run(in: context)
        #expect(output.stdout == "a\nb\n")
        #expect(output.stderr.isEmpty)

        await #expect(throws: ShellError.self) {
            try await Command("tool").mergingStderrIntoStdout().stderr(.discard).run(in: context)
        }
    }

    @Test func commandReportsMergeInDebugDescription() {
        let command = Command("tool").mergingStderrIntoStdout()
        #expect(command.mergesStderrIntoStdout)
        #expect(command.debugDescription.contains("mergesStderrIntoStdout: true"))
    }
}
