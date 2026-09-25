import Foundation
import Testing
@testable import SwiftyShell

/// Covers `.discard` and `.file`, which the built-in executor hands to the child process directly.
struct OutputRoutingTests {
    private func temporaryPath() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftyshell-routing-\(UUID().uuidString)").path
    }

    private func contents(of path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    @Test func fileDestinationReceivesLargeOutputIntact() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let output = try await Command("head", arguments: "-c", "8388608", "/dev/zero")
            .stdout(.file(path: path, append: false))
            .run()

        #expect(output.stdoutData.isEmpty)
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        #expect((attributes[.size] as? NSNumber)?.intValue == 8_388_608)
    }

    @Test func fileDestinationTruncatesExistingContents() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        try "previous contents that are longer".write(toFile: path, atomically: true, encoding: .utf8)

        _ = try await Command("printf", arguments: "new").stdout(.file(path: path, append: false)).run()

        #expect(try contents(of: path) == "new")
    }

    @Test func fileDestinationAppendsToExistingContents() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        try "first;".write(toFile: path, atomically: true, encoding: .utf8)

        _ = try await Command("printf", arguments: "second").stdout(.file(path: path, append: true)).run()

        #expect(try contents(of: path) == "first;second")
    }

    @Test func bothStreamsCanAppendToTheSameFile() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        _ = try await Command("/bin/sh", arguments: "-c", "printf out; printf err >&2; printf out")
            .stdout(.file(path: path, append: true))
            .stderr(.file(path: path, append: true))
            .run()

        // O_APPEND on both descriptors: every write lands at the end, nothing is overwritten.
        let text = try contents(of: path)
        #expect(text.count == 9)
        #expect(text.components(separatedBy: "out").count - 1 == 2)
        #expect(text.contains("err"))
    }

    @Test func relativeFileDestinationResolvesAgainstWorkingDirectory() async throws {
        let directory = temporaryPath()
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }

        _ = try await Command("printf", arguments: "hi")
            .workingDirectory(directory)
            .stdout(.file(path: "out.txt", append: false))
            .run()

        #expect(try contents(of: "\(directory)/out.txt") == "hi")
    }

    @Test func unwritableFileDestinationThrowsSpawnError() async throws {
        await #expect {
            try await Command("printf", arguments: "hi")
                .stdout(.file(path: "/nonexistent-directory/out.txt", append: false))
                .run()
        } throws: { error in
            guard case .spawnError = error as? ShellError else { return false }
            return true
        }
    }

    @Test func discardedStreamsReturnNothingAndDoNotCountTowardTheLimit() async throws {
        let output = try await Command("/bin/sh", arguments: "-c", "head -c 100000 /dev/zero; printf ok >&2")
            .stdout(.discard)
            .outputLimit(10)
            .run()

        #expect(output.stdoutData.isEmpty)
        #expect(output.stderr == "ok")
    }

    @Test func discardedStderrStillCapturesStdout() async throws {
        let output = try await Command("/bin/sh", arguments: "-c", "printf out; printf err >&2")
            .stderr(.discard)
            .run()

        #expect(output.stdout == "out")
        #expect(output.stderrData.isEmpty)
    }

    @Test func outputLimitOnCapturedStreamStopsProcessWhileOtherStreamGoesToFile() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        await #expect {
            try await Command("/bin/sh", arguments: "-c", "while :; do printf abcdefghij; done")
                .stderr(.file(path: path, append: false))
                .outputLimit(4)
                .timeout(.seconds(10))
                .run()
        } throws: { error in
            guard case let .outputLimitExceeded(_, limit, partialOutput) = error as? ShellError else { return false }
            return limit == 4 && partialOutput.stdout == "abcd"
        }
    }

    @Test func pipelineFinalStageCanWriteToFile() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let output = try await Command("printf", arguments: "alpha\nbeta\n")
            .pipe(to: Command("grep", arguments: "beta").stdout(.file(path: path, append: false)))
            .run()

        #expect(output.stdoutData.isEmpty)
        #expect(try contents(of: path) == "beta\n")
    }

    @Test func pipelineStageStderrCanBeDiscarded() async throws {
        let output = try await Command("/bin/sh", arguments: "-c", "printf noisy >&2; printf data")
            .stderr(.discard)
            .pipe(to: Command("cat"))
            .run()

        #expect(output.stdout == "data")
        #expect(output.stderrData.isEmpty)
    }

    @Test func captureOfManyChunksIsJoinedInOrder() async throws {
        let output = try await Command(
            "/bin/sh",
            arguments: "-c",
            "i=0; while [ $i -lt 5000 ]; do printf '%05d' $i; i=$((i + 1)); done"
        )
        .run()

        let expected = (0..<5000).map { String(format: "%05d", $0) }.joined()
        #expect(output.stdout == expected)
    }
}
