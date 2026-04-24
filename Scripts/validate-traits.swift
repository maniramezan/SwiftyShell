#!/usr/bin/env swift
//
// validate-traits.swift
//
// Structural validator for SwiftyShell's per-family SwiftPM trait wiring.
//
// Run from the repository root:
//
//     swift Scripts/validate-traits.swift
//
// The script enforces the conventions documented in `AGENTS.md` and the
// `SelectingCommandFamilies` DocC article. It exits non-zero on any violation
// so it can be wired into CI as a fast pre-build check.
//
// Rules enforced:
//
// 1. Every per-family trait declared in `Package.swift` must have a matching
//    family (a sibling directory under `Sources/SwiftyShell/`, or — for the
//    flat `Common/` directory — a single source file whose base name matches
//    the trait).
// 2. Every family directory under `Sources/SwiftyShell/` (excluding `Core`,
//    `Internal`, and `SwiftyShell.docc`) must correspond to a declared trait.
// 3. Every source file that belongs to a gated family must be wrapped in
//    `#if <Trait> ... #endif` covering the whole file.
// 4. Every family must have at least one matching test file under
//    `Tests/SwiftyShellTests/<TraitContainer>/` and every such test file must
//    also be wrapped in the matching `#if`.
// 5. The `All` umbrella trait must enable every per-family trait (directly or
//    via the `CommonUtilities` umbrella).
//
// The script intentionally prefers explicit, readable failure messages over
// terse output so contributors can quickly see what to fix.

import Foundation

// MARK: - Types

struct ValidationFailure {
    let location: String
    let message: String
}

// MARK: - Constants

let repoRoot: String = FileManager.default.currentDirectoryPath
let packageManifestPath = "\(repoRoot)/Package.swift"
let sourcesRoot = "\(repoRoot)/Sources/SwiftyShell"
let testsRoot = "\(repoRoot)/Tests/SwiftyShellTests"
let coreOnlyDirectories: Set<String> = ["Core", "Internal", "SwiftyShell.docc"]
let umbrellaTraits: Set<String> = ["All", "CommonUtilities"]
// The flat directory whose source files each represent their own family.
let flatFamilyDirectory = "Common"

// MARK: - Helpers

func readFile(_ path: String) -> String? {
    try? String(contentsOfFile: path, encoding: .utf8)
}

func listChildren(of directory: String) -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: directory).sorted()) ?? []
}

func isDirectory(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

func swiftFiles(in directory: String) -> [String] {
    listChildren(of: directory)
        .filter { $0.hasSuffix(".swift") }
        .map { "\(directory)/\($0)" }
}

/// Returns the trait names declared in `Package.swift` along with the
/// `enabledTraits` for each umbrella trait.
func parsePackageTraits(manifestPath: String) -> (perFamily: Set<String>, umbrellas: [String: [String]])? {
    guard let manifest = readFile(manifestPath) else {
        return nil
    }
    // Match `.trait(name: "Name"...)` declarations. The optional
    // `enabledTraits: [...]` portion is captured per-trait below.
    let traitPattern = #"\.trait\(\s*name:\s*"([^"]+)"([^)]*)\)"#
    guard let regex = try? NSRegularExpression(pattern: traitPattern, options: [.dotMatchesLineSeparators]) else {
        return nil
    }
    let nsManifest = manifest as NSString
    let matches = regex.matches(in: manifest, range: NSRange(location: 0, length: nsManifest.length))

    var perFamily = Set<String>()
    var umbrellas: [String: [String]] = [:]
    for match in matches {
        let name = nsManifest.substring(with: match.range(at: 1))
        let body = nsManifest.substring(with: match.range(at: 2))
        // Extract `enabledTraits: ["A","B"]` if present.
        let enabledPattern = #"enabledTraits:\s*\[([^\]]*)\]"#
        let bodyRange = NSRange(location: 0, length: (body as NSString).length)
        if let enabledRegex = try? NSRegularExpression(pattern: enabledPattern),
            let enabled = enabledRegex.firstMatch(in: body, range: bodyRange)
        {
            let listBody = (body as NSString).substring(with: enabled.range(at: 1))
            let entries =
                listBody
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"\n\t")) }
                .filter { !$0.isEmpty }
            umbrellas[name] = entries
        } else {
            perFamily.insert(name)
        }
    }
    return (perFamily, umbrellas)
}

/// Returns true when `file` begins with `#if <trait>` (skipping leading blank
/// lines and `//` comments) and ends with a matching `#endif`.
func isWrapped(filePath: String, trait: String) -> Bool {
    guard let contents = readFile(filePath) else { return false }
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)

    // Find first significant line (non-blank, non `//` comment, non `#sourceLocation`).
    let firstSignificant = lines.first {
        let trimmed = $0.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        if trimmed.hasPrefix("//") { return false }
        return true
    }
    guard let first = firstSignificant?.trimmingCharacters(in: .whitespaces) else {
        return false
    }
    guard first == "#if \(trait)" else { return false }

    // Find last significant line.
    let lastSignificant = lines.reversed().first {
        let trimmed = $0.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty
    }
    return lastSignificant?.trimmingCharacters(in: .whitespaces) == "#endif"
}

// MARK: - Validation

var failures: [ValidationFailure] = []

func fail(_ location: String, _ message: String) {
    failures.append(ValidationFailure(location: location, message: message))
}

guard let parsed = parsePackageTraits(manifestPath: packageManifestPath) else {
    fputs("Could not parse traits from Package.swift\n", stderr)
    exit(2)
}
let declaredFamilyTraits = parsed.perFamily
let umbrellas = parsed.umbrellas

// 1 + 2: Cross-check declared traits ↔ filesystem layout.
let sourceChildren = listChildren(of: sourcesRoot)
var filesystemFamilies = Set<String>()

for child in sourceChildren {
    let childPath = "\(sourcesRoot)/\(child)"
    guard isDirectory(childPath) else { continue }
    if coreOnlyDirectories.contains(child) { continue }

    if child == flatFamilyDirectory {
        // Each `.swift` file in the flat directory is its own family.
        for file in swiftFiles(in: childPath) {
            let basename = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
            filesystemFamilies.insert(basename)
            // Rule 3: file must be `#if <basename>`-wrapped.
            if !isWrapped(filePath: file, trait: basename) {
                fail(file, "Common family file must be wrapped in `#if \(basename) ... #endif`.")
            }
            // Rule 1: trait declared.
            if !declaredFamilyTraits.contains(basename) {
                fail(
                    file,
                    "Common family `\(basename)` is missing a `.trait(name: \"\(basename)\")` entry in Package.swift."
                )
            }
        }
    } else {
        // Family directory whose name == trait name.
        filesystemFamilies.insert(child)
        // Rule 1: trait declared.
        if !declaredFamilyTraits.contains(child) {
            fail(
                childPath,
                "Family directory `\(child)` is missing a `.trait(name: \"\(child)\")` entry in Package.swift."
            )
        }
        // Rule 3: every file wrapped.
        for file in swiftFiles(in: childPath) {
            if !isWrapped(filePath: file, trait: child) {
                fail(file, "File belongs to family `\(child)` and must be wrapped in `#if \(child) ... #endif`.")
            }
        }
    }
}

// Rule 2 (reverse): every declared per-family trait must have a corresponding family.
for trait in declaredFamilyTraits where !filesystemFamilies.contains(trait) {
    fail(
        packageManifestPath,
        "Trait `\(trait)` is declared in Package.swift but no matching family directory "
            + "or Common/<\(trait)>.swift exists."
    )
}

// Rule 4: tests must exist and be wrapped.
for trait in declaredFamilyTraits.sorted() {
    // Locate the test directory. Per-family directories live under their own
    // dir; Common families live under Tests/.../Common.
    let standaloneTestDir = "\(testsRoot)/\(trait)"
    let commonTestDir = "\(testsRoot)/\(flatFamilyDirectory)"

    let candidateDir: String
    if isDirectory(standaloneTestDir) {
        candidateDir = standaloneTestDir
    } else if isDirectory(commonTestDir) {
        candidateDir = commonTestDir
    } else {
        fail(
            testsRoot,
            "No test directory exists for family `\(trait)` "
                + "(expected `\(standaloneTestDir)` or `\(commonTestDir)`)."
        )
        continue
    }

    let testFiles = swiftFiles(in: candidateDir)
    let matching = testFiles.filter { (($0 as NSString).lastPathComponent).contains(trait) }

    if matching.isEmpty {
        fail(
            candidateDir,
            "No test file mentions family `\(trait)` in its name. "
                + "Add a `\(trait)Tests.swift` (or similar) and wrap it in `#if \(trait)`."
        )
    }

    for file in matching where !isWrapped(filePath: file, trait: trait) {
        fail(file, "Test file for family `\(trait)` must be wrapped in `#if \(trait) ... #endif`.")
    }
}

// Rule 5: `All` umbrella must transitively enable every per-family trait.
func resolveUmbrella(_ name: String, visited: inout Set<String>) -> Set<String> {
    if visited.contains(name) { return [] }
    visited.insert(name)
    var result = Set<String>()
    for entry in umbrellas[name] ?? [] {
        if umbrellas[entry] != nil {
            result.formUnion(resolveUmbrella(entry, visited: &visited))
        } else {
            result.insert(entry)
        }
    }
    return result
}

if umbrellas["All"] != nil {
    var visited = Set<String>()
    let reachable = resolveUmbrella("All", visited: &visited)
    let missing = declaredFamilyTraits.subtracting(reachable)
    if !missing.isEmpty {
        fail(
            packageManifestPath,
            "The `All` umbrella trait does not enable: \(missing.sorted().joined(separator: ", ")). "
                + "Update `enabledTraits` so consumers using `All` get the full surface."
        )
    }
} else {
    fail(packageManifestPath, "The `All` umbrella trait is missing from Package.swift.")
}

// MARK: - Report

if failures.isEmpty {
    print("validate-traits: ok — \(declaredFamilyTraits.count) per-family traits validated.")
    exit(0)
} else {
    fputs("validate-traits: \(failures.count) violation(s):\n\n", stderr)
    for failure in failures {
        fputs("  • \(failure.location)\n      \(failure.message)\n\n", stderr)
    }
    exit(1)
}
