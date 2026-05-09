#if Unzip
import Foundation
import Testing
@testable import SwiftyShell

actor CommandRecorder {
    private(set) var commands: [Command] = []

    func record(_ command: Command) {
        commands.append(command)
    }

    func first() -> Command? {
        commands.first
    }
}

struct UnzipCommandTests {
    let subject = Unzip()

    @Test func buildsDefaultUnzipCommand() {
        let command = subject.command()

        #expect(command.executableName == "unzip")
        #expect(command.arguments == [])
    }

    @Test func buildsUnzipCommandWithFlagsAndDestination() {
        let command =
            subject
            .archive("/tmp/in.zip")
            .overwrite()
            .quiet()
            .destination("/tmp/out")
            .command()

        #expect(command.executableName == "unzip")
        #expect(command.arguments == ["-o", "-q", "/tmp/in.zip", "-d", "/tmp/out"])
    }

    @Test func emitsPasswordBeforeArchive() {
        let command =
            subject
            .password("hunter2")
            .archive("/tmp/in.zip")
            .destination("/tmp/out")
            .command()

        #expect(command.arguments == ["-P", "hunter2", "/tmp/in.zip", "-d", "/tmp/out"])
    }

    @Test func emitsMembersBeforeExcludesAndDestination() {
        let command =
            subject
            .archive("/tmp/in.zip")
            .members(["docs/*.md", "README.md"])
            .excludes(["*.draft.md"])
            .destination("/tmp/out")
            .command()

        #expect(
            command.arguments == [
                "/tmp/in.zip",
                "docs/*.md", "README.md",
                "-x", "*.draft.md",
                "-d", "/tmp/out",
            ]
        )
    }

    @Test func listModeAddsListFlag() {
        let command = subject.list().archive("/tmp/in.zip").command()
        #expect(command.arguments == ["-l", "/tmp/in.zip"])
    }

    @Test func testModeAddsTestFlag() {
        let command = subject.test().archive("/tmp/in.zip").command()
        #expect(command.arguments == ["-t", "/tmp/in.zip"])
    }
}

struct UnzipEntryParserTests {
    @Test func parsesStandardListing() {
        let stdout = """
            Archive:  /tmp/test.zip
              Length      Date    Time    Name
            ---------  ---------- -----   ----
                   11  2026-05-09 10:30   foo.txt
                    5  2026-05-09 10:30   sub/bar.txt
            ---------                     -------
                   16                     2 files
            """

        let entries = UnzipEntryParser.parse(stdout)

        #expect(entries.count == 2)
        #expect(entries[0].path == "foo.txt")
        #expect(entries[0].size == 11)
        #expect(entries[1].path == "sub/bar.txt")
        #expect(entries[1].size == 5)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let expected = formatter.date(from: "2026-05-09 10:30")
        #expect(entries[0].modified == expected)
    }

    @Test func parsesPathsWithEmbeddedSpaces() {
        let stdout = """
              Length      Date    Time    Name
            ---------  ---------- -----   ----
                   42  2026-05-09 10:30   My Documents/notes.txt
            ---------                     -------
                   42                     1 file
            """

        let entries = UnzipEntryParser.parse(stdout)

        #expect(entries.count == 1)
        #expect(entries[0].path == "My Documents/notes.txt")
        #expect(entries[0].size == 42)
    }

    @Test func parsesLegacyDateFormat() {
        let stdout = """
              Length      Date    Time    Name
            ---------  ---------- -----   ----
                   11  05-09-2026 10:30   foo.txt
            ---------                     -------
                   11                     1 file
            """

        let entries = UnzipEntryParser.parse(stdout)

        #expect(entries.count == 1)
        #expect(entries[0].modified != nil)
    }

    @Test(arguments: [
        "",
        "totally unrelated text",
        "Archive: foo.zip\n  no separator here\n",
    ])
    func returnsEmptyForMalformedOutput(input: String) {
        #expect(UnzipEntryParser.parse(input) == [])
    }

    @Test func tolerantOfUnparseableEntryLines() {
        let stdout = """
              Length      Date    Time    Name
            ---------  ---------- -----   ----
                   11  2026-05-09 10:30   foo.txt
            this line is junk and should be skipped
                    5  2026-05-09 10:30   bar.txt
            ---------                     -------
            """

        let entries = UnzipEntryParser.parse(stdout)
        #expect(entries.map(\.path) == ["foo.txt", "bar.txt"])
    }
}

struct UnzipEntriesWorkflowTests {
    @Test func entriesWorkflowParsesMockExecutorStdout() async throws {
        let stdout = """
            Archive:  /tmp/test.zip
              Length      Date    Time    Name
            ---------  ---------- -----   ----
                   11  2026-05-09 10:30   foo.txt
            ---------                     -------
                   11                     1 file
            """

        let context = ShellContext(executor: MockExecutor(stdout: stdout))

        let entries = try await Unzip(context: context)
            .archive("/tmp/test.zip")
            .entries()
            .run()

        #expect(entries.count == 1)
        #expect(entries[0].path == "foo.txt")
        #expect(entries[0].size == 11)
    }

    @Test func entriesWorkflowForcesListModeAndCapturedStdout() async throws {
        let stdout = """
            Archive:  /tmp/test.zip
              Length      Date    Time    Name
            ---------  ---------- -----   ----
                    11  2026-05-09 10:30   foo.txt
            ---------                     -------
                    11                     1 file
            """

        let recorder = CommandRecorder()
        let executor = MockExecutor { command, _ in
            await recorder.record(command)
            return ShellOutput(stdout: stdout, stderr: "", exitCode: 0)
        }
        let context = ShellContext(executor: executor)

        let entries = try await Unzip(context: context)
            .archive("/tmp/test.zip")
            .printToStdout()
            .stdout(.discard)
            .destination("/tmp/out")
            .entries()
            .run()

        #expect(entries.map(\.path) == ["foo.txt"])

        let command = try #require(await recorder.first())
        #expect(command.arguments == ["-l", "/tmp/test.zip"])
        #expect(command.stdoutDestination == .capture)
    }
}

#endif
