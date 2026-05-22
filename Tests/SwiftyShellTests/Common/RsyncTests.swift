#if Rsync
import Foundation
import Testing
@testable import SwiftyShell

struct RsyncCommandTests {
    let subject = Rsync()

    @Test func buildsDefaultRsyncCommand() {
        let command = subject.command()

        #expect(command.executableName == "rsync")
        #expect(command.arguments == [])
    }

    @Test func buildsArchiveSyncCommandWithFiltersAndOperands() {
        let command =
            subject
            .archive()
            .compress()
            .delete()
            .verbose()
            .humanReadable()
            .itemizeChanges()
            .exclude(".build")
            .include("*.swift")
            .filter("- *.tmp")
            .source("/workspace/")
            .destination("deploy@example.com:/srv/app/")
            .command()

        #expect(command.executableName == "rsync")
        #expect(
            command.arguments == [
                "-a", "-z", "-v", "--delete", "-i", "-h",
                "--exclude", ".build",
                "--include", "*.swift",
                "--filter", "- *.tmp",
                "/workspace/",
                "deploy@example.com:/srv/app/",
            ]
        )
    }

    @Test func emitsPreservationAndTransferRules() {
        let command =
            subject
            .recursive()
            .links()
            .permissions()
            .times()
            .owner()
            .group()
            .hardLinks()
            .sparse()
            .oneFileSystem()
            .checksum()
            .update()
            .existing()
            .ignoreExisting()
            .removeSourceFiles()
            .source("src/")
            .destination("dst/")
            .command()

        #expect(
            command.arguments == [
                "-r", "-c", "-u", "-l", "-p", "-t", "-o", "-g", "-H", "-S", "-x",
                "--existing", "--ignore-existing", "--remove-source-files",
                "src/", "dst/",
            ]
        )
    }

    @Test func emitsParameterizedOptionsBeforeRawOptionsAndOperands() {
        let command =
            subject
            .excludeFrom("exclude.txt")
            .includeFrom("include.txt")
            .filesFrom("files.txt")
            .from0()
            .remoteShell("ssh -i key.pem")
            .remoteRsyncPath("/opt/bin/rsync")
            .port(8730)
            .bandwidthLimit("2M")
            .maxSize("10M")
            .minSize("1K")
            .ioTimeout(30)
            .options(["--numeric-ids", "--safe-links"])
            .sources(["one", "two"])
            .destination("backup/")
            .command()

        #expect(
            command.arguments == [
                "--from0",
                "--exclude-from", "exclude.txt",
                "--include-from", "include.txt",
                "--files-from", "files.txt",
                "-e", "ssh -i key.pem",
                "--rsync-path", "/opt/bin/rsync",
                "--port", "8730",
                "--bwlimit", "2M",
                "--max-size", "10M",
                "--min-size", "1K",
                "--timeout", "30",
                "--numeric-ids", "--safe-links",
                "one", "two", "backup/",
            ]
        )
    }

    @Test func booleanFlagsCanBeDisabled() {
        let command =
            subject
            .archive()
            .archive(false)
            .delete()
            .delete(false)
            .source("src")
            .command()

        #expect(command.arguments == ["src"])
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

        let output = try await Rsync(context: context)
            .executable("/usr/bin/rsync")
            .workingDirectory("/override")
            .timeout(5)
            .outputLimit(1024)
            .archive()
            .source("src/")
            .destination("dst/")
            .run()

        let command = await recorder.command
        #expect(output.stdout == "ok\n")
        #expect(command?.executableName == "rsync")
        #expect(command?.executableOverride == "/usr/bin/rsync")
        #expect(command?.workingDirectoryOverride == "/override")
        #expect(command?.timeoutOverride == 5)
        #expect(command?.outputLimitOverride == 1024)
        #expect(command?.arguments == ["-a", "src/", "dst/"])
        #expect(await recorder.workingDirectory == "/context")
    }

    @Test func copiesDirectoryContentsOnDisk() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source", isDirectory: true)
        let destination = directory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let nested = source.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "hello".write(to: nested.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let output =
            try await subject
            .recursive()
            .source(source.path + "/")
            .destination(destination.path + "/")
            .run()

        let copied = destination.appendingPathComponent("nested/file.txt")
        let contents = try String(contentsOf: copied, encoding: .utf8)

        #expect(output.exitCode == 0)
        #expect(contents == "hello")
    }

    @Test func dryRunDoesNotCopyFilesOnDisk() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("source", isDirectory: true)
        let destination = directory.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try "hello".write(to: source.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let output =
            try await subject
            .recursive()
            .dryRun()
            .source(source.path + "/")
            .destination(destination.path + "/")
            .run()

        let copied = destination.appendingPathComponent("file.txt")
        #expect(output.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: copied.path))
    }
}
#endif
