import Foundation

public extension SpawnedProcess {
    /// Real-time stdout as complete lines, without their line terminators.
    ///
    /// Built on ``standardOutput``: chunks are joined across their boundaries and split on `\n` and
    /// `\r\n`. A lone `\r` is kept as ordinary text. Empty lines are delivered as empty strings, and a
    /// final line that lacks a terminating newline is delivered when the process closes its output.
    ///
    /// This reads the same underlying stream as ``standardOutput`` and ``standardOutputData``, so
    /// consume only one of them. Lines are pulled on demand, so a slow consumer does not buffer more
    /// than the 1,024 most recent unread chunks the underlying stream already retains.
    ///
    /// ```swift
    /// let process = try await Command("tail", arguments: "-f", "app.log").spawn()
    /// for await line in process.standardOutputLines {
    ///     if line.contains("ready") { break }
    /// }
    /// _ = await process.teardownAndWait()
    /// ```
    var standardOutputLines: AsyncStream<String> {
        makeLineStream(from: standardOutput)
    }

    /// Real-time stderr as complete lines, without their line terminators.
    ///
    /// Splits ``standardError`` exactly like ``standardOutputLines`` splits stdout.
    var standardErrorLines: AsyncStream<String> {
        makeLineStream(from: standardError)
    }
}

/// Splits text chunks into lines on `\n` and `\r\n`, carrying partial lines across chunks.
struct LineSplitter {
    private var current = String.UnicodeScalarView()
    private var pendingCarriageReturn = false

    /// Adds a chunk and returns every line it completed.
    mutating func push(_ chunk: String) -> [String] {
        var lines: [String] = []
        for scalar in chunk.unicodeScalars {
            if pendingCarriageReturn {
                pendingCarriageReturn = false
                if scalar == "\n" {
                    lines.append(takeLine())
                    continue
                }
                current.append("\r")
            }
            switch scalar {
            case "\n":
                lines.append(takeLine())
            case "\r":
                pendingCarriageReturn = true
            default:
                current.append(scalar)
            }
        }
        return lines
    }

    /// Returns the trailing partial line, if any, and resets the splitter.
    mutating func finish() -> String? {
        if pendingCarriageReturn {
            pendingCarriageReturn = false
            current.append("\r")
        }
        return current.isEmpty ? nil : takeLine()
    }

    private mutating func takeLine() -> String {
        defer { current = String.UnicodeScalarView() }
        return String(current)
    }
}

/// Builds a pull-based line stream so the consumer's pace is the only buffering.
private func makeLineStream(from chunks: AsyncStream<String>) -> AsyncStream<String> {
    let state = LineStreamState(chunks: chunks)
    return AsyncStream(unfolding: { await state.next() })
}

/// Holds the iterator and splitter for one line stream; only the single consumer calls it.
private final class LineStreamState: @unchecked Sendable {
    private var iterator: AsyncStream<String>.AsyncIterator
    private var splitter = LineSplitter()
    private var queue: [String] = []
    private var head = 0
    private var finished = false

    init(chunks: AsyncStream<String>) {
        iterator = chunks.makeAsyncIterator()
    }

    func next() async -> String? {
        while true {
            if head < queue.count {
                let line = queue[head]
                head += 1
                if head == queue.count {
                    queue.removeAll(keepingCapacity: true)
                    head = 0
                }
                return line
            }
            if finished { return nil }
            if let chunk = await iterator.next() {
                queue = splitter.push(chunk)
                head = 0
            } else {
                finished = true
                if let last = splitter.finish() {
                    queue = [last]
                    head = 0
                }
            }
        }
    }
}
