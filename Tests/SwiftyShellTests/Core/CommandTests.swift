import Foundation
import Testing
@testable import SwiftyShell

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
        let output = try await Command("echo", "hello").run(in: context)
        #expect(output.stdout == "hello\n")
        #expect(output.stderr.isEmpty)
        #expect(output.exitCode == 0)
    }

    @Test func exitFailurePreservesOutput() async throws {
        let context = ShellContext()

        do {
            _ = try await Command("/bin/sh", "-c", "printf 'out'; printf 'err' >&2; exit 7").run(in: context)
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
        let context = ShellContext(defaultTimeout: 0.2)

        do {
            _ = try await Command("/bin/sh", "-c", "printf 'start'; sleep 2").run(in: context)
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
            _ = try await Command("/bin/sh", "-c", "printf 'abcdef'").run(in: context)
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

    @Test func cancellationPreservesPartialOutput() async throws {
        let context = ShellContext()
        let task = Task {
            try await Command("/bin/sh", "-c", "printf 'start'; sleep 2").run(in: context)
        }

        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch let error as ShellError {
            guard case let .cancelled(_, partialOutput) = error else {
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
        let command = Command("sleep", "10").timeout(5.0)
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

    @Test func displayStringQuotesArgumentsWithSpaces() {
        let command = Command("echo", "hello world", "foo")
        #expect(command.displayString() == #"echo "hello world" foo"#)
    }

    @Test func displayStringUsesResolvedExecutable() {
        let command = Command("echo", "hi")
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
        let output = try await Command("echo", "hello")
            .stdout(.discard)
            .run(in: ShellContext())
        #expect(output.stdout.isEmpty)
        #expect(output.exitCode == 0)
    }

    @Test func envOverrideIsPassedToSubprocess() async throws {
        let output = try await Command("/bin/sh", "-c", "echo $TEST_VAR_SWIFTYSHELL")
            .env("TEST_VAR_SWIFTYSHELL", "hello123")
            .run(in: ShellContext())
        #expect(output.stdout == "hello123\n")
    }

    @Test func perCommandTimeoutOverridesContext() async throws {
        let context = ShellContext(defaultTimeout: 10.0)
        do {
            _ = try await Command("/bin/sh", "-c", "printf 'hi'; sleep 2")
                .timeout(0.2)
                .run(in: context)
            Issue.record("Expected timeout")
        } catch let error as ShellError {
            guard case .timeout = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
    }
}
