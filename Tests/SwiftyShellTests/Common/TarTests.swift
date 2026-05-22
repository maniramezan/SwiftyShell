#if Tar
import Foundation
import Testing
@testable import SwiftyShell

struct TarCommandTests {
    let subject = Tar()

    @Test func buildsDefaultTarCommand() {
        let command = subject.command()

        #expect(command.executableName == "tar")
        #expect(command.arguments == [])
    }

    @Test func buildsCreateCommandWithCompressionFiltersAndPaths() {
        let command =
            subject
            .create()
            .verbose()
            .gzip()
            .exclude("*.tmp")
            .exclude("*/.build/*")
            .file("/tmp/source.tar.gz")
            .directory("/workspace")
            .path("Sources")
            .path("Package.swift")
            .command()

        #expect(command.executableName == "tar")
        #expect(
            command.arguments == [
                "-c", "-v", "-z",
                "--exclude", "*.tmp",
                "--exclude", "*/.build/*",
                "-f", "/tmp/source.tar.gz",
                "-C", "/workspace",
                "Sources", "Package.swift",
            ]
        )
    }

    @Test func latestOperationWins() {
        let command =
            subject
            .create()
            .extract()
            .file("archive.tar")
            .command()

        #expect(command.arguments == ["-x", "-f", "archive.tar"])
    }

    @Test(arguments: [
        (TarCompression.gzip, ["-z"]),
        (TarCompression.bzip2, ["-j"]),
        (TarCompression.xz, ["-J"]),
        (TarCompression.auto, ["-a"]),
        (TarCompression.custom("zstd -T0"), ["--use-compress-program", "zstd -T0"]),
    ])
    func compressionArgumentMapping(compression: TarCompression, expectedArguments: [String]) {
        #expect(subject.compression(compression).command().arguments == expectedArguments)
    }

    @Test func emitsInputFilesAndExtractionOptions() {
        let command =
            subject
            .extract()
            .file("archive.tar")
            .filesFrom("members.txt")
            .nullTerminatedFiles()
            .stripComponents(1)
            .toStdout()
            .preservePermissions()
            .noSameOwner()
            .keepOldFiles()
            .option("--warning=no-unknown-keyword")
            .path("Sources/SwiftyShell")
            .command()

        #expect(
            command.arguments == [
                "-x", "-p", "--no-same-owner", "-k", "-O", "--null",
                "-T", "members.txt",
                "--strip-components", "1",
                "--warning=no-unknown-keyword",
                "-f", "archive.tar",
                "Sources/SwiftyShell",
            ]
        )
    }

    @Test func preservesToolConfigurationOverrides() async throws {
        actor Recorder {
            var command: Command?
            var workingDirectory: String?

            func record(_ command: Command, context: ShellContext) {
                self.command = command
                self.workingDirectory = context.workingDirectory
            }
        }

        let recorder = Recorder()
        let context = ShellContext(
            executor: MockExecutor { command, context in
                await recorder.record(command, context: context)
                return ShellOutput(stdout: "ok\n", stderr: "", exitCode: 0)
            },
            workingDirectory: "/context"
        )

        let output = try await Tar(context: context)
            .executable("/usr/bin/tar")
            .workingDirectory("/override")
            .timeout(5)
            .outputLimit(1024)
            .create()
            .file("archive.tar")
            .path("file.txt")
            .run()

        let command = await recorder.command
        #expect(output.stdout == "ok\n")
        #expect(command?.executableName == "tar")
        #expect(command?.executableOverride == "/usr/bin/tar")
        #expect(command?.workingDirectoryOverride == "/override")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["-c", "-f", "archive.tar", "file.txt"])
        #expect(await recorder.workingDirectory == "/context")
    }

    @Test func createsAndExtractsArchiveOnDisk() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source", isDirectory: true)
        let destination = directory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let inputName = "hello.txt"
        let input = source.appendingPathComponent(inputName)
        try "hello world".write(to: input, atomically: true, encoding: .utf8)

        let archive = directory.appendingPathComponent("out.tar")
        let createOutput =
            try await subject
            .create()
            .file(archive.path)
            .directory(source.path)
            .path(inputName)
            .run()

        let extractOutput =
            try await subject
            .extract()
            .file(archive.path)
            .directory(destination.path)
            .run()

        let extracted = destination.appendingPathComponent(inputName)
        let extractedContents = try String(contentsOf: extracted, encoding: .utf8)

        #expect(createOutput.exitCode == 0)
        #expect(extractOutput.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: archive.path))
        #expect(extractedContents == "hello world")
    }

    @Test func listsArchiveEntriesOnDisk() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let inputName = "listed.txt"
        let input = directory.appendingPathComponent(inputName)
        try "listed".write(to: input, atomically: true, encoding: .utf8)

        let archive = directory.appendingPathComponent("out.tar")
        _ =
            try await subject
            .create()
            .file(archive.path)
            .directory(directory.path)
            .path(inputName)
            .run()

        let output =
            try await subject
            .list()
            .file(archive.path)
            .run()

        #expect(output.stdout.split(separator: "\n").contains(Substring(inputName)))
    }
}
#endif
