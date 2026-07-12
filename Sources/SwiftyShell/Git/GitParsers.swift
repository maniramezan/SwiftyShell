#if Git
import Foundation

enum GitParsers {
    static func parse<Value>(
        _ output: String,
        from command: Command,
        using parser: (String) throws -> Value
    ) throws -> Value {
        do {
            return try parser(output)
        } catch let error as ShellError {
            throw error
        } catch {
            throw ShellError.parsingError(command: command.displayString(), reason: String(describing: error))
        }
    }

    static func parseStatus(_ output: String) throws -> GitStatus {
        var branch: String?
        var upstream: String?
        var hasStagedChanges = false
        var hasUnstagedChanges = false
        var hasUntrackedFiles = false

        var foundBranchHead = false
        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            if let head = line.stripPrefix("# branch.head ") {
                guard !head.isEmpty else { throw ParseError.malformedRecord(line) }
                branch = head == "(detached)" ? nil : head
                foundBranchHead = true
                continue
            }
            if let trackedUpstream = line.stripPrefix("# branch.upstream ") {
                guard !trackedUpstream.isEmpty else { throw ParseError.malformedRecord(line) }
                upstream = trackedUpstream
                continue
            }
            if line.hasPrefix("# branch.oid ") || line.hasPrefix("# branch.ab ") {
                continue
            }
            if line.hasPrefix("? ") {
                guard line.count > 2 else { throw ParseError.malformedRecord(line) }
                hasUntrackedFiles = true
                continue
            }
            if line.hasPrefix("! ") {
                guard line.count > 2 else { throw ParseError.malformedRecord(line) }
                continue
            }
            if line.hasPrefix("1 ") || line.hasPrefix("2 ") || line.hasPrefix("u ") {
                let parts = line.split(separator: " ")
                guard parts.count > 1 else { throw ParseError.malformedRecord(line) }
                let xy = Array(parts[1])
                guard xy.count == 2 else { throw ParseError.malformedRecord(line) }
                hasStagedChanges = hasStagedChanges || xy[0] != "."
                hasUnstagedChanges = hasUnstagedChanges || xy[1] != "."
                continue
            }
            throw ParseError.malformedRecord(line)
        }

        guard foundBranchHead else { throw ParseError.missingRecord("# branch.head") }

        let state: GitWorkingTreeState =
            (hasStagedChanges || hasUnstagedChanges || hasUntrackedFiles) ? .dirty : .noChanges
        return GitStatus(
            state: state,
            branch: branch,
            upstream: upstream,
            hasStagedChanges: hasStagedChanges,
            hasUnstagedChanges: hasUnstagedChanges,
            hasUntrackedFiles: hasUntrackedFiles
        )
    }

    static func parseBranchEntries(_ output: String) throws -> [GitBranchEntry] {
        try output
            .split(whereSeparator: \.isNewline)
            .map { rawLine -> GitBranchEntry in
                let parts = rawLine.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard parts.count == 3 else { throw ParseError.malformedRecord(String(rawLine)) }

                let headMarker = parts[0].trimmingCharacters(in: .whitespaces)
                let name = parts[1].trimmingCharacters(in: .whitespaces)
                let upstream = parts[2].trimmingCharacters(in: .whitespaces)
                guard (headMarker.isEmpty || headMarker == "*"), !name.isEmpty else {
                    throw ParseError.malformedRecord(String(rawLine))
                }

                return GitBranchEntry(
                    name: name,
                    isCurrent: headMarker == "*",
                    upstream: upstream.isEmpty ? nil : upstream
                )
            }
    }

    static func parseLogEntries(_ output: String) throws -> [GitLogEntry] {
        try output
            .split(whereSeparator: \.isNewline)
            .map { rawLine -> GitLogEntry in
                let parts = rawLine.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
                guard parts.count == 5, !parts[0].isEmpty, !parts[1].isEmpty else {
                    throw ParseError.malformedRecord(String(rawLine))
                }
                return GitLogEntry(
                    commitHash: parts[0],
                    abbreviatedCommitHash: parts[1],
                    authorName: parts[2],
                    authorEmail: parts[3],
                    subject: parts[4]
                )
            }
    }

    static func parseDiffFileChanges(_ output: String) throws -> [GitDiffFileChange] {
        guard output.isEmpty || output.last == "\0" else { throw ParseError.missingTerminator }
        let fields = output.split(separator: "\0", omittingEmptySubsequences: false).dropLast().map(String.init)
        var index = 0
        var changes: [GitDiffFileChange] = []
        while index < fields.count {
            let statusCode = fields[index]
            guard !statusCode.isEmpty else { throw ParseError.malformedRecord(statusCode) }
            let pathCount = statusCode.hasPrefix("R") || statusCode.hasPrefix("C") ? 2 : 1
            guard index + pathCount < fields.count else { throw ParseError.malformedRecord(statusCode) }
            let paths = fields[(index + 1)...(index + pathCount)]
            guard paths.allSatisfy({ !$0.isEmpty }) else { throw ParseError.malformedRecord(statusCode) }
            changes.append(
                GitDiffFileChange(
                    kind: parseDiffChangeKind(statusCode),
                    path: paths.last ?? "",
                    originalPath: pathCount == 2 ? paths.first : nil,
                    statusCode: statusCode
                )
            )
            index += pathCount + 1
        }
        return changes
    }

    static func parseSubmoduleStatusEntries(_ output: String) throws -> [GitSubmoduleStatusEntry] {
        try output
            .split(whereSeparator: \.isNewline)
            .map { rawLine -> GitSubmoduleStatusEntry in
                guard let statePrefix = rawLine.first else { throw ParseError.malformedRecord(String(rawLine)) }
                let state = parseSubmoduleStatusState(String(statePrefix))
                let body = rawLine.dropFirst()
                guard let separator = body.firstIndex(of: " ") else {
                    throw ParseError.malformedRecord(String(rawLine))
                }
                let commitHash = String(body[..<separator])
                let pathAndDescription = String(body[body.index(after: separator)...])
                guard !commitHash.isEmpty, !pathAndDescription.isEmpty else {
                    throw ParseError.malformedRecord(String(rawLine))
                }
                let descriptionStart = pathAndDescription.range(of: " (", options: .backwards)
                let hasDescription = descriptionStart != nil && pathAndDescription.hasSuffix(")")
                let path =
                    hasDescription
                    ? String(pathAndDescription[..<(descriptionStart?.lowerBound ?? pathAndDescription.endIndex)])
                    : pathAndDescription
                let description =
                    hasDescription
                    ? String(
                        pathAndDescription[(descriptionStart?.upperBound ?? pathAndDescription.endIndex)...].dropLast()
                    )
                    : nil
                guard !path.isEmpty else { throw ParseError.malformedRecord(String(rawLine)) }

                return GitSubmoduleStatusEntry(
                    state: state,
                    commitHash: commitHash,
                    path: path,
                    description: description.map { "(\($0))" }
                )
            }
    }

    private static func parseDiffChangeKind(_ statusCode: String) -> GitDiffChangeKind {
        guard let leadingCode = statusCode.first else {
            return .unknown(statusCode)
        }

        switch leadingCode {
        case "A":
            return .added
        case "M":
            return .modified
        case "D":
            return .deleted
        case "R":
            return .renamed
        case "C":
            return .copied
        case "U":
            return .unmerged
        case "T":
            return .typeChanged
        default:
            return .unknown(statusCode)
        }
    }

    private static func parseSubmoduleStatusState(_ prefix: String) -> GitSubmoduleStatusState {
        switch prefix {
        case " ":
            return .current
        case "-":
            return .uninitialized
        case "+":
            return .outOfSync
        case "U":
            return .mergeConflicted
        default:
            return .unknown(prefix)
        }
    }

    enum ParseError: Error, Equatable, CustomStringConvertible {
        case malformedRecord(String)
        case missingRecord(String)
        case missingTerminator

        var description: String {
            switch self {
            case let .malformedRecord(record):
                return "malformed record \(record.debugDescription)"
            case let .missingRecord(record):
                return "missing required record \(record.debugDescription)"
            case .missingTerminator:
                return "missing NUL record terminator"
            }
        }
    }
}

private extension String {
    func stripPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
#endif
