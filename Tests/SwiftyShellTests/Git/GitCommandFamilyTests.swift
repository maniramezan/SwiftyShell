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

    @Test func buildsSubmoduleAddCommand() {
        let command = Git()
            .submodule()
            .add("https://example.com/lib.git", path: "Vendor/Lib")
            .branch("main")
            .name("lib")
            .refFormat("reftable")
            .depth(1)
            .dissociate()
            .command()

        #expect(
            command.arguments == [
                "submodule",
                "add",
                "--branch",
                "main",
                "--name",
                "lib",
                "--dissociate",
                "--ref-format",
                "reftable",
                "--depth",
                "1",
                "--",
                "https://example.com/lib.git",
                "Vendor/Lib",
            ]
        )
    }

    @Test func buildsSubmoduleUpdateCommand() {
        let command = Git()
            .submodule()
            .update()
            .initializeOnUpdate()
            .recursive()
            .remote()
            .noFetch()
            .updateStrategy(.merge)
            .jobs(4)
            .singleBranch()
            .noRecommendShallow()
            .filter("blob:none")
            .path("Vendor/Lib")
            .command()

        #expect(
            command.arguments == [
                "submodule",
                "update",
                "--init",
                "--remote",
                "--no-fetch",
                "--merge",
                "--recursive",
                "--jobs",
                "4",
                "--single-branch",
                "--no-recommend-shallow",
                "--filter",
                "blob:none",
                "--",
                "Vendor/Lib",
            ]
        )
    }

    @Test func buildsSubmoduleSetBranchCommand() {
        let command = Git()
            .submodule()
            .setBranch("stable", path: "Vendor/Lib")
            .command()

        #expect(command.arguments == ["submodule", "set-branch", "--branch", "stable", "--", "Vendor/Lib"])
    }

    @Test func buildsSubmoduleResetBranchCommand() {
        let command = Git()
            .submodule()
            .resetBranch(path: "Vendor/Lib")
            .command()

        #expect(command.arguments == ["submodule", "set-branch", "--default", "--", "Vendor/Lib"])
    }

    @Test func buildsSubmoduleSetURLCommand() {
        let command = Git()
            .submodule()
            .setUrl(path: "Vendor/Lib", to: "https://example.com/new-lib.git")
            .command()

        #expect(
            command.arguments == [
                "submodule",
                "set-url",
                "--",
                "Vendor/Lib",
                "https://example.com/new-lib.git",
            ]
        )
    }

    @Test func buildsSubmoduleForeachCommand() {
        let command = Git()
            .submodule()
            .foreach("git status --short")
            .recursive()
            .command()

        #expect(command.arguments == ["submodule", "foreach", "--recursive", "git status --short"])
    }

    @Test func buildsSubmoduleDeinitializeAllCommand() {
        let command = Git()
            .submodule()
            .deinitialize()
            .force()
            .all()
            .command()

        #expect(command.arguments == ["submodule", "deinit", "--force", "--all"])
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

    @Test func parsesTypedSubmoduleStatusEntriesFromRepository() async throws {
        let parentURL = try makeTemporaryDirectoryForGitCommandTests()
        let childURL = try makeTemporaryDirectoryForGitCommandTests()
        defer { try? FileManager.default.removeItem(at: parentURL) }
        defer { try? FileManager.default.removeItem(at: childURL) }

        let context = ShellContext()
        try await initializeRepository(at: childURL, context: context)
        try await initializeRepository(at: parentURL, context: context)
        _ = try await Command("git", "submodule", "add", childURL.path, "Vendor/Child")
            .env("GIT_ALLOW_PROTOCOL", "file")
            .workingDirectory(parentURL.path)
            .run(in: context)

        let entries = try await Git(context: context)
            .workingDirectory(parentURL.path)
            .submodule()
            .statusEntries()
            .run()

        #expect(entries.count == 1)
        #expect(entries[0].state == .current)
        #expect(entries[0].path == "Vendor/Child")
        #expect(!entries[0].commitHash.isEmpty)
    }
}

private func makeTemporaryDirectoryForGitCommandTests() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func initializeRepository(at url: URL, context: ShellContext) async throws {
    _ = try await Command("git", "init", "-b", "main").workingDirectory(url.path).run(in: context)
    _ = try await Command("git", "config", "user.email", "test@test.com").workingDirectory(url.path).run(in: context)
    _ = try await Command("git", "config", "user.name", "Test User").workingDirectory(url.path).run(in: context)
    try "hello".write(to: url.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    _ = try await Command("git", "add", "README.md").workingDirectory(url.path).run(in: context)
    _ = try await Command("git", "commit", "-m", "initial commit").workingDirectory(url.path).run(in: context)
}
#endif
