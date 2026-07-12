#!/usr/bin/env swift
//
// validate-code-coverage.swift
//
// Validates package line coverage using SwiftPM's exported code coverage JSON.

import Foundation

struct CoverageTotals {
    let coveredLines: Int
    let executableLines: Int

    var percent: Double {
        guard executableLines > 0 else { return 0 }
        return (Double(coveredLines) / Double(executableLines)) * 100
    }
}

enum ValidationError: Error, CustomStringConvertible {
    case usage(String)
    case unreadableFile(String)
    case invalidJSON(String)
    case missingCoverageData(String)
    case missingSourceFiles([String])
    case invalidThreshold(Double)
    case thresholdNotMet(actual: Double, minimum: Double)

    var description: String {
        switch self {
        case .usage(let message):
            return message
        case .unreadableFile(let path):
            return "Could not read coverage report at `\(path)`."
        case .invalidJSON(let path):
            return "Coverage report at `\(path)` is not valid JSON."
        case .missingCoverageData(let path):
            return "Coverage report at `\(path)` does not contain source line coverage data."
        case .missingSourceFiles(let paths):
            return "Coverage report is missing expected compiled source files:\n  " + paths.joined(separator: "\n  ")
        case .invalidThreshold(let threshold):
            return "Minimum line coverage must be between 0 and 100; received \(threshold)."
        case .thresholdNotMet(let actual, let minimum):
            return String(
                format: "Package line coverage %.2f%% is below the required %.2f%%.",
                actual,
                minimum
            )
        }
    }
}

struct Arguments {
    let inputPath: String
    let minimumLineCoverage: Double
    let allTraits: Bool
}

func usageMessage() -> String {
    """
    Usage:
      swift Scripts/validate-code-coverage.swift --input <path> --minimum-line-coverage <percent> [--all-traits]
      swift Scripts/validate-code-coverage.swift --self-test
    """
}

func validateThreshold(_ value: Double) throws {
    guard value.isFinite, (0...100).contains(value) else {
        throw ValidationError.invalidThreshold(value)
    }
}

func parseArguments() throws -> Arguments? {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--self-test"] { return nil }

    var inputPath: String?
    var minimumLineCoverage: Double?
    var allTraits = false
    var index = 0

    while index < arguments.count {
        switch arguments[index] {
        case "--input":
            index += 1
            guard index < arguments.count else { throw ValidationError.usage(usageMessage()) }
            inputPath = arguments[index]
        case "--minimum-line-coverage":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]) else {
                throw ValidationError.usage(usageMessage())
            }
            minimumLineCoverage = value
        case "--all-traits":
            allTraits = true
        default:
            throw ValidationError.usage(usageMessage())
        }
        index += 1
    }

    guard let inputPath, let minimumLineCoverage else {
        throw ValidationError.usage(usageMessage())
    }
    try validateThreshold(minimumLineCoverage)
    return Arguments(
        inputPath: inputPath,
        minimumLineCoverage: minimumLineCoverage,
        allTraits: allTraits
    )
}

func normalizedPath(_ path: String, relativeTo root: URL) -> String {
    let url = path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(path)
    return url.standardizedFileURL.resolvingSymlinksInPath().path
}

func expectedSourceFiles(repoRoot: URL, allTraits: Bool) throws -> Set<String> {
    let sourcesRoot = repoRoot.appendingPathComponent("Sources/SwiftyShell")
    // LLVM does not emit coverage entries for files containing declarations but no executable regions.
    let declarationOnlyFiles: Set<String> = [
        "Core/CommandExecutor.swift",
        "Core/OutputDestination.swift",
        "Core/ProcessSignal.swift",
    ]
    guard
        let enumerator = FileManager.default.enumerator(
            at: sourcesRoot,
            includingPropertiesForKeys: [.isRegularFileKey]
        )
    else {
        throw ValidationError.unreadableFile(sourcesRoot.path)
    }

    var paths = Set<String>()
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
        let relativePath = fileURL.path.replacingOccurrences(of: sourcesRoot.path + "/", with: "")
        let isUngated = relativePath.hasPrefix("Core/") || relativePath.hasPrefix("Internal/")
        if (allTraits || isUngated) && !declarationOnlyFiles.contains(relativePath) {
            paths.insert(fileURL.standardizedFileURL.resolvingSymlinksInPath().path)
        }
    }
    return paths
}

func sourceCoverageTotals(from reportPath: String, repoRoot: URL, allTraits: Bool) throws -> CoverageTotals {
    let reportURL = URL(fileURLWithPath: reportPath)
    guard let data = try? Data(contentsOf: reportURL) else {
        throw ValidationError.unreadableFile(reportPath)
    }
    guard
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let containers = json["data"] as? [[String: Any]]
    else {
        throw ValidationError.invalidJSON(reportPath)
    }

    let sourcesRoot = normalizedPath("Sources/SwiftyShell", relativeTo: repoRoot) + "/"
    var coverageByPath: [String: CoverageTotals] = [:]

    for container in containers {
        guard let files = container["files"] as? [[String: Any]] else { continue }
        for file in files {
            guard
                let filename = file["filename"] as? String,
                let summary = file["summary"] as? [String: Any],
                let lines = summary["lines"] as? [String: Any],
                let count = lines["count"] as? Int,
                let covered = lines["covered"] as? Int
            else { continue }

            let path = normalizedPath(filename, relativeTo: repoRoot)
            guard path.hasPrefix(sourcesRoot) else { continue }
            coverageByPath[path] = CoverageTotals(coveredLines: covered, executableLines: count)
        }
    }

    let expected = try expectedSourceFiles(repoRoot: repoRoot, allTraits: allTraits)
    let missing = expected.subtracting(coverageByPath.keys).sorted()
    guard missing.isEmpty else {
        let prefix = repoRoot.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        throw ValidationError.missingSourceFiles(missing.map { $0.replacingOccurrences(of: prefix, with: "") })
    }

    let totals = coverageByPath.values.reduce(CoverageTotals(coveredLines: 0, executableLines: 0)) { result, value in
        CoverageTotals(
            coveredLines: result.coveredLines + value.coveredLines,
            executableLines: result.executableLines + value.executableLines
        )
    }
    guard totals.executableLines > 0 else {
        throw ValidationError.missingCoverageData(reportPath)
    }
    return totals
}

func runSelfTest() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let core = temporaryRoot.appendingPathComponent("Sources/SwiftyShell/Core")
    let family = temporaryRoot.appendingPathComponent("Sources/SwiftyShell/Git")
    try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: family, withIntermediateDirectories: true)
    try "struct Core {}".write(to: core.appendingPathComponent("Core.swift"), atomically: true, encoding: .utf8)
    try "struct Git {}".write(to: family.appendingPathComponent("Git.swift"), atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    func writeReport(_ filenames: [String]) throws -> String {
        let files = filenames.map { filename in
            ["filename": filename, "summary": ["lines": ["count": 10, "covered": 9]]] as [String: Any]
        }
        let report = ["data": [["files": files]]]
        let reportURL = temporaryRoot.appendingPathComponent(UUID().uuidString + ".json")
        try JSONSerialization.data(withJSONObject: report).write(to: reportURL)
        return reportURL.path
    }

    let corePath = core.appendingPathComponent("Core.swift").path
    let duplicateReport = try writeReport([corePath, "Sources/SwiftyShell/Core/Core.swift"])
    let totals = try sourceCoverageTotals(from: duplicateReport, repoRoot: temporaryRoot, allTraits: false)
    guard totals.coveredLines == 9, totals.executableLines == 10 else {
        throw ValidationError.missingCoverageData("self-test did not deduplicate normalized paths")
    }

    do {
        _ = try sourceCoverageTotals(from: duplicateReport, repoRoot: temporaryRoot, allTraits: true)
        throw ValidationError.missingCoverageData("self-test accepted a missing all-traits source")
    } catch ValidationError.missingSourceFiles(let paths) where paths == ["Sources/SwiftyShell/Git/Git.swift"] {}

    for threshold in [-0.1, 100.1, Double.infinity, Double.nan] {
        do {
            try validateThreshold(threshold)
            throw ValidationError.missingCoverageData("self-test accepted invalid threshold \(threshold)")
        } catch ValidationError.invalidThreshold {}
    }
    print("validate-code-coverage: self-test ok.")
}

do {
    if let arguments = try parseArguments() {
        let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let totals = try sourceCoverageTotals(
            from: arguments.inputPath,
            repoRoot: repoRoot,
            allTraits: arguments.allTraits
        )
        guard totals.percent >= arguments.minimumLineCoverage else {
            throw ValidationError.thresholdNotMet(actual: totals.percent, minimum: arguments.minimumLineCoverage)
        }
        print(
            String(
                format: "validate-code-coverage: ok - package line coverage %.2f%% (%d/%d) meets %.2f%%.",
                totals.percent,
                totals.coveredLines,
                totals.executableLines,
                arguments.minimumLineCoverage
            )
        )
    } else {
        try runSelfTest()
    }
} catch let error as ValidationError {
    fputs("validate-code-coverage: \(error.description)\n", stderr)
    exit(1)
} catch {
    fputs("validate-code-coverage: unexpected error: \(error)\n", stderr)
    exit(1)
}
