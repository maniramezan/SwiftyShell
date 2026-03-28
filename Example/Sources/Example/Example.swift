// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import SwiftyShell

@main
struct Example: AsyncParsableCommand {
    mutating func run() async throws {
        print(try await Ls().all(true)
            .run().stdout)
    }
}
