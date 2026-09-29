import Foundation
import Testing

@testable import SwiftyShell

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Redirects the given process file descriptors (e.g. `STDOUT_FILENO`) to temporary files for the
/// duration of `body`, then restores them and returns the captured contents keyed by descriptor.
///
/// Used to observe the live writes that ``OutputDestination/tee`` makes to the parent process's
/// standard output and standard error without polluting the test runner's own output.
///
/// The redirect is process-wide, so it also swallows anything the rest of the (parallel) test suite
/// prints while the window is open. Every captured byte is therefore replayed to the restored
/// descriptor before the window closes. Without that replay, these tests would silently discard most
/// of the runner's output — including the details of any failure recorded elsewhere in the run.
private func capturingStandardStreams(
    _ fileDescriptors: [Int32],
    during body: () async -> Void
) async throws -> [Int32: String] {
    var entries: [(fileDescriptor: Int32, url: URL, handle: FileHandle, saved: Int32)] = []

    for fileDescriptor in fileDescriptors {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tee-\(UUID().uuidString).log")
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        entries.append((fileDescriptor, url, handle, saved: -1))
    }

    fflush(nil)
    for index in entries.indices {
        entries[index].saved = dup(entries[index].fileDescriptor)
        dup2(entries[index].handle.fileDescriptor, entries[index].fileDescriptor)
    }

    await body()

    fflush(nil)
    var results: [Int32: String] = [:]
    for entry in entries {
        // Restore the descriptor before reading the file, so a concurrent writer is never left
        // writing into a descriptor this helper is about to close.
        dup2(entry.saved, entry.fileDescriptor)
        let captured = (try? Data(contentsOf: entry.url)) ?? Data()
        if !captured.isEmpty {
            let replay = FileHandle(fileDescriptor: entry.saved, closeOnDealloc: false)
            try? replay.write(contentsOf: captured)
        }
        close(entry.saved)
        try? entry.handle.close()
        results[entry.fileDescriptor] = String(decoding: captured, as: UTF8.self)
        try? FileManager.default.removeItem(at: entry.url)
    }
    return results
}

@Suite(.serialized)
struct OutputDestinationTeeTests {
    @Test func redirectedTeeKeepsJSONChannelClean() async throws {
        var captured: ShellOutput?
        let streams = try await capturingStandardStreams([STDOUT_FILENO, STDERR_FILENO]) {
            captured = try? await Command("/bin/sh", arguments: "-c", "printf routed-out; printf routed-err >&2")
                .stdout(.teeTo(.stderr))
                .stderr(.teeTo(.stderr))
                .run()
        }
        let output = try #require(captured)
        #expect(output.stdout == "routed-out")
        #expect(output.stderr == "routed-err")
        #expect(streams[STDOUT_FILENO]?.contains("routed-out") == false)
        #expect(streams[STDOUT_FILENO]?.contains("routed-err") == false)
        #expect(streams[STDERR_FILENO]?.contains("routed-out") == true)
        #expect(streams[STDERR_FILENO]?.contains("routed-err") == true)
    }

    @Test(arguments: [false, true])
    func explicitTeeRoutesSpawnAndPipelineToStdout(spawn: Bool) async throws {
        var captured: ShellOutput?
        let streams = try await capturingStandardStreams([STDOUT_FILENO, STDERR_FILENO]) {
            if spawn {
                let process = try? await Command("/bin/sh", arguments: "-c", "printf spawned-error >&2")
                    .stderr(.teeTo(.stdout)).spawn(captureOutput: true)
                captured = await process?.waitForExit()
            } else {
                captured = try? await Command("printf", arguments: "pipeline-output")
                    .pipe(to: Command("cat").stdout(.teeTo(.stdout))).run()
            }
        }
        let marker = spawn ? "spawned-error" : "pipeline-output"
        let output = try #require(captured)
        #expect((spawn ? output.stderr : output.stdout) == marker)
        #expect(streams[STDOUT_FILENO]?.contains(marker) == true)
        #expect(streams[STDERR_FILENO]?.contains(marker) == false)
    }

    @Test func logCanAlsoStreamToParentStderr() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        var captured: ShellOutput?
        let streams = try await capturingStandardStreams([STDOUT_FILENO, STDERR_FILENO]) {
            captured = try? await Command("printf", arguments: "log-progress")
                .stdout(.log(path: path, append: false, tailBytes: 4, tee: .stderr))
                .run()
        }
        #expect(try #require(captured).stdout == "ress")
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "log-progress")
        #expect(streams[STDOUT_FILENO]?.contains("log-progress") == false)
        #expect(streams[STDERR_FILENO]?.contains("log-progress") == true)
    }

    @Test func teeStillCapturesStreamForShellOutput() async throws {
        let context = ShellContext()
        var captured: ShellOutput?
        _ = try await capturingStandardStreams([STDOUT_FILENO]) {
            captured = try? await Command("/bin/sh", arguments: "-c", "printf 'tee-capture-text'")
                .stdout(.tee)
                .run(in: context)
        }

        let output = try #require(captured)
        #expect(output.stdout == "tee-capture-text")
    }

    @Test func teeWritesLiveToParentStandardOutput() async throws {
        let context = ShellContext()
        let streams = try await capturingStandardStreams([STDOUT_FILENO]) {
            _ = try? await Command("/bin/sh", arguments: "-c", "printf 'tee-live-text'")
                .stdout(.tee)
                .run(in: context)
        }

        #expect(streams[STDOUT_FILENO]?.contains("tee-live-text") == true)
    }

    @Test func teeInterleavesStdoutAndStderrWithoutCorruption() async throws {
        let context = ShellContext()
        var captured: ShellOutput?
        let streams = try await capturingStandardStreams([STDOUT_FILENO, STDERR_FILENO]) {
            captured = try? await Command(
                "/bin/sh",
                arguments: "-c",
                "printf 'out-stream'; printf 'err-stream' >&2"
            )
            .stdout(.tee)
            .stderr(.tee)
            .run(in: context)
        }

        let output = try #require(captured)
        #expect(output.stdout == "out-stream")
        #expect(output.stderr == "err-stream")
        #expect(streams[STDOUT_FILENO]?.contains("out-stream") == true)
        #expect(streams[STDERR_FILENO]?.contains("err-stream") == true)
    }

    @Test func teeRespectsOutputLimit() async throws {
        let context = ShellContext(defaultOutputLimit: 4)
        var thrown: Error?
        _ = try await capturingStandardStreams([STDOUT_FILENO]) {
            do {
                _ = try await Command("/bin/sh", arguments: "-c", "printf 'abcdef'")
                    .stdout(.tee)
                    .run(in: context)
                Issue.record("Expected outputLimitExceeded")
            } catch {
                thrown = error
            }
        }

        let error = try #require(thrown as? ShellError)
        guard case let .outputLimitExceeded(_, limit, partialOutput) = error else {
            Issue.record("Expected outputLimitExceeded, got \(error)")
            return
        }
        #expect(limit == 4)
        #expect(partialOutput.stdout == "abcd")
    }
}
