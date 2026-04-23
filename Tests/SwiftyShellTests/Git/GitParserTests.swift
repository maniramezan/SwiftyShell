import Testing
@testable import SwiftyShell

struct GitParserTests {
    @Test func parsesCleanRepo() throws {
        let output = """
            # branch.oid abc123
            # branch.head main
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.state == .noChanges)
        #expect(status.branch == "main")
        #expect(status.upstream == nil)
        #expect(!status.hasStagedChanges)
        #expect(!status.hasUnstagedChanges)
        #expect(!status.hasUntrackedFiles)
    }

    @Test func parsesDetachedHead() throws {
        let output = """
            # branch.oid abc123
            # branch.head (detached)
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.branch == nil)
        #expect(status.state == .noChanges)
    }

    @Test func parsesUpstreamTracking() throws {
        let output = """
            # branch.oid abc123
            # branch.head main
            # branch.upstream origin/main
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.upstream == "origin/main")
        #expect(status.branch == "main")
    }

    @Test func parsesUntrackedFiles() throws {
        let output = """
            # branch.head main
            ? new-file.txt
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.state == .dirty)
        #expect(status.hasUntrackedFiles)
        #expect(!status.hasStagedChanges)
        #expect(!status.hasUnstagedChanges)
    }

    @Test func parsesStagedChanges() throws {
        // XY field: X != "." means index (staged) change
        let output = """
            # branch.head main
            1 M. N... 100644 100644 100644 abc def file.txt
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.state == .dirty)
        #expect(status.hasStagedChanges)
        #expect(!status.hasUnstagedChanges)
    }

    @Test func parsesUnstagedChanges() throws {
        // XY field: Y != "." means worktree (unstaged) change
        let output = """
            # branch.head main
            1 .M N... 100644 100644 100644 abc def file.txt
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.state == .dirty)
        #expect(!status.hasStagedChanges)
        #expect(status.hasUnstagedChanges)
    }

    @Test func parsesBothStagedAndUnstagedChanges() throws {
        let output = """
            # branch.head main
            1 MM N... 100644 100644 100644 abc def file.txt
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.state == .dirty)
        #expect(status.hasStagedChanges)
        #expect(status.hasUnstagedChanges)
    }

    @Test func parsesRenamedEntry() throws {
        // Renamed files use "2" prefix
        let output = """
            # branch.head main
            2 R. N... 100644 100644 100644 abc def R100 newname.txt\toldname.txt
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.state == .dirty)
        #expect(status.hasStagedChanges)
        #expect(!status.hasUnstagedChanges)
    }

    @Test func parsesUnmergedEntry() throws {
        // Unmerged entries use "u" prefix; XY = "AA" means both sides added
        let output = """
            # branch.head main
            u AA N... 100644 100644 100644 100644 abc def ghi file.txt
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.state == .dirty)
        #expect(status.hasStagedChanges)
        #expect(status.hasUnstagedChanges)
    }

    @Test func parsesMultipleFiles() throws {
        let output = """
            # branch.head feature
            # branch.upstream origin/feature
            1 M. N... 100644 100644 100644 abc def staged.txt
            ? untracked.txt
            """
        let status = try GitParsers.parseStatus(output)
        #expect(status.state == .dirty)
        #expect(status.branch == "feature")
        #expect(status.upstream == "origin/feature")
        #expect(status.hasStagedChanges)
        #expect(!status.hasUnstagedChanges)
        #expect(status.hasUntrackedFiles)
    }

    @Test func parsesBranchEntries() {
        let output = """
            *	main	origin/main
             	feature/demo	origin/feature/demo
             	remotes/origin/main	
            """
        let entries = GitParsers.parseBranchEntries(output)

        #expect(
            entries == [
                GitBranchEntry(name: "main", isCurrent: true, upstream: "origin/main"),
                GitBranchEntry(name: "feature/demo", isCurrent: false, upstream: "origin/feature/demo"),
                GitBranchEntry(name: "remotes/origin/main", isCurrent: false, upstream: nil),
            ]
        )
    }

    @Test func parsesLogEntries() {
        let output = """
            abcdef1234567890\u{1F}abcdef1\u{1F}Test User\u{1F}test@example.com\u{1F}Initial commit
            fedcba0987654321\u{1F}fedcba0\u{1F}Other User\u{1F}other@example.com\u{1F}Follow-up change
            """
        let entries = GitParsers.parseLogEntries(output)

        #expect(
            entries == [
                GitLogEntry(
                    commitHash: "abcdef1234567890",
                    abbreviatedCommitHash: "abcdef1",
                    authorName: "Test User",
                    authorEmail: "test@example.com",
                    subject: "Initial commit"
                ),
                GitLogEntry(
                    commitHash: "fedcba0987654321",
                    abbreviatedCommitHash: "fedcba0",
                    authorName: "Other User",
                    authorEmail: "other@example.com",
                    subject: "Follow-up change"
                ),
            ]
        )
    }

    @Test func parsesDiffFileChanges() {
        let output = """
            M\tREADME.md
            A\tSources/NewFile.swift
            R100\tOld.swift\tNew.swift
            """
        let changes = GitParsers.parseDiffFileChanges(output)

        #expect(
            changes == [
                GitDiffFileChange(kind: .modified, path: "README.md", originalPath: nil, statusCode: "M"),
                GitDiffFileChange(
                    kind: .added,
                    path: "Sources/NewFile.swift",
                    originalPath: nil,
                    statusCode: "A"
                ),
                GitDiffFileChange(kind: .renamed, path: "New.swift", originalPath: "Old.swift", statusCode: "R100"),
            ]
        )
    }
}
