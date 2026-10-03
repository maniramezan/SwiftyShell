import Foundation
import TestCommons
import Testing
@testable import SwiftyShell

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct DetachedProcessTests {
    @Test func customExecutorsMustOptIn() async {
        await #expect(throws: ShellError.self) {
            try await Command("tool").spawnDetached(in: ShellContext(executor: ManagedOnlyExecutor()))
        }
    }

    @Test func cancelledCallerDoesNotLaunch() async throws {
        let mock = MockExecutor()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await Command("tool").spawnDetached(in: ShellContext(executor: mock))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(mock.recordedCommands.isEmpty)
    }

    @Test func mockRecordsLaunchWithoutTreatingEventualExitAsStartupFailure() async throws {
        let mock = MockExecutor(exitCode: 42)
        let pid = try await Command("emulator", arguments: "-avd", "Pixel")
            .spawnDetached(in: ShellContext(executor: mock))
        #expect(pid == 1)
        #expect(mock.recordedCommands.count == 1)
        #expect(mock.recordedCommands[0].stdoutDestination == .discard)
        #expect(mock.recordedCommands[0].stderrDestination == .discard)
    }

    @Test func rejectsParentDependentConfigurationBeforeRecording() async throws {
        let mock = MockExecutor()
        let context = ShellContext(executor: mock)
        let commands = [
            Command("tool").timeout(.seconds(1)),
            Command("tool").outputLimit(1),
            Command("tool").outputLimit(-1),
            Command("tool").stdin(.string("input")),
            Command("tool").stdin(.data(Data())),
            Command("tool").stdout(.tee),
            Command("tool").stderr(.teeTo(.stderr)),
            Command("tool").stdout(.log(path: "/tmp/unused", append: true, tailBytes: 10)),
        ]
        for command in commands {
            await #expect(throws: ShellError.self) { try await command.spawnDetached(in: context) }
        }
        await #expect(throws: ShellError.self) {
            try await Command("tool").spawnDetached(in: ShellContext(executor: mock, defaultTimeout: .seconds(1)))
        }
        #expect(mock.recordedCommands.isEmpty)
    }

    /// Integration: the real child leads a new session and writes through direct file descriptors.
    @Test func newSessionHonorsFilesEnvironmentAndWorkingDirectory() async throws {
        let scratch = try TemporaryDirectory()
        defer { try? scratch.remove() }
        let directory = scratch.url
        _ = try scratch.write(Data("input\n".utf8), named: "input")
        let command = Command(
            "/bin/sh",
            arguments: "-c",
            "cat; printf '%s' \"$VALUE\"; printf error >&2; exec sleep 30"
        )
        .workingDirectory(directory.path)
        .env("VALUE", "two words")
        .stdin(.file(path: "input"))
        .stdout(.file(path: "log", append: true))
        .stderr(.file(path: "log", append: true))
        let pid = try await command.spawnDetached()
        defer { _ = kill(-pid, SIGKILL) }
        #expect(getpgid(pid) == pid)
        #expect(getsid(pid) == pid)
        let deadline = ContinuousClock.now + .seconds(5)
        var log = ""
        while ContinuousClock.now < deadline {
            log = (try? String(contentsOf: directory.appendingPathComponent("log"), encoding: .utf8)) ?? ""
            if log.contains("error") { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(log == "input\ntwo wordserror")
        _ = kill(-pid, SIGTERM)
        try await waitForProcessExit(processIdentifier: pid)
    }

    @Test func missingExecutableAndUnwritableRouteFailStartup() async throws {
        await #expect(throws: ShellError.commandNotFound("/swiftyshell-missing")) {
            try await Command("/swiftyshell-missing").spawnDetached()
        }
        do {
            _ = try await Command("/bin/sh").stdout(.file(path: "/swiftyshell-missing/log", append: false))
                .spawnDetached()
            Issue.record("Expected startup failure")
        } catch let ShellError.spawnError(command, _) {
            #expect(command.executableName == "/bin/sh")
        }
    }

    @Test func defaultDiscardAndNaturalExitAreReaped() async throws {
        let pid = try await Command("/bin/sh", arguments: "-c", "echo ignored; exit 42").spawnDetached()
        try await waitForProcessExit(processIdentifier: pid)
    }
}

private struct ManagedOnlyExecutor: CommandExecutor {
    func execute(_ command: Command, in context: ShellContext) async throws -> ShellOutput {
        ShellOutput(exitCode: 0)
    }

    func execute(_ pipeline: Pipeline, in context: ShellContext) async throws -> ShellOutput {
        ShellOutput(exitCode: 0)
    }

    func spawn(_ command: Command, in context: ShellContext, teardown: TeardownStrategy) async throws
        -> any SpawnedProcess
    {
        MockSpawnedProcess(output: ShellOutput(exitCode: 0))
    }
}
