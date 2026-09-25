import Foundation
import Testing
@testable import SwiftyShell

struct StdinTests {
    private func temporaryPath() -> String {
        FileManager.default.temporaryDirectory.appendingPathComponent("swiftyshell-stdin-\(UUID().uuidString)").path
    }

    @Test func defaultStdinIsEmpty() async throws {
        let output = try await Command("cat").run()

        #expect(output.stdoutData.isEmpty)
        #expect(Command("cat").stdinSource == .none)
    }

    @Test func stringSourceIsWrittenAsUTF8() async throws {
        let output = try await Command("cat").stdin(.string("héllo\nworld")).run()

        #expect(output.stdout == "héllo\nworld")
    }

    @Test func dataSourceIsWrittenVerbatim() async throws {
        let bytes = Data([0x00, 0xFF, 0x10, 0x80])
        let output = try await Command("cat").stdin(.data(bytes)).run()

        #expect(output.stdoutData == bytes)
    }

    @Test func largeDataSourceDoesNotDeadlockWhileOutputIsCaptured() async throws {
        // Larger than any pipe buffer in both directions: the input writer and output readers must
        // run concurrently.
        let bytes = Data(repeating: 0x61, count: 4 * 1024 * 1024)
        let output = try await Command("cat").stdin(.data(bytes)).timeout(.seconds(30)).run()

        #expect(output.stdoutData == bytes)
    }

    @Test func fileSourceIsReadLikeShellRedirection() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        try "one\ntwo\nthree\n".write(toFile: path, atomically: true, encoding: .utf8)

        let output = try await Command("wc", arguments: "-l").stdin(.file(path: path)).run()

        #expect(output.stdout.trimmingCharacters(in: .whitespaces) == "3\n")
    }

    @Test func relativeFileSourceResolvesAgainstWorkingDirectory() async throws {
        let directory = temporaryPath()
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: directory) }
        try "relative".write(toFile: "\(directory)/in.txt", atomically: true, encoding: .utf8)

        let output = try await Command("cat").workingDirectory(directory).stdin(.file(path: "in.txt")).run()

        #expect(output.stdout == "relative")
    }

    @Test func missingFileSourceThrowsSpawnError() async throws {
        await #expect {
            try await Command("cat").stdin(.file(path: "/nonexistent/input.txt")).run()
        } throws: { error in
            guard case .spawnError = error as? ShellError else { return false }
            return true
        }
    }

    @Test func pipelineFeedsFirstStage() async throws {
        let output = try await Command("cat").stdin(.string("b\na\nc\n"))
            .pipe(to: Command("sort"))
            .run()

        #expect(output.stdout == "a\nb\nc\n")
    }

    @Test(arguments: [ShellContext(), ShellContext(executor: MockExecutor())])
    func pipelineRejectsStdinOnLaterStagesBeforeRunning(context: ShellContext) async throws {
        await #expect {
            try await Command("cat").pipe(to: Command("sort").stdin(.string("ignored\n"))).run(in: context)
        } throws: { error in
            guard case let .invalidConfiguration(description) = error as? ShellError else { return false }
            return description.contains("Only the first pipeline stage may set stdin")
        }
    }

    @Test func spawnedProcessReadsStdinSource() async throws {
        let process = try await Command("cat").stdin(.string("spawned input")).spawn(captureOutput: true)

        var streamed = ""
        for await chunk in process.standardOutput {
            streamed += chunk
        }
        let output = await process.waitForExit()

        #expect(streamed == "spawned input")
        #expect(output.stdout == "spawned input")
    }

    @Test func spawnedProcessReadsFileSource() async throws {
        let path = temporaryPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        try "from file".write(toFile: path, atomically: true, encoding: .utf8)

        let process = try await Command("cat").stdin(.file(path: path)).spawn(captureOutput: true)
        let output = await process.waitForExit()

        #expect(output.stdout == "from file")
    }

    @Test func commandFamilyRunAcceptsStdin() async throws {
        struct Cat: RunnableCommandFamily {
            let context = ShellContext()
            func updatingConfiguration(_ update: (ToolConfiguration) -> ToolConfiguration) -> Self { self }
            func settingStdoutDestination(_ destination: OutputDestination) -> Self { self }
            func settingStderrDestination(_ destination: OutputDestination) -> Self { self }
            func command() -> Command { Command("cat") }
        }

        let output = try await Cat().run(stdin: .string("family"))

        #expect(output.stdout == "family")
    }

    @Test func debugDescriptionSummarizesStdinWithoutContents() {
        let description = Command("cat").stdin(.string("secret-token")).debugDescription

        #expect(description.contains("stdin: string(12 bytes)"))
        #expect(!description.contains("secret-token"))
    }

    @Test func mockExecutorSeesStdinSource() async throws {
        let mock = MockExecutor { command, _ in
            guard case let .string(text) = command.stdinSource else { return ShellOutput(exitCode: 1) }
            return ShellOutput(stdout: text.uppercased(), exitCode: 0)
        }

        let output = try await Command("tr").stdin(.string("abc")).run(in: ShellContext(executor: mock))

        #expect(output.stdout == "ABC")
    }
}
