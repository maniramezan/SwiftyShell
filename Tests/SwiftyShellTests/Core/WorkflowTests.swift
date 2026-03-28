import Testing
@testable import SwiftyShell

struct WorkflowTests {
    @Test func mapTransform() async throws {
        let result = try await Workflow { 42 }
            .map { $0 * 2 }
            .run()
        #expect(result == 84)
    }

    @Test func mapKeyPath() async throws {
        struct Box: Sendable { var value: Int }
        let result = try await Workflow { Box(value: 7) }
            .map(\.value)
            .run()
        #expect(result == 7)
    }

    @Test func flatMap() async throws {
        let result = try await Workflow { 10 }
            .flatMap { n in Workflow { n + 5 } }
            .run()
        #expect(result == 15)
    }

    @Test func then() async throws {
        let result = try await Workflow { "hello" }
            .then { $0 + " world" }
            .run()
        #expect(result == "hello world")
    }

    @Test func requirePredicatePasses() async throws {
        let result = try await Workflow { 42 }
            .require({ $0 > 10 }, else: WorkflowTestError())
            .run()
        #expect(result == 42)
    }

    @Test func requirePredicateFails() async throws {
        do {
            _ = try await Workflow { 5 }
                .require({ $0 > 10 }, else: WorkflowTestError())
                .run()
            Issue.record("Expected error to be thrown")
        } catch is WorkflowTestError {
            // expected
        }
    }

    @Test func requireKeyPathPasses() async throws {
        struct Box: Sendable, Equatable { var value: Int }
        let result = try await Workflow { Box(value: 42) }
            .require(\.value, equals: 42, else: WorkflowTestError())
            .run()
        #expect(result == Box(value: 42))
    }

    @Test func requireKeyPathFails() async throws {
        struct Box: Sendable, Equatable { var value: Int }
        do {
            _ = try await Workflow { Box(value: 5) }
                .require(\.value, equals: 42, else: WorkflowTestError())
                .run()
            Issue.record("Expected error to be thrown")
        } catch is WorkflowTestError {
            // expected
        }
    }

    @Test func mapChaining() async throws {
        let result = try await Workflow { "hello" }
            .map { $0.uppercased() }
            .map { $0 + "!" }
            .run()
        #expect(result == "HELLO!")
    }

    @Test func propagatesError() async throws {
        do {
            _ = try await Workflow<Int> { throw WorkflowTestError() }
                .map { $0 * 2 }
                .run()
            Issue.record("Expected error to be thrown")
        } catch is WorkflowTestError {
            // expected
        }
    }
}

private struct WorkflowTestError: Error {}
