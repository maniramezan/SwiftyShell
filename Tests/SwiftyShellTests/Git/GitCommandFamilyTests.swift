#if Git
import Foundation
import Testing
@testable import SwiftyShell

struct GitCommandFamilyTests {
    @Test func buildsBranchListCommand() {
        let command = Git()
            .workingDirectory("/tmp/repo")
            .branch()
            .list()
            .all()
            .command()

        #expect(command.arguments == ["branch", "--list", "--all"])
        #expect(command.workingDirectoryOverride == "/tmp/repo")
    }

    @Test func buildsStashPushCommand() {
        let command = Git()
            .stash()
            .push()
            .includeUntracked()
            .message("checkpoint")
            .command()

        #expect(command.arguments == ["stash", "push", "--include-untracked", "-m", "checkpoint"])
    }

    @Test func buildsStashShowCommand() {
        let command = Git()
            .stash()
            .show()
            .reference("stash@{1}")
            .command()

        #expect(command.arguments == ["stash", "show", "stash@{1}"])
    }

    @Test func buildsStashDeleteAliasCommand() {
        let command = Git()
            .stash()
            .delete()
            .reference("stash@{0}")
            .command()

        #expect(command.arguments == ["stash", "drop", "stash@{0}"])
    }

    @Test func buildsStashBranchCommand() {
        let command = Git()
            .stash()
            .branch("recover-work")
            .reference("stash@{2}")
            .command()

        #expect(command.arguments == ["stash", "branch", "recover-work", "stash@{2}"])
    }

    @Test func buildsWorktreeAddCommand() {
        let command = Git()
            .worktree()
            .add("../feature-worktree")
            .branch("feature")
            .command()

        #expect(command.arguments == ["worktree", "add", "-b", "feature", "../feature-worktree"])
    }

    @Test func buildsDiffCommandWithFormatAndPaths() {
        let command = Git()
            .diff()
            .format(.nameStatus)
            .staged()
            .range("HEAD~1..HEAD")
            .path("README.md")
            .command()

        #expect(command.arguments == ["diff", "--name-status", "--staged", "HEAD~1..HEAD", "--", "README.md"])
    }

    @Test func buildsLogCommandWithFormatAndCount() {
        let command = Git()
            .log()
            .format(.oneline)
            .maxCount(5)
            .range("main..feature")
            .command()

        #expect(command.arguments == ["log", "--oneline", "-n", "5", "main..feature"])
    }

    @Test func buildsGitConfigCommandForListing() {
        let command = Git()
            .gitConfig()
            .global()
            .format(.showOrigin)
            .list()
            .command()

        #expect(command.arguments == ["config", "--global", "--show-origin", "--list"])
    }

    @Test func buildsMergeCommand() {
        let command = Git()
            .merge()
            .noFastForward()
            .branch("feature")
            .command()

        #expect(command.arguments == ["merge", "--no-ff", "feature"])
    }

    @Test func buildsCommitCommand() {
        let command = Git()
            .commit()
            .all()
            .message("Record update")
            .command()

        #expect(command.arguments == ["commit", "--all", "-m", "Record update"])
    }

    @Test func buildsRebaseCommand() {
        let command = Git()
            .rebase()
            .onto("main")
            .command()

        #expect(command.arguments == ["rebase", "main"])
    }

    @Test func readsGitConfigFromRepository() async throws {
        let repoURL = try makeTemporaryDirectoryForGitCommandTests()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        _ = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .gitConfig()
            .local()
            .set("user.name", to: "Swifty Shell")
            .run()

        let output = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .gitConfig()
            .local()
            .get("user.name")
            .run()

        #expect(
            output.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "Swifty Shell"
        )
    }

    @Test func readsGitLogWithOnelineFormat() async throws {
        let repoURL = try makeTemporaryDirectoryForGitCommandTests()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", "-C", repoURL.path, "config", "user.email", "test@test.com").run(in: context)
        _ = try await Command("git", "-C", repoURL.path, "config", "user.name", "Test").run(in: context)

        try "hello".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try await Command("git", "add", "README.md").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", "commit", "-m", "initial commit").workingDirectory(repoURL.path).run(in: context)

        let output = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .log()
            .format(.oneline)
            .maxCount(1)
            .run()

        #expect(output.stdout.contains("initial commit"))
    }

    @Test func parsesTypedBranchEntriesFromRepository() async throws {
        let repoURL = try makeTemporaryDirectoryForGitCommandTests()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", "-C", repoURL.path, "config", "user.email", "test@test.com").run(in: context)
        _ = try await Command("git", "-C", repoURL.path, "config", "user.name", "Test User").run(in: context)
        try "hello".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try await Command("git", "add", "README.md").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", "commit", "-m", "initial commit").workingDirectory(repoURL.path).run(in: context)

        let entries = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .branch()
            .entries()
            .run()

        #expect(entries.contains { $0.name == "main" && $0.isCurrent })
    }

    @Test func parsesTypedLogEntriesFromRepository() async throws {
        let repoURL = try makeTemporaryDirectoryForGitCommandTests()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", "-C", repoURL.path, "config", "user.email", "test@test.com").run(in: context)
        _ = try await Command("git", "-C", repoURL.path, "config", "user.name", "Test User").run(in: context)

        try "hello".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try await Command("git", "add", "README.md").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", "commit", "-m", "initial commit").workingDirectory(repoURL.path).run(in: context)

        let entries = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .log()
            .maxCount(1)
            .entries()
            .run()

        #expect(entries.count == 1)
        #expect(entries[0].authorName == "Test User")
        #expect(entries[0].subject == "initial commit")
    }

    @Test func parsesTypedDiffFileChangesFromRepository() async throws {
        let repoURL = try makeTemporaryDirectoryForGitCommandTests()
        defer { try? FileManager.default.removeItem(at: repoURL) }

        let context = ShellContext()
        _ = try await Command("git", "init", "-b", "main").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", "-C", repoURL.path, "config", "user.email", "test@test.com").run(in: context)
        _ = try await Command("git", "-C", repoURL.path, "config", "user.name", "Test User").run(in: context)

        try "hello".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try await Command("git", "add", "README.md").workingDirectory(repoURL.path).run(in: context)
        _ = try await Command("git", "commit", "-m", "initial commit").workingDirectory(repoURL.path).run(in: context)

        try "updated".write(to: repoURL.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)

        let changes = try await Git(context: context)
            .workingDirectory(repoURL.path)
            .diff()
            .fileChanges()
            .run()

        #expect(changes.contains { $0.path == "README.md" && $0.kind == .modified })
    }
}

private func makeTemporaryDirectoryForGitCommandTests() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
#endif
