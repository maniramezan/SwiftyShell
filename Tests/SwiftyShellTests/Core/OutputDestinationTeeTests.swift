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
private func capturingStandardStreams(
    _ fileDescriptors: [Int32],
    during body: () async -> Void
) async throws -> [Int32: String] {
    var entries: [(fileDescriptor: Int32, url: URL, handle: FileHandle, saved: Int32)] = []

    for fileDescriptor in fileDescriptors {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tee-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
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
        dup2(entry.saved, entry.fileDescriptor)
        close(entry.saved)
        try? entry.handle.close()
        results[entry.fileDescriptor] = (try? String(contentsOf: entry.url, encoding: .utf8)) ?? ""
        try? FileManager.default.removeItem(at: entry.url)
    }
    return results
}

@Suite(.serialized)
struct OutputDestinationTeeTests {
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
