import Foundation
import Testing
@testable import SwiftyShell

struct BuildLogTests {
    private func temporaryPath() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("build-log-\(UUID().uuidString)").path
    }

    @Test func cancellationStopsDescendantsAndPreservesBothLogTails() async throws {
        let path = temporaryPath()
        let errPath = temporaryPath()
        let pidPath = temporaryPath()
        defer {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: errPath)
            try? FileManager.default.removeItem(atPath: pidPath)
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    _ = try await Command(
                        "/bin/sh",
                        arguments: "-c",
                        "sleep 30 & printf '%s' $! > '\(pidPath)'; printf build-ready; printf error-ready >&2; wait"
                    )
                    .stdout(.log(path: path, append: false, tailBytes: 5))
                    .stderr(.log(path: errPath, append: false, tailBytes: 5))
                    .run()
                    Issue.record("Expected cancellation")
                } catch let ShellError.canceled(_, partial) {
                    #expect(partial.stdout == "ready")
                    #expect(partial.stderr == "ready")
                }
            }
            let clock = ContinuousClock()
            let deadline = clock.now + .seconds(10)
            while (try? String(contentsOfFile: errPath, encoding: .utf8)) != "error-ready"
                || (try? String(contentsOfFile: path, encoding: .utf8)) != "build-ready"
            {
                guard clock.now < deadline else {
                    group.cancelAll()
                    Issue.record("Timed out waiting for process output")
                    throw ProcessExitTimeout()
                }
                try await Task.sleep(for: .milliseconds(10))
            }
            group.cancelAll()
            try await group.waitForAll()
        }
        let childPID = try #require(Int32(String(contentsOfFile: pidPath, encoding: .utf8)))
        try await waitForProcessExit(processIdentifier: childPID)
    }

    @Test func timeoutPreservesBothStreamsWithoutWaitingForDescendantPipes() async throws {
        let path = temporaryPath()
        let errPath = temporaryPath()
        defer {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: errPath)
        }
        do {
            _ = try await Command(
                "/bin/sh",
                arguments: "-c",
                "printf stdout-ready; printf stderr-ready >&2; sleep 30 & wait"
            )
            .stdout(.log(path: path, append: false, tailBytes: 5))
            .stderr(.log(path: errPath, append: false, tailBytes: 5))
            .timeout(.seconds(2)).run()
            Issue.record("Expected timeout")
        } catch let ShellError.timeout(_, _, partial) {
            #expect(partial.stdout == "ready")
            #expect(partial.stderr == "ready")
        }
    }

    @Test func logOpenFailureStopsAChattyProcess() async throws {
        await #expect {
            try await Command("/bin/sh", arguments: "-c", "while :; do printf out; printf err >&2; done")
                .stdout(.log(path: "/nonexistent-directory/build.log", append: false, tailBytes: 5))
                .timeout(.seconds(3)).run()
        } throws: { error in
            guard case .spawnError = error as? ShellError else { return false }
            return true
        }
    }

    @Test(arguments: [0, 3, 8192])
    func logRetainsBoundedTailAndWritesCompleteBytes(tailBytes: Int) async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let output = try await Command("/bin/sh", arguments: "-c", "head -c 262144 /dev/zero; printf END")
            .stdout(.log(path: path, append: false, tailBytes: tailBytes))
            .outputLimit(8192)
            .run()
        let log = try Data(contentsOf: URL(fileURLWithPath: path))
        #expect(log.count == 262147)
        #expect(output.stdoutData == Data(log.suffix(tailBytes)))
        #expect(output.exitCode == 0)
    }

    @Test func logAppendsAndResolvesRelativeToCommandDirectory() async throws {
        let directory = temporaryPath()
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/build.log"
        try Data("old;".utf8).write(to: URL(fileURLWithPath: path))
        let output = try await Command("printf", arguments: "new")
            .workingDirectory(directory)
            .stdout(.log(path: "build.log", append: true, tailBytes: 2))
            .run()
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "old;new")
        #expect(output.stdout == "ew")
    }

    @Test func pipelineLogsFinalStdoutAndEveryStderr() async throws {
        let path = temporaryPath()
        let errPath = temporaryPath()
        defer {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.removeItem(atPath: errPath)
        }
        let output = try await Command("/bin/sh", arguments: "-c", "printf abcdef; printf first >&2")
            .stderr(.log(path: errPath, append: true, tailBytes: 2))
            .pipe(
                to: Command("/bin/sh", arguments: "-c", "cat; printf second >&2")
                    .stdout(.log(path: path, append: false, tailBytes: 3))
                    .stderr(.log(path: errPath, append: true, tailBytes: 2))
            )
            .run()
        #expect(output.stdout == "def")
        #expect(output.stderr == "stnd")
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "abcdef")
        let errors = try String(contentsOfFile: errPath, encoding: .utf8)
        #expect(errors.contains("first"))
        #expect(errors.contains("second"))
    }

    @Test func failureCarriesLogTailAndExitStatus() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf build-failed >&2; exit 7")
                .stderr(.log(path: path, append: false, tailBytes: 6)).run()
            Issue.record("Expected exitFailure")
        } catch let ShellError.exitFailure(command, output) {
            #expect(command.executableName == "/bin/sh")
            #expect(output.exitCode == 7)
            #expect(output.stderr == "failed")
            #expect(try String(contentsOfFile: path, encoding: .utf8) == "build-failed")
        }
    }

    @Test(arguments: [false, true])
    func spawnPreservesFullLiveStreamWithOptionalTail(capture: Bool) async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let process = try await Command("printf", arguments: "abcdef")
            .stdout(.log(path: path, append: false, tailBytes: 3))
            .spawn(captureOutput: capture)
        var live = Data()
        for await chunk in process.standardOutputData { live.append(chunk) }
        let output = await process.waitForExit()
        #expect(live == Data("abcdef".utf8))
        #expect(output.stdout == (capture ? "def" : ""))
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "abcdef")
    }

    @Test(arguments: [false, true])
    func negativeTailIsRejectedBeforeExecution(mock: Bool) async throws {
        let executor: any CommandExecutor = mock ? MockExecutor() : SubprocessExecutor()
        await #expect(throws: ShellError.invalidConfiguration(description: "Log tail size must be nonnegative")) {
            try await Command("printf", arguments: "unused")
                .stdout(.log(path: "unused", append: false, tailBytes: -1))
                .run(in: ShellContext(executor: executor))
        }
    }

    @Test func logAndFileCannotTruncateTheSamePath() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        await #expect(
            throws: ShellError.invalidConfiguration(
                description: "stdout and stderr cannot overwrite the same file; use append mode for both streams"
            )
        ) {
            try await Command("printf", arguments: "unused")
                .stdout(.log(path: path, append: false, tailBytes: 4))
                .stderr(.file(path: path, append: true)).run()
        }
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test func logTailStillRespectsHardOutputLimit() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        do {
            _ = try await Command("printf", arguments: "abcdef")
                .stdout(.log(path: path, append: false, tailBytes: 6)).outputLimit(3).run()
            Issue.record("Expected outputLimitExceeded")
        } catch let ShellError.outputLimitExceeded(_, limit, partial) {
            #expect(limit == 3)
            #expect(partial.stdoutData.count == 3)
        }
    }

    @Test func mockPipelineFailureKeepsBothTailsAndCommandSnapshot() async throws {
        let mock = MockExecutor { command, _ in
            ShellOutput(stdout: "abcdef", stderr: "warning", exitCode: command.executableName == "last" ? 9 : 0)
        }
        let destination = OutputDestination.log(path: "unused", append: true, tailBytes: 3)
        do {
            _ = try await Command("first").stderr(destination)
                .pipe(to: Command("last").stdout(destination).stderr(destination))
                .run(in: ShellContext(executor: mock))
            Issue.record("Expected exitFailure")
        } catch let ShellError.exitFailure(command, output) {
            #expect(command.executableName == "last")
            #expect(output.stdout == "def")
            #expect(output.stderr == "inging")
            #expect(output.exitCode == 9)
        }
    }

    @Test func mockPreservesLiveBytesAndRetainsOnlyLogTail() async throws {
        let mock = MockExecutor(stdout: "abcdef", stderr: "warning")
        let command = Command("build").stdout(.log(path: "unused", append: false, tailBytes: 3))
        let context = ShellContext(executor: mock)
        #expect(try await command.run(in: context).stdout == "def")
        let process = try await command.spawn(captureOutput: true, in: context)
        var live = ""
        for await text in process.standardOutput { live += text }
        #expect(live == "abcdef")
        #expect(await process.waitForExit().stdout == "def")
        #expect(mock.recordedCommands.count == 2)
    }
}
