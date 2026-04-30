#if Git
import Foundation
import Testing
@testable import SwiftyShell

struct GitTests {
    @Test func statusWorkflowMapProjectsBranch() async throws {
        let context = ShellContext(executor: MockExecutor(stdout: "# branch.head feature/demo\n"))

        let branch = try await Git(context: context)
            .status()
            .map(\.branch)
            .run()

        #expect(branch == "feature/demo")
    }

    @Test func statusWorkflowMapTransformsStatusSynchronously() async throws {
        let context = ShellContext(executor: MockExecutor(stdout: "# branch.head main\n? README.md\n"))

        let summary = try await Git(context: context)
            .status()
            .map { status in
                let branch = status.branch ?? "detached"
                return "\(branch):\(status.state == .dirty)"
            }
            .run()

        #expect(summary == "main:true")
    }

    @Test func statusWorkflowFetchPrefersOriginRemote() async throws {
        actor Recorder {
            var commands: [Command] = []

            func record(_ command: Command) {
                commands.append(command)
            }

            func snapshot() -> [Command] {
                commands
            }
        }

        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)

                switch command.arguments {
                case ["status", "--porcelain=v2", "--branch"]:
                    return ShellOutput(stdout: "# branch.head main\n", stderr: "", exitCode: 0)
                case ["remote"]:
                    return ShellOutput(stdout: "backup\norigin\n", stderr: "", exitCode: 0)
                case ["fetch", "origin"]:
                    return ShellOutput(stdout: "", stderr: "", exitCode: 0)
                default:
                    Issue.record("Unexpected command: \(command.displayString())")
                    return ShellOutput(stdout: "", stderr: "", exitCode: 0)
                }
            }
        )

        let result = try await Git(context: context)
            .status()
            .require(\.state, equals: .noChanges)
            .fetch()
            .run()

        #expect(result.remote == "origin")
        #expect(
            await recorder.snapshot().map(\.arguments) == [
                ["status", "--porcelain=v2", "--branch"],
                ["remote"],
                ["fetch", "origin"],
            ]
        )
    }

    @Test func statusWorkflowFetchFallsBackToFirstRemote() async throws {
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                switch command.arguments {
                case ["status", "--porcelain=v2", "--branch"]:
                    return ShellOutput(stdout: "# branch.head main\n", stderr: "", exitCode: 0)
                case ["remote"]:
                    return ShellOutput(stdout: "upstream\nbackup\n", stderr: "", exitCode: 0)
                case ["fetch", "upstream"]:
                    return ShellOutput(stdout: "", stderr: "", exitCode: 0)
                default:
                    Issue.record("Unexpected command: \(command.displayString())")
                    return ShellOutput(stdout: "", stderr: "", exitCode: 0)
                }
            }
        )

        let result = try await Git(context: context)
            .status()
            .fetch()
            .run()

        #expect(result.remote == "upstream")
    }

    @Test func statusWorkflowFetchFallsBackToOriginWhenNoRemoteExists() async throws {
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                switch command.arguments {
                case ["status", "--porcelain=v2", "--branch"]:
                    return ShellOutput(stdout: "# branch.head main\n", stderr: "", exitCode: 0)
                case ["remote"]:
                    return ShellOutput(stdout: "", stderr: "", exitCode: 0)
                case ["fetch", "origin"]:
                    return ShellOutput(stdout: "", stderr: "", exitCode: 0)
                default:
                    Issue.record("Unexpected command: \(command.displayString())")
                    return ShellOutput(stdout: "", stderr: "", exitCode: 0)
                }
            }
        )

        let result = try await Git(context: context)
            .status()
            .fetch()
            .run()

        #expect(result.remote == "origin")
    }

    @Test func statusWorkflowPullReturnsPostPullBranchState() async throws {
        actor Recorder {
            var commands: [Command] = []

            func record(_ command: Command) {
                commands.append(command)
            }

            func snapshot() -> [Command] {
                commands
            }
        }

        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, _ in
                await recorder.record(command)

                switch command.arguments {
                case ["status", "--porcelain=v2", "--branch"]:
                    let statusCalls = await recorder.snapshot().filter {
                        $0.arguments == ["status", "--porcelain=v2", "--branch"]
                    }.count
                    if statusCalls == 1 {
                        return ShellOutput(stdout: "# branch.head main\n", stderr: "", exitCode: 0)
                    }
                    return ShellOutput(
                        stdout: "# branch.head main\n# branch.upstream origin/main\n",
                        stderr: "",
                        exitCode: 0
                    )
                case ["pull"]:
                    return ShellOutput(stdout: "Already up to date.\n", stderr: "", exitCode: 0)
                default:
                    Issue.record("Unexpected command: \(command.displayString())")
                    return ShellOutput(stdout: "", stderr: "", exitCode: 0)
                }
            }
        )

        let result = try await Git(context: context)
            .status()
            .require(\.state, equals: .noChanges)
            .pull()
            .run()

        #expect(result.branch == "main")
        #expect(result.upstream == "origin/main")
        #expect(
            await recorder.snapshot().map(\.arguments) == [
                ["status", "--porcelain=v2", "--branch"],
                ["pull"],
                ["status", "--porcelain=v2", "--branch"],
            ]
        )
    }

    @Test func gitStatusDetectsDirtyRepo() async throws {
        let repoURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", arguments: "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        try "hello".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let status = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .status()
            .run()

        #expect(status.state == .dirty)
        #expect(status.branch == "main")
        #expect(status.hasUntrackedFiles)
    }

    @Test func gitRequireAcceptsCleanRepo() async throws {
        let repoURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", arguments: "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)

        let status = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .status()
            .require(\.state, equals: .noChanges)
            .run()

        #expect(status.state == .noChanges)
    }

    @Test func gitStatusDetectsStagedChanges() async throws {
        let repoURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", arguments: "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", arguments: "-C", repoURL.path, "config", "user.email", "test@test.com").run(
            in: context
        )
        _ = try await Command("git", arguments: "-C", repoURL.path, "config", "user.name", "Test").run(in: context)

        try "hello".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try await Command("git", arguments: "add", "README.md").workingDirectory(repoURL.path).run(in: context)

        let status = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .status()
            .run()

        #expect(status.state == .dirty)
        #expect(status.hasStagedChanges)
        #expect(!status.hasUnstagedChanges)
        #expect(!status.hasUntrackedFiles)
    }

    @Test func gitStatusDetectsUnstagedChanges() async throws {
        let repoURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", arguments: "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", arguments: "-C", repoURL.path, "config", "user.email", "test@test.com").run(
            in: context
        )
        _ = try await Command("git", arguments: "-C", repoURL.path, "config", "user.name", "Test").run(in: context)

        // Commit an initial file
        try "hello".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try await Command("git", arguments: "add", "README.md").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", arguments: "commit", "-m", "initial").workingDirectory(repoURL.path).run(
            in: context
        )

        // Modify without staging
        try "hello world".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let status = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .status()
            .run()

        #expect(status.state == .dirty)
        #expect(!status.hasStagedChanges)
        #expect(status.hasUnstagedChanges)
        #expect(!status.hasUntrackedFiles)
    }

    @Test func gitRequireFailsOnDirtyRepo() async throws {
        let repoURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", arguments: "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        try "hello".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        do {
            _ = try await Git(context: context)
                .workingDirectory(repoURL.path)
                .status()
                .require(\.state, equals: .noChanges)
                .run()
            Issue.record("Expected workflowConditionFailed")
        } catch let error as ShellError {
            guard case .workflowConditionFailed = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
    }

    @Test func gitStatusReportsBranchName() async throws {
        let repoURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", arguments: "init", "-b", "feature-branch").workingDirectory(repoURL.path).run(
            in: context
        )

        let status = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .status()
            .run()

        #expect(status.branch == "feature-branch")
    }
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
#endif
