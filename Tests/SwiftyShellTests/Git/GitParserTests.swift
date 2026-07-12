#if Git
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

    @Test func parsesBranchEntries() throws {
        let output = """
            *	main	origin/main
             	feature/demo	origin/feature/demo
             	remotes/origin/main	
            """
        let entries = try GitParsers.parseBranchEntries(output)

        #expect(
            entries == [
                GitBranchEntry(name: "main", isCurrent: true, upstream: "origin/main"),
                GitBranchEntry(name: "feature/demo", isCurrent: false, upstream: "origin/feature/demo"),
                GitBranchEntry(name: "remotes/origin/main", isCurrent: false, upstream: nil),
            ]
        )
    }

    @Test func parsesLogEntries() throws {
        let output = """
            abcdef1234567890\u{1F}abcdef1\u{1F}Test User\u{1F}test@example.com\u{1F}Initial commit
            fedcba0987654321\u{1F}fedcba0\u{1F}Other User\u{1F}other@example.com\u{1F}Follow-up change
            """
        let entries = try GitParsers.parseLogEntries(output)

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

    @Test func parsesNULTerminatedDiffFileChanges() throws {
        let output =
            "M\0README.md\0A\0Sources/New\tFile.swift\0R100\0Old\nFile.swift\0New.swift\0C75\0Copy Source\0Copy Target\0"
        let changes = try GitParsers.parseDiffFileChanges(output)

        #expect(
            changes == [
                GitDiffFileChange(kind: .modified, path: "README.md", originalPath: nil, statusCode: "M"),
                GitDiffFileChange(
                    kind: .added,
                    path: "Sources/New\tFile.swift",
                    originalPath: nil,
                    statusCode: "A"
                ),
                GitDiffFileChange(
                    kind: .renamed,
                    path: "New.swift",
                    originalPath: "Old\nFile.swift",
                    statusCode: "R100"
                ),
                GitDiffFileChange(
                    kind: .copied,
                    path: "Copy Target",
                    originalPath: "Copy Source",
                    statusCode: "C75"
                ),
            ]
        )
    }

    @Test func parsesSubmoduleStatusEntries() throws {
        let output = """
             abcdef1234567890abcdef1234567890abcdef12 Vendor/Ready With Spaces (heads/main)
            -fedcba0987654321fedcba0987654321fedcba09 Vendor/Missing
            +1234567890abcdef1234567890abcdef12345678 Vendor/Changed (v1.2.3-4-g1234567)
            U0987654321fedcba0987654321fedcba09876543 Vendor/Conflicted
            """
        let entries = try GitParsers.parseSubmoduleStatusEntries(output)

        #expect(
            entries == [
                GitSubmoduleStatusEntry(
                    state: .current,
                    commitHash: "abcdef1234567890abcdef1234567890abcdef12",
                    path: "Vendor/Ready With Spaces",
                    description: "(heads/main)"
                ),
                GitSubmoduleStatusEntry(
                    state: .uninitialized,
                    commitHash: "fedcba0987654321fedcba0987654321fedcba09",
                    path: "Vendor/Missing",
                    description: nil
                ),
                GitSubmoduleStatusEntry(
                    state: .outOfSync,
                    commitHash: "1234567890abcdef1234567890abcdef12345678",
                    path: "Vendor/Changed",
                    description: "(v1.2.3-4-g1234567)"
                ),
                GitSubmoduleStatusEntry(
                    state: .mergeConflicted,
                    commitHash: "0987654321fedcba0987654321fedcba09876543",
                    path: "Vendor/Conflicted",
                    description: nil
                ),
            ]
        )
    }

    @Test(arguments: [
        "unexpected",
        "# branch.oid abc123",
        "# branch.head main\n1 X N... file",
        "# branch.head ",
    ]) func rejectsMalformedStatus(output: String) {
        #expect(throws: GitParsers.ParseError.self) {
            try GitParsers.parseStatus(output)
        }
    }

    @Test(arguments: ["*\tmain", "x\tmain\torigin/main", "\t\torigin/main"])
    func rejectsMalformedBranchEntry(output: String) {
        #expect(throws: GitParsers.ParseError.self) {
            try GitParsers.parseBranchEntries(output)
        }
    }

    @Test(arguments: ["hash\u{1F}short", "\u{1F}short\u{1F}name\u{1F}email\u{1F}subject"])
    func rejectsMalformedLogEntry(output: String) {
        #expect(throws: GitParsers.ParseError.self) {
            try GitParsers.parseLogEntries(output)
        }
    }

    @Test(arguments: ["M\0path", "M\0", "R100\0old\0", "\0"])
    func rejectsMalformedDiffEntry(output: String) {
        #expect(throws: GitParsers.ParseError.self) {
            try GitParsers.parseDiffFileChanges(output)
        }
    }

    @Test(arguments: ["+hash-only", " hash ", ""])
    func rejectsMalformedSubmoduleEntry(output: String) throws {
        if output.isEmpty {
            #expect(try GitParsers.parseSubmoduleStatusEntries(output).isEmpty)
        } else {
            #expect(throws: GitParsers.ParseError.self) {
                try GitParsers.parseSubmoduleStatusEntries(output)
            }
        }
    }
}
#endif
