import Foundation
import Testing

@testable import SwiftyShell

struct SpawnedProcessLinesTests {
    private struct ChunkedProcess: SpawnedProcess {
        let processIdentifier: Int32 = 1
        let standardOutput: AsyncStream<String>
        let standardError: AsyncStream<String>

        init(stdout: [String], stderr: [String] = []) {
            standardOutput = AsyncStream { continuation in
                for chunk in stdout { continuation.yield(chunk) }
                continuation.finish()
            }
            standardError = AsyncStream { continuation in
                for chunk in stderr { continuation.yield(chunk) }
                continuation.finish()
            }
        }

        func send(_ signal: ProcessSignal) async throws {}
        func teardownAndWait() async -> ShellOutput { ShellOutput(exitCode: 0) }
        func waitForExit() async -> ShellOutput { ShellOutput(exitCode: 0) }
    }

    private func collect(_ stream: AsyncStream<String>) async -> [String] {
        var lines: [String] = []
        for await line in stream { lines.append(line) }
        return lines
    }

    @Test func splitsAcrossChunkBoundaries() async {
        let process = ChunkedProcess(stdout: ["al", "pha\nbe", "ta\n", "gam", "ma"])
        #expect(await collect(process.standardOutputLines) == ["alpha", "beta", "gamma"])
    }

    @Test func handlesCarriageReturnLineFeedSplitAcrossChunks() async {
        let process = ChunkedProcess(stdout: ["one\r", "\ntwo\r\nthree\r", "\n"])
        #expect(await collect(process.standardOutputLines) == ["one", "two", "three"])
    }

    @Test func keepsLoneCarriageReturnAsText() async {
        let process = ChunkedProcess(stdout: ["a\rb\n", "tail\r"])
        #expect(await collect(process.standardOutputLines) == ["a\rb", "tail\r"])
    }

    @Test func deliversEmptyLinesAndOmitsEmptyTrailingPartial() async {
        let process = ChunkedProcess(stdout: ["\n\nx\n"])
        #expect(await collect(process.standardOutputLines) == ["", "", "x"])
    }

    @Test func emitsFinalLineWithoutTrailingNewline() async {
        let process = ChunkedProcess(stdout: ["done"])
        #expect(await collect(process.standardOutputLines) == ["done"])
    }

    @Test func emptyStreamProducesNoLines() async {
        let process = ChunkedProcess(stdout: [])
        #expect(await collect(process.standardOutputLines).isEmpty)
    }

    @Test func errorLinesUseTheStderrStream() async {
        let process = ChunkedProcess(stdout: ["out\n"], stderr: ["er", "r\n"])
        #expect(await collect(process.standardErrorLines) == ["err"])
    }

    @Test func multibyteCharactersSurviveSplitting() async {
        let process = ChunkedProcess(stdout: ["héllo ", "wörld\n日本"])
        #expect(await collect(process.standardOutputLines) == ["héllo wörld", "日本"])
    }

    @Test func mockSpawnedProcessProvidesLines() async throws {
        let context = ShellContext(executor: MockExecutor(stdout: "a\nb\n", stderr: "e\n"))
        let process = try await Command("tool").spawn(in: context)
        #expect(await collect(process.standardOutputLines) == ["a", "b"])
        #expect(await collect(process.standardErrorLines) == ["e"])
    }

    @Test func realProcessLinesMatchOutput() async throws {
        let process = try await Command("/bin/sh", arguments: "-c", "printf 'x\\r\\ny\\nz'; printf 'e1\\n' >&2").spawn()
        #expect(await collect(process.standardOutputLines) == ["x", "y", "z"])
        #expect(await collect(process.standardErrorLines) == ["e1"])
        _ = await process.waitForExit()
    }

    @Test func splitterFinishResetsState() {
        var splitter = LineSplitter()
        #expect(splitter.push("a\nb").count == 1)
        #expect(splitter.finish() == "b")
        #expect(splitter.finish() == nil)
    }
}
