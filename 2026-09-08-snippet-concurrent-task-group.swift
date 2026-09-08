// Swift Snippet: Bound concurrent work with a throwing task group
//
// I use this shape when a screen needs several independent resources. I keep
// ownership in one async boundary: a failure cancels outstanding work instead
// of letting half-updated UI escape into the app.

import Foundation

enum BatchLoadError: Error {
    case missingResult
}

func loadConcurrently<Value: Sendable>(
    _ operations: [@Sendable () async throws -> Value]
) async throws -> [Value] {
    try await withThrowingTaskGroup(of: (Int, Value).self) { group in
        for (index, operation) in operations.enumerated() {
            group.addTask {
                (index, try await operation())
            }
        }

        var ordered = Array<Value?>(repeating: nil, count: operations.count)
        for try await (index, value) in group {
            // Task groups finish in completion order; the index preserves UI order.
            ordered[index] = value
        }

        return try ordered.map { value in
            guard let value else { throw BatchLoadError.missingResult }
            return value
        }
    }
}
