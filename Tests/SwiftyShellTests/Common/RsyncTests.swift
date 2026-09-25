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
            .timeout(.seconds(5))
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
        #expect(command?.timeoutOverride == .seconds(5))
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

/// Every Boolean flag setter adds exactly its flag when enabled and removes it when disabled.
struct RsyncFlagSetterTests {
    @Test func eachFlagSetterTogglesItsFlag() {
        let base = Rsync()
        let setters: [(flag: String, set: (Rsync, Bool) -> Rsync)] = [
            ("-a", { $0.archive($1) }),
            ("-r", { $0.recursive($1) }),
            ("-z", { $0.compress($1) }),
            ("-v", { $0.verbose($1) }),
            ("-q", { $0.quiet($1) }),
            ("-n", { $0.dryRun($1) }),
            ("-c", { $0.checksum($1) }),
            ("-u", { $0.update($1) }),
            ("--delete", { $0.delete($1) }),
            ("--delete-excluded", { $0.deleteExcluded($1) }),
            ("-l", { $0.links($1) }),
            ("-L", { $0.copyLinks($1) }),
            ("-p", { $0.permissions($1) }),
            ("-t", { $0.times($1) }),
            ("-o", { $0.owner($1) }),
            ("-g", { $0.group($1) }),
            ("-H", { $0.hardLinks($1) }),
            ("-S", { $0.sparse($1) }),
            ("-x", { $0.oneFileSystem($1) }),
            ("-i", { $0.itemizeChanges($1) }),
            ("-h", { $0.humanReadable($1) }),
            ("--progress", { $0.progress($1) }),
            ("--partial", { $0.partial($1) }),
            ("--existing", { $0.existing($1) }),
            ("--ignore-existing", { $0.ignoreExisting($1) }),
            ("--remove-source-files", { $0.removeSourceFiles($1) }),
            ("--from0", { $0.from0($1) }),
        ]
        for (flag, set) in setters {
            #expect(!base.command().arguments.contains(flag), "\(flag) present before enabling")
            let enabled = set(base, true)
            #expect(enabled.command().arguments.contains(flag), "\(flag) missing after enabling")
            #expect(!set(enabled, false).command().arguments.contains(flag), "\(flag) kept after disabling")
        }
    }
}
#endif
