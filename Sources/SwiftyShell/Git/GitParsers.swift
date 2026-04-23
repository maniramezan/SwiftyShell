import Foundation

enum GitParsers {
    static func parseStatus(_ output: String) throws -> GitStatus {
        var branch: String?
        var upstream: String?
        var hasStagedChanges = false
        var hasUnstagedChanges = false
        var hasUntrackedFiles = false

        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            if let head = line.stripPrefix("# branch.head ") {
                branch = head == "(detached)" ? nil : head
                continue
            }
            if let trackedUpstream = line.stripPrefix("# branch.upstream ") {
                upstream = trackedUpstream
                continue
            }
            if line.hasPrefix("? ") {
                hasUntrackedFiles = true
                continue
            }
            if line.hasPrefix("1 ") || line.hasPrefix("2 ") || line.hasPrefix("u ") {
                let parts = line.split(separator: " ")
                if parts.count > 1 {
                    let xy = Array(parts[1])
                    if xy.count >= 2 {
                        hasStagedChanges = hasStagedChanges || xy[0] != "."
                        hasUnstagedChanges = hasUnstagedChanges || xy[1] != "."
                    }
                }
            }
        }

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

    static func parseBranchEntries(_ output: String) -> [GitBranchEntry] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine -> GitBranchEntry? in
                let parts = rawLine.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard parts.count == 3 else { return nil }

                let headMarker = parts[0].trimmingCharacters(in: .whitespaces)
                let name = parts[1].trimmingCharacters(in: .whitespaces)
                let upstream = parts[2].trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }

                return GitBranchEntry(
                    name: name,
                    isCurrent: headMarker == "*",
                    upstream: upstream.isEmpty ? nil : upstream
                )
            }
    }

    static func parseLogEntries(_ output: String) -> [GitLogEntry] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine -> GitLogEntry? in
                let parts = rawLine.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
                guard parts.count == 5 else { return nil }
                return GitLogEntry(
                    commitHash: parts[0],
                    abbreviatedCommitHash: parts[1],
                    authorName: parts[2],
                    authorEmail: parts[3],
                    subject: parts[4]
                )
            }
    }

    static func parseDiffFileChanges(_ output: String) -> [GitDiffFileChange] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine -> GitDiffFileChange? in
                let components = rawLine.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                guard let statusCode = components.first, components.count >= 2 else { return nil }

                let kind = parseDiffChangeKind(statusCode)
                if statusCode.hasPrefix("R") || statusCode.hasPrefix("C") {
                    guard components.count >= 3 else { return nil }
                    return GitDiffFileChange(
                        kind: kind,
                        path: components[2],
                        originalPath: components[1],
                        statusCode: statusCode
                    )
                }

                return GitDiffFileChange(
                    kind: kind,
                    path: components[1],
                    originalPath: nil,
                    statusCode: statusCode
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
}

private extension String {
    func stripPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
