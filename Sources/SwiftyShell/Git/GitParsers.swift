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

        let state: GitWorkingTreeState = (hasStagedChanges || hasUnstagedChanges || hasUntrackedFiles) ? .dirty : .noChanges
        return GitStatus(
            state: state,
            branch: branch,
            upstream: upstream,
            hasStagedChanges: hasStagedChanges,
            hasUnstagedChanges: hasUnstagedChanges,
            hasUntrackedFiles: hasUntrackedFiles
        )
    }
}

private extension String {
    func stripPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
