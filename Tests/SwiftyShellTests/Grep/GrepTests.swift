#if Grep
import Foundation
import Testing
@testable import SwiftyShell

struct GrepTests {
    @Test func buildsLiteralCommand() {
        let command = Grep("beta")
            .ignoreCase()
            .lineNumbers()
            .file("/tmp/input.txt")
            .command()

        #expect(command.executableName == "grep")
        #expect(command.arguments == ["-i", "-n", "-F", "--", "beta", "/tmp/input.txt"])
    }

    @Test func runsLiteralMatchAgainstFile() async throws {
        let fileURL = try makeTemporaryFile(contents: "alpha\nbeta\ngamma\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let output = try await Grep("beta")
            .file(fileURL.path)
            .run()

        #expect(output.stdout == "beta\n")
        #expect(output.stderr.isEmpty)
        #expect(output.exitCode == 0)
    }

    @Test func buildsRecursiveCommand() {
        let command = Grep("TODO")
            .recursive()
            .file("/tmp/project")
            .command()

        #expect(command.executableName == "grep")
        #expect(command.arguments == ["-r", "-F", "--", "TODO", "/tmp/project"])
    }

    @Test func buildsCountCommand() {
        let command = Grep("error")
            .count()
            .file("/tmp/log.txt")
            .command()

        #expect(command.executableName == "grep")
        #expect(command.arguments == ["-c", "-F", "--", "error", "/tmp/log.txt"])
    }

    @Test func buildsCommandWithAllFlags() {
        let command = Grep("pattern")
            .ignoreCase()
            .invertMatch()
            .recursive()
            .lineNumbers()
            .count()
            .file("/tmp/dir")
            .command()

        #expect(command.arguments == ["-i", "-v", "-r", "-n", "-c", "-F", "--", "pattern", "/tmp/dir"])
    }

    @Test func runsCountAgainstFile() async throws {
        let fileURL = try makeTemporaryFile(contents: "alpha\nbeta\nalpha\ngamma\nalpha\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let output = try await Grep("alpha")
            .count()
            .file(fileURL.path)
            .run()

        #expect(output.stdout == "3\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsRecursiveSearch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let subdir = directory.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try "hello world".write(
            to: subdir.appendingPathComponent("file.txt"),
            atomically: true,
            encoding: .utf8
        )

        let output = try await Grep("hello")
            .recursive()
            .file(directory.path)
            .run()

        #expect(output.stdout.contains("hello world"))
        #expect(output.exitCode == 0)
    }

    @Test func runsInvertMatch() async throws {
        let fileURL = try makeTemporaryFile(contents: "alpha\nbeta\ngamma\n")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let output = try await Grep("beta")
            .invertMatch()
            .file(fileURL.path)
            .run()

        #expect(output.stdout == "alpha\ngamma\n")
        #expect(output.exitCode == 0)
    }

    @Test func runsRegexMatchInPipeline() async throws {
        let output = try await Command("printf", "alpha\nbeta42\ngamma\n")
            .pipe(to: Grep.regex(#"beta[0-9]+"#).command())
            .run(in: ShellContext())

        #expect(output.stdout == "beta42\n")
        #expect(output.stderr.isEmpty)
        #expect(output.exitCode == 0)
    }

    private func makeTemporaryFile(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("input.txt")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
#endif
