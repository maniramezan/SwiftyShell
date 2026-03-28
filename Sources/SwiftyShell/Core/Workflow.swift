import Foundation

/// A reusable asynchronous workflow that can be transformed and composed.
public struct Workflow<Value>: Sendable {
    private let operation: @Sendable () async throws -> Value

    /// Creates a workflow from an async throwing operation.
    public init(_ operation: @escaping @Sendable () async throws -> Value) {
        self.operation = operation
    }

    /// Runs the workflow and returns its value.
    public consuming func run() async throws -> Value {
        try await operation()
    }

    /// Maps the workflow output using a synchronous transform.
    public func map<T>(
        _ transform: @escaping @Sendable (Value) throws -> T
    ) -> Workflow<T> {
        let op = operation
        return Workflow<T> {
            try transform(try await op())
        }
    }

    /// Maps the workflow output using a key path.
    public func map<T>(_ keyPath: KeyPath<Value, T>) -> Workflow<T> {
        let keyPath = SendableKeyPath(keyPath)
        return map { $0[keyPath: keyPath.value] }
    }

    /// Chains the workflow into another workflow.
    public func flatMap<T>(
        _ transform: @escaping @Sendable (Value) async throws -> Workflow<T>
    ) -> Workflow<T> {
        let op = operation
        return Workflow<T> {
            let value = try await op()
            return try await transform(value).run()
        }
    }

    /// Runs an additional async transform after the workflow succeeds.
    public func then<T>(
        _ next: @escaping @Sendable (Value) async throws -> T
    ) -> Workflow<T> {
        let op = operation
        return Workflow<T> {
            let value = try await op()
            return try await next(value)
        }
    }

    /// Requires the workflow output to satisfy a predicate.
    public func require(
        _ predicate: @escaping @Sendable (Value) throws -> Bool,
        else error: @autoclosure @escaping @Sendable () -> Error
    ) -> Workflow<Value> {
        let op = operation
        return Workflow<Value> {
            let value = try await op()
            guard try predicate(value) else {
                throw error()
            }
            return value
        }
    }

    /// Requires a key path on the workflow output to equal an expected value.
    public func require<T: Equatable & Sendable>(
        _ keyPath: KeyPath<Value, T>,
        equals expected: T,
        else error: @autoclosure @escaping @Sendable () -> Error
    ) -> Workflow<Value> {
        let keyPath = SendableKeyPath(keyPath)
        return require({ $0[keyPath: keyPath.value] == expected }, else: error())
    }
}

private struct SendableKeyPath<Root, Value>: @unchecked Sendable {
    let value: KeyPath<Root, Value>

    init(_ value: KeyPath<Root, Value>) {
        self.value = value
    }
}
