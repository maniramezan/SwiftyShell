#!/usr/bin/env swift
//
// validate-code-coverage.swift
//
// Validates package line coverage using SwiftPM's exported code coverage JSON.
//
// Run from the repository root:
//
//     swift Scripts/validate-code-coverage.swift \
//       --input .build/arm64-apple-macosx/debug/codecov/SwiftyShell.json \
//       --minimum-line-coverage 84.33

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
        case .thresholdNotMet(let actual, let minimum):
            return String(
                format: "Package line coverage %.2f%% is below the required %.2f%%.",
                actual,
                minimum
            )
        }
    }
}

func usageMessage() -> String {
    """
    Usage:
      swift Scripts/validate-code-coverage.swift --input <path> --minimum-line-coverage <percent>
    """
}

func parseArguments() throws -> (inputPath: String, minimumLineCoverage: Double) {
    let arguments = Array(CommandLine.arguments.dropFirst())
    var inputPath: String?
    var minimumLineCoverage: Double?
    var index = 0

    while index < arguments.count {
        switch arguments[index] {
        case "--input":
            index += 1
            guard index < arguments.count else {
                throw ValidationError.usage(usageMessage())
            }
            inputPath = arguments[index]
        case "--minimum-line-coverage":
            index += 1
            guard index < arguments.count, let value = Double(arguments[index]) else {
                throw ValidationError.usage(usageMessage())
            }
            minimumLineCoverage = value
        default:
            throw ValidationError.usage(usageMessage())
        }

        index += 1
    }

    guard let inputPath, let minimumLineCoverage else {
        throw ValidationError.usage(usageMessage())
    }

    return (inputPath, minimumLineCoverage)
}

func sourceCoverageTotals(from reportPath: String) throws -> CoverageTotals {
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

    let repoRoot = FileManager.default.currentDirectoryPath
    let sourcesPrefix = "\(repoRoot)/Sources/SwiftyShell/"

    var coveredLines = 0
    var executableLines = 0

    for container in containers {
        guard let files = container["files"] as? [[String: Any]] else { continue }

        for file in files {
            guard
                let filename = file["filename"] as? String,
                filename.hasPrefix(sourcesPrefix),
                let summary = file["summary"] as? [String: Any],
                let lines = summary["lines"] as? [String: Any],
                let count = lines["count"] as? Int,
                let covered = lines["covered"] as? Int
            else {
                continue
            }

            executableLines += count
            coveredLines += covered
        }
    }

    guard executableLines > 0 else {
        throw ValidationError.missingCoverageData(reportPath)
    }

    return CoverageTotals(coveredLines: coveredLines, executableLines: executableLines)
}

do {
    let arguments = try parseArguments()
    let totals = try sourceCoverageTotals(from: arguments.inputPath)

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
} catch let error as ValidationError {
    fputs("validate-code-coverage: \(error.description)\n", stderr)
    exit(1)
} catch {
    fputs("validate-code-coverage: unexpected error: \(error)\n", stderr)
    exit(1)
}
