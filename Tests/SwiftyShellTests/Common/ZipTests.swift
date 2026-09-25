#if Zip
import Foundation
import Testing
@testable import SwiftyShell

struct ZipCommandTests {
    let subject = Zip()

    @Test func operationsAreMutuallyExclusiveLastWins() {
        #expect(subject.update().freshen().command().arguments == ["-f"])
        #expect(subject.freshen().delete().command().arguments == ["-d"])
        #expect(subject.delete().update().move().command().arguments == ["-u", "-m"])
        #expect(subject.update().freshen(false).command().arguments == ["-u"])
        #expect(subject.update().update(false).command().arguments.isEmpty)
    }

    @Test func buildsDefaultZipCommand() {
        let command = subject.command()

        #expect(command.executableName == "zip")
        #expect(command.arguments == [])
    }

    @Test func buildsZipCommandWithFlagsAndPaths() {
        let command =
            subject
            .recursive()
            .quiet()
            .compressionLevel(.best)
            .archive("/tmp/out.zip")
            .path("Sources")
            .path("README.md")
            .excludes(["*.tmp", "*/.build/*"])
            .command()

        #expect(command.executableName == "zip")
        #expect(
            command.arguments == [
                "-r", "-q", "-9",
                "/tmp/out.zip",
                "Sources", "README.md",
                "-x", "*.tmp", "*/.build/*",
            ]
        )
    }

    @Test func emitsModeFlagsBeforeBehaviorFlags() {
        let command =
            subject
            .update()
            .recursive()
            .archive("/tmp/out.zip")
            .path("file.txt")
            .command()

        #expect(command.arguments == ["-u", "-r", "/tmp/out.zip", "file.txt"])
    }

    @Test func stripExtraFieldsUsesNoExtraFlag() {
        #expect(subject.stripExtraFields().command().arguments == ["-X"])
    }

    @Test func emitsPasswordAndSplitSize() {
        let command =
            subject
            .splitSize("100m")
            .password("hunter2")
            .archive("/tmp/out.zip")
            .path("file.txt")
            .command()

        #expect(
            command.arguments == [
                "-s", "100m",
                "-P", "hunter2",
                "/tmp/out.zip",
                "file.txt",
            ]
        )
    }

    @Test func emitsIncludesBeforeExcludes() {
        let command =
            subject
            .archive("/tmp/out.zip")
            .path(".")
            .include("*.swift")
            .exclude("*.tmp")
            .command()

        #expect(
            command.arguments == [
                "/tmp/out.zip",
                ".",
                "-i", "*.swift",
                "-x", "*.tmp",
            ]
        )
    }

    @Test(arguments: [
        (ZipCompressionLevel.store, "-0"),
        (ZipCompressionLevel.fastest, "-1"),
        (ZipCompressionLevel.default, "-6"),
        (ZipCompressionLevel.best, "-9"),
    ])
    func compressionLevelFlagMapping(level: ZipCompressionLevel, expectedFlag: String) {
        #expect(subject.compressionLevel(level).command().arguments == [expectedFlag])
    }

    @Test(arguments: [
        (99, "-9"),
        (-7, "-0"),
        (3, "-3"),
    ])
    func customCompressionLevelClampsOutOfRange(raw: Int, expectedFlag: String) {
        #expect(subject.compressionLevel(.custom(raw)).command().arguments == [expectedFlag])
    }

    @Test func createsArchiveOnDisk() async throws {
        let directory = try CommonTestSupport.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let inputName = "hello.txt"
        let input = directory.appendingPathComponent(inputName)
        try "hello world".write(to: input, atomically: true, encoding: .utf8)

        let archive = directory.appendingPathComponent("out.zip")
        let output =
            try await subject
            .workingDirectory(directory.path)
            .quiet()
            .archive("out.zip")
            .path(inputName)
            .run()

        #expect(output.exitCode == 0)
        #expect(FileManager.default.fileExists(atPath: archive.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: archive.path)
        let size = attributes[.size] as? Int ?? 0
        #expect(size > 0)
    }
}

/// Every Boolean flag setter adds exactly its flag when enabled and removes it when disabled.
struct ZipFlagSetterTests {
    @Test func eachFlagSetterTogglesItsFlag() {
        let base = Zip()
        let setters: [(flag: String, set: (Zip, Bool) -> Zip)] = [
            ("-m", { $0.move($1) }),
            ("-r", { $0.recursive($1) }),
            ("-q", { $0.quiet($1) }),
            ("-v", { $0.verbose($1) }),
            ("-j", { $0.junkPaths($1) }),
            ("-y", { $0.storeSymlinks($1) }),
            ("-X", { $0.stripExtraFields($1) }),
            ("-e", { $0.encryptInteractive($1) }),
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
