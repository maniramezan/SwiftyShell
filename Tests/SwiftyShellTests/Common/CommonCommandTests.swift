import Foundation
import Testing
@testable import SwiftyShell

struct CommonCommandTests {
    @Test func buildsLsCommand() {
        let command = Ls()
            .all()
            .longFormat()
            .humanReadable()
            .recursive()
            .directoryAsFile()
            .path("/tmp")
            .command()

        #expect(command.executableName == "ls")
        #expect(command.arguments == ["-a", "-l", "-h", "-R", "-d", "/tmp"])
    }

    @Test func listsDirectoryContents() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("note.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        let output = try await Ls()
            .path(directory.path)
            .run()

        #expect(output.stdout.contains("note.txt"))
        #expect(output.exitCode == 0)
    }

    @Test func buildsCpCommand() {
        let command = Cp()
            .recursive()
            .force()
            .source("src")
            .destination("dst")
            .command()

        #expect(command.executableName == "cp")
        #expect(command.arguments == ["-R", "-f", "src", "dst"])
    }

    @Test func copiesFile() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source.txt")
        let destination = directory.appendingPathComponent("destination.txt")
        try "copy me".write(to: source, atomically: true, encoding: .utf8)

        let output = try await Cp()
            .source(source.path)
            .destination(destination.path)
            .run()

        let contents = try String(contentsOf: destination, encoding: .utf8)
        #expect(contents == "copy me")
        #expect(output.exitCode == 0)
    }

    @Test func buildsMvCommand() {
        let command = Mv()
            .force()
            .source("from")
            .destination("to")
            .command()

        #expect(command.executableName == "mv")
        #expect(command.arguments == ["-f", "from", "to"])
    }

    @Test func movesFile() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("before.txt")
        let destination = directory.appendingPathComponent("after.txt")
        try "rename me".write(to: source, atomically: true, encoding: .utf8)

        let output = try await Mv()
            .source(source.path)
            .destination(destination.path)
            .run()

        #expect(FileManager.default.fileExists(atPath: destination.path))
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(output.exitCode == 0)
    }

    @Test func buildsMkdirCommand() {
        let command = Mkdir()
            .parents()
            .mode("755")
            .directory("/tmp/example")
            .command()

        #expect(command.executableName == "mkdir")
        #expect(command.arguments == ["-p", "-m", "755", "/tmp/example"])
    }

    @Test func createsDirectories() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let nested = directory.appendingPathComponent("a/b/c", isDirectory: true)
        let output = try await Mkdir()
            .parents()
            .directory(nested.path)
            .run()

        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: nested.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        #expect(output.exitCode == 0)
    }

    @Test func buildsPwdCommand() {
        let command = Pwd()
            .physical()
            .command()

        #expect(command.executableName == "pwd")
        #expect(command.arguments == ["-P"])
    }

    @Test func printsWorkingDirectory() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let output = try await Pwd()
            .workingDirectory(directory.path)
            .run()

        let reportedPath = normalizePath(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
        let expectedPath = normalizePath(directory.path)

        #expect(reportedPath == expectedPath)
        #expect(output.exitCode == 0)
    }

    @Test func buildsRmCommand() {
        let command = Rm()
            .recursive()
            .force()
            .path("/tmp/example")
            .command()

        #expect(command.executableName == "rm")
        #expect(command.arguments == ["-r", "-f", "/tmp/example"])
    }

    @Test func removesDirectories() async throws {
        let directory = try makeTemporaryDirectory()
        let nested = directory.appendingPathComponent("inner", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "gone".write(to: nested.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let output = try await Rm()
            .recursive()
            .path(directory.path)
            .run()

        #expect(!FileManager.default.fileExists(atPath: directory.path))
        #expect(output.exitCode == 0)
    }

    @Test func buildsJqCommand() {
        let command = Jq(".name")
            .rawOutput()
            .compactOutput()
            .slurp()
            .nullInput()
            .sortKeys()
            .arg("kind", "demo")
            .file("input.json")
            .command()

        #expect(command.executableName == "jq")
        #expect(command.arguments == ["-r", "-c", "-s", "-n", "-S", "--arg", "kind", "demo", ".name", "input.json"])
    }

    @Test func transformsJsonWhenJqIsAvailable() async throws {
        guard (try? await Command("jq", "--version").run(in: ShellContext())) != nil else {
            return
        }

        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let input = directory.appendingPathComponent("input.json")
        try #"{"name":"SwiftyShell"}"#.write(to: input, atomically: true, encoding: .utf8)

        let output = try await Jq(".name")
            .rawOutput()
            .file(input.path)
            .run()

        #expect(output.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "SwiftyShell")
        #expect(output.exitCode == 0)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func normalizePath(_ path: String) -> String {
        if path.hasPrefix("/private/var/") {
            return String(path.dropFirst("/private".count))
        }
        return path
    }
}
