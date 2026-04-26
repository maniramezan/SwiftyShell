#if Git
import Foundation
import Testing
@testable import SwiftyShell

struct GitTests {
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
