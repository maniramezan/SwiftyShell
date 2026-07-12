import Foundation
import Testing
@testable import SwiftyShell

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private func waitForFile(at path: String) async throws {
    for _ in 0..<500 {
        if FileManager.default.fileExists(atPath: path) {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    Issue.record("Timed out waiting for marker file at \(path)")
}

private func waitForProcessExit(processIdentifier: Int32) async throws {
    for _ in 0..<500 {
        if !processIsRunning(processIdentifier) {
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for descendant process exit for pid \(processIdentifier)")
}

private func processIsRunning(_ processIdentifier: Int32) -> Bool {
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

struct CommandTests {
    @Test func shellPlatformCurrentProvidesDefaultSearchPaths() {
        #expect(ShellPlatform.current.defaultSearchPaths.isEmpty == false)
    }

    @Test func defaultSearchPathsUsePathEnvironmentWhenPresent() {
        let searchPaths = ShellContext.defaultSearchPaths(environment: ["PATH": "/opt/homebrew/bin:/usr/bin"])
        #expect(searchPaths == ["/opt/homebrew/bin", "/usr/bin"])
    }

    @Test func defaultSearchPathsFallbackToPlatformWhenPathMissing() {
        let searchPaths = ShellContext.defaultSearchPaths(environment: [:], platform: .linux)
        #expect(searchPaths == ["/usr/local/sbin", "/usr/local/bin", "/usr/sbin", "/usr/bin", "/sbin", "/bin"])
    }

    @Test func defaultSearchPathsFallbackToPlatformWhenPathEmpty() {
        let searchPaths = ShellContext.defaultSearchPaths(environment: ["PATH": ""], platform: .macOS)
        #expect(searchPaths == ["/usr/bin", "/bin", "/usr/sbin", "/sbin", "/usr/local/bin"])
    }

    @Test func runsSimpleCommand() async throws {
        let context = ShellContext()
        let output = try await Command("echo", arguments: "hello").run(in: context)
        #expect(output.stdout == "hello\n")
        #expect(output.stderr.isEmpty)
        #expect(output.exitCode == 0)
    }

    @Test func mockExecutorThrowsExitFailureForNonZeroStatus() async throws {
        let context = ShellContext(executor: MockExecutor(stdout: "out", stderr: "err", exitCode: 7))

        do {
            _ = try await Command("fake-tool", arguments: "arg").run(in: context)
            Issue.record("Expected exitFailure")
        } catch let error as ShellError {
            guard case let .exitFailure(command, output) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command == "fake-tool arg")
            #expect(output.stdout == "out")
            #expect(output.stderr == "err")
            #expect(output.exitCode == 7)
        }
    }

    @Test func mockExecutorRejectsNegativeContextTimeout() async throws {
        let context = ShellContext(executor: MockExecutor(), defaultTimeout: -1)

        do {
            _ = try await Command("fake-tool").run(in: context)
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description == "Timeout must be greater than or equal to zero seconds")
        }
    }

    @Test func exitFailurePreservesOutput() async throws {
        let context = ShellContext()

        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf 'out'; printf 'err' >&2; exit 7").run(in: context)
            Issue.record("Expected exitFailure")
        } catch let error as ShellError {
            guard case let .exitFailure(command, output) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command.contains("/bin/sh"))
            #expect(output.stdout == "out")
            #expect(output.stderr == "err")
            #expect(output.exitCode == 7)
        }
    }

    @Test func timeoutPreservesPartialOutput() async throws {
        let context = ShellContext(defaultTimeout: 5)
        let marker = "/tmp/swiftyshell-timeout-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: marker) }

        let task = Task {
            try await Command(
                "/bin/sh",
                arguments: "-c",
                "printf 'start'; touch '\(marker)'; exec sleep 30"
            ).run(in: context)
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

    @Test func outputLimitExceededPreservesPartialOutput() async throws {
        let context = ShellContext(defaultOutputLimit: 4)

        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf 'abcdef'").run(in: context)
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

    @Test func outputLimitTruncatingUTF8UsesLossyPartialDecoding() async throws {
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf '\\360\\237\\230\\200'")
                .outputLimit(2)
                .run()
            Issue.record("Expected outputLimitExceeded")
        } catch let error as ShellError {
            guard case let .outputLimitExceeded(_, limit, partialOutput) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(limit == 2)
            #expect(partialOutput.stdout == "\u{FFFD}")
        }
    }

    @Test func outputLimitExceededDoesNotHangOnLargeOutput() async throws {
        let context = ShellContext(defaultTimeout: 1.0, defaultOutputLimit: 4)

        do {
            _ = try await Command(
                "/bin/sh",
                arguments: "-c",
                "i=0; while [ $i -lt 20000 ]; do printf 'abcdefghij'; i=$((i + 1)); done"
            ).run(in: context)
            Issue.record("Expected outputLimitExceeded")
        } catch let error as ShellError {
            guard case let .outputLimitExceeded(command, limit, partialOutput) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command.contains("/bin/sh"))
            #expect(limit == 4)
            #expect(partialOutput.stdout == "abcd")
        }
    }

    @Test func negativeTimeoutIsRejected() async throws {
        do {
            _ = try await Command("echo", arguments: "hello")
                .timeout(-1)
                .run(in: ShellContext())
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description == "Timeout must be greater than or equal to zero seconds")
        }
    }

    @Test func negativeContextTimeoutIsRejected() async throws {
        do {
            _ = try await Command("echo", arguments: "hello").run(in: ShellContext(defaultTimeout: -1))
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description == "Timeout must be greater than or equal to zero seconds")
        }
    }

    @Test func nonFiniteTimeoutIsRejected() async throws {
        do {
            _ = try await Command("echo", arguments: "hello")
                .timeout(.infinity)
                .run(in: ShellContext())
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description == "Timeout must be greater than or equal to zero seconds")
        }
    }

    @Test func mockExecutorRejectsNonFiniteTimeout() async throws {
        do {
            _ = try await Command("fake-tool")
                .timeout(.nan)
                .run(in: ShellContext(executor: MockExecutor()))
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description == "Timeout must be greater than or equal to zero seconds")
        }
    }

    @Test func extremeFiniteTimeoutDoesNotTrap() async throws {
        let output = try await Command("echo", arguments: "hello")
            .timeout(.greatestFiniteMagnitude)
            .run()
        #expect(output.stdout == "hello\n")
    }

    @Test func timeoutKillsDescendantsAndReapsLeaderBeforeReturning() async throws {
        let childPIDPath = "/tmp/swiftyshell-descendant-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: childPIDPath) }

        do {
            _ = try await Command(
                "/bin/sh",
                arguments: "-c",
                "sleep 30 & child=$!; printf '%s' \"$child\" > '\(childPIDPath)'; wait"
            )
            .timeout(5)
            .run()
            Issue.record("Expected timeout")
        } catch let error as ShellError {
            guard case .timeout = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }

        let pidString = try String(contentsOfFile: childPIDPath, encoding: .utf8)
        let childPID = try #require(Int32(pidString))
        try await waitForProcessExit(processIdentifier: childPID)
    }

    @Test func negativeOutputLimitIsRejected() async throws {
        do {
            _ = try await Command("echo", arguments: "hello")
                .outputLimit(-1)
                .run(in: ShellContext())
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description == "Output limit must be zero (unlimited) or a positive byte count")
        }
    }

    @Test func negativeContextOutputLimitIsRejected() async throws {
        do {
            _ = try await Command("echo", arguments: "hello").run(in: ShellContext(defaultOutputLimit: -1))
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description == "Output limit must be zero (unlimited) or a positive byte count")
        }
    }

    @Test func decodingErrorIncludesCommandName() async throws {
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf '\\377'").run(in: ShellContext())
            Issue.record("Expected decodingError")
        } catch let error as ShellError {
            guard case let .decodingError(command, stream) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(command.contains("/bin/sh"))
            #expect(stream == .stdout)
        }
    }

    @Test func cancellationPreservesPartialOutput() async throws {
        let context = ShellContext()
        let marker = "/tmp/swiftyshell-cancel-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: marker) }
        let task = Task {
            try await Command(
                "/bin/sh",
                arguments: "-c",
                "printf 'start'; sleep 0.05; touch '\(marker)'; exec sleep 30"
            )
            .run(
                in: context
            )
        }

        try await waitForFile(at: marker)
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

    @Test func builderArgAndArgs() {
        let command = Command("git")
            .arg("commit")
            .args(["-m", "message"])
        #expect(command.executableName == "git")
        #expect(command.arguments == ["commit", "-m", "message"])
    }

    @Test func builderEnvSingleAndDict() {
        let command = Command("env")
            .env("FOO", "bar")
            .env(["BAZ": "qux"])
        #expect(command.environmentOverrides["FOO"] == "bar")
        #expect(command.environmentOverrides["BAZ"] == "qux")
    }

    @Test func builderEnvDictMergesWithLastValueWinning() {
        let command = Command("env")
            .env("KEY", "first")
            .env(["KEY": "second"])
        #expect(command.environmentOverrides["KEY"] == "second")
    }

    @Test func builderWorkingDirectory() {
        let command = Command("ls").workingDirectory("/tmp")
        #expect(command.workingDirectoryOverride == "/tmp")
    }

    @Test func builderTimeout() {
        let command = Command("sleep", arguments: "10").timeout(5.0)
        #expect(command.timeoutOverride == 5.0)
    }

    @Test func builderOutputLimit() {
        let command = Command("cat").outputLimit(1024)
        #expect(command.outputLimitOverride == 1024)
    }

    @Test func builderExecutableOverride() {
        let command = Command("git").executable("/usr/local/bin/git")
        #expect(command.executableOverride == "/usr/local/bin/git")
    }

    @Test func builderOutputDestinations() {
        let command = Command("ls")
            .stdout(.discard)
            .stderr(.file(path: "/tmp/err.log", append: true))
        #expect(command.stdoutDestination == .discard)
        #expect(command.stderrDestination == .file(path: "/tmp/err.log", append: true))
    }

    @Test func resolvesRelativeExecutableAndOutputAgainstWorkingDirectory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("swiftyshell-relative-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("tool.sh")
        try "#!/bin/sh\nprintf relative".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        _ = try await Command("tool")
            .executable("./tool.sh")
            .workingDirectory(directory.path)
            .stdout(.file(path: "output.txt", append: false))
            .run()

        let output = try String(contentsOf: directory.appendingPathComponent("output.txt"), encoding: .utf8)
        #expect(output == "relative")
    }

    @Test func rejectsStdoutAndStderrOverwritingSameFile() async throws {
        do {
            _ = try await Command("echo", arguments: "hello")
                .stdout(.file(path: "same.log", append: false))
                .stderr(.file(path: "./same.log", append: false))
                .run()
            Issue.record("Expected invalidConfiguration")
        } catch let error as ShellError {
            guard case let .invalidConfiguration(description) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(description.contains("stdout and stderr"))
        }
    }

    @Test func displayStringQuotesArgumentsWithSpaces() {
        let command = Command("echo", arguments: "hello world", "foo")
        #expect(command.displayString() == #"echo "hello world" foo"#)
    }

    @Test func displayStringUsesResolvedExecutable() {
        let command = Command("echo", arguments: "hi")
        #expect(command.displayString(using: "/bin/echo") == "/bin/echo hi")
    }

    @Test func commandNotFoundThrows() async throws {
        do {
            _ = try await Command("nonexistent_cmd_xyz_abc_123").run(in: ShellContext())
            Issue.record("Expected commandNotFound")
        } catch let error as ShellError {
            guard case .commandNotFound = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
    }

    @Test func discardStdoutProducesEmptyOutput() async throws {
        let output = try await Command("echo", arguments: "hello")
            .stdout(.discard)
            .run(in: ShellContext())
        #expect(output.stdout.isEmpty)
        #expect(output.exitCode == 0)
    }

    @Test func envOverrideIsPassedToSubprocess() async throws {
        let output = try await Command("/bin/sh", arguments: "-c", "echo $TEST_VAR_SWIFTYSHELL")
            .env("TEST_VAR_SWIFTYSHELL", "hello123")
            .run(in: ShellContext())
        #expect(output.stdout == "hello123\n")
    }

    @Test func perCommandTimeoutOverridesContext() async throws {
        let context = ShellContext(defaultTimeout: 10.0)
        let started = Date()
        do {
            _ = try await Command("/bin/sh", arguments: "-c", "printf 'hi'; exec sleep 30")
                .timeout(0.2)
                .run(in: context)
            Issue.record("Expected timeout")
        } catch let error as ShellError {
            guard case .timeout = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(Date().timeIntervalSince(started) < 3.0)
        }
    }
}
