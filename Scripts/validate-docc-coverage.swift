#!/usr/bin/env swift
//
// validate-docc-coverage.swift
//
// Structural validator for SwiftyShell's authored DocC coverage.
//
// Run from the repository root:
//
//     swift Scripts/validate-docc-coverage.swift
//
// The script enforces the documentation contract documented in `AGENTS.md`
// and `.claude/skills/swiftyshell.md`: public API must be visible from DocC,
// and public command families must have a user-facing page with Swift examples.

import Foundation

struct ValidationFailure {
    let location: String
    let message: String
}

struct PublicType {
    let name: String
    let declarationKind: String
    let conformsToRunnableCommandFamily: Bool
    let sourcePath: String
}

let repoRoot = FileManager.default.currentDirectoryPath
let sourcesRoot = "\(repoRoot)/Sources/SwiftyShell"
let doccRoot = "\(repoRoot)/Sources/SwiftyShell/SwiftyShell.docc"

let groupedCommandFamilyPages: [String: String] = [
    "GitBranch": "Git.md",
    "GitStash": "Git.md",
    "GitWorktree": "Git.md",
    "GitSubmodule": "Git.md",
    "GitDiff": "Git.md",
    "GitLog": "Git.md",
    "GitConfigCommand": "Git.md",
    "GitMerge": "Git.md",
    "GitCommit": "Git.md",
    "GitRebase": "Git.md",
]

var failures: [ValidationFailure] = []

func fail(_ location: String, _ message: String) {
    failures.append(ValidationFailure(location: location, message: message))
}

func readFile(_ path: String) -> String? {
    try? String(contentsOfFile: path, encoding: .utf8)
}

func isDirectory(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

func files(in directory: String, suffix: String) -> [String] {
    guard let enumerator = FileManager.default.enumerator(atPath: directory) else { return [] }
    return enumerator.compactMap { entry -> String? in
        guard let relativePath = entry as? String else { return nil }
        let path = "\(directory)/\(relativePath)"
        guard !isDirectory(path), path.hasSuffix(suffix) else { return nil }
        return path
    }.sorted()
}

func stripComments(from line: String) -> String {
    guard let commentRange = line.range(of: "//") else { return line }
    return String(line[..<commentRange.lowerBound])
}

func publicTypes(in filePath: String) -> [PublicType] {
    guard let contents = readFile(filePath) else { return [] }
    let pattern = #"\bpublic\s+(struct|enum|protocol|class)\s+([A-Za-z_][A-Za-z0-9_]*)\s*([^\{]*)\{"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let nsContents = contents as NSString
    let matches = regex.matches(in: contents, range: NSRange(location: 0, length: nsContents.length))

    return matches.map { match in
        let declarationKind = nsContents.substring(with: match.range(at: 1))
        let name = nsContents.substring(with: match.range(at: 2))
        let inheritanceClause = nsContents.substring(with: match.range(at: 3))
        return PublicType(
            name: name,
            declarationKind: declarationKind,
            conformsToRunnableCommandFamily: inheritanceClause.contains("RunnableCommandFamily"),
            sourcePath: filePath
        )
    }
}

func containsSymbolReference(_ symbol: String, in contents: String) -> Bool {
    contents.contains("``\(symbol)``") || contents.contains("/\(symbol)``")
}

func pagePath(for publicType: PublicType) -> String {
    if let groupedPage = groupedCommandFamilyPages[publicType.name] {
        return "\(doccRoot)/\(groupedPage)"
    }
    return "\(doccRoot)/\(publicType.name).md"
}

let sourceFiles = files(in: sourcesRoot, suffix: ".swift")
let doccFiles = files(in: doccRoot, suffix: ".md")
let doccContentsByPath = Dictionary(
    uniqueKeysWithValues: doccFiles.compactMap { path in
        readFile(path).map { (path, $0) }
    }
)
let allDoccContents = doccContentsByPath.values.joined(separator: "\n")
let allPublicTypes = sourceFiles.flatMap(publicTypes(in:))

for publicType in allPublicTypes.sorted(by: { $0.name < $1.name }) {
    if !containsSymbolReference(publicType.name, in: allDoccContents) {
        fail(
            publicType.sourcePath,
            "Public \(publicType.declarationKind) `\(publicType.name)` is missing a DocC symbol reference. "
                + "Add it to `SwiftyShell.docc` so it appears in authored documentation."
        )
    }

    guard publicType.conformsToRunnableCommandFamily else { continue }
    let documentationPage = pagePath(for: publicType)
    guard let pageContents = readFile(documentationPage) else {
        fail(
            publicType.sourcePath,
            "Public command family `\(publicType.name)` needs user-facing DocC. "
                + "Create `\(documentationPage.replacingOccurrences(of: "\(repoRoot)/", with: ""))` with examples."
        )
        continue
    }

    if !containsSymbolReference(publicType.name, in: pageContents) {
        fail(documentationPage, "DocC page must reference public command family `\(publicType.name)`.")
    }
    if !pageContents.contains("```swift") {
        fail(documentationPage, "DocC page for `\(publicType.name)` must include at least one Swift example.")
    }
    if !pageContents.contains("## Topics") {
        fail(documentationPage, "DocC page for `\(publicType.name)` must include a `## Topics` section.")
    }
}

if failures.isEmpty {
    print("validate-docc-coverage: ok — \(allPublicTypes.count) public types validated.")
} else {
    fputs("validate-docc-coverage: found \(failures.count) problem(s):\n", stderr)
    for failure in failures {
        let relativeLocation = failure.location.replacingOccurrences(of: "\(repoRoot)/", with: "")
        fputs("- \(relativeLocation): \(failure.message)\n", stderr)
    }
    exit(1)
}
