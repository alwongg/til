import Foundation

/*
# Production Patterns at Scale: Request Coalescing for Feed Loads

## Legacy approach
I used to let every caller fire its own network request. It looked harmless in isolated view models,
but once multiple screens, refresh triggers, and background prefetching all asked for the same page,
I paid for it with duplicated work, harder-to-read logs, and extra backend pressure.

## Modern approach
I now use an actor as a request coalescer. The first caller creates the task. Everyone else awaiting the
same key joins that task instead of starting a new one. I get one source of truth for in-flight work,
fewer race conditions, and a natural place to add cancellation, metrics, or caching later.

## Migration strategy
I do not rewrite the whole data layer at once. I wrap the noisy endpoints first — feed loads, config fetches,
image prewarming, token refreshes — then push the coalescer behind repository boundaries so feature code stays simple.

## Production notes
- Key by the real unit of work: page, endpoint + params, or user/session scope.
- Keep coalescing separate from caching. One controls in-flight work; the other controls reuse after completion.
- Instrument hit rate. If almost nothing coalesces, the abstraction may be in the wrong place.
- Be explicit about cancellation semantics before sharing tasks across multiple callers.
*/

actor RequestCoalescer<Key: Hashable & Sendable, Value: Sendable> {
    private var inFlight: [Key: Task<Value, Error>] = [:]

    func value(
        for key: Key,
        start: @Sendable @escaping () async throws -> Value
    ) async throws -> Value {
        if let existing = inFlight[key] {
            return try await existing.value
        }

        let task = Task {
            try await start()
        }
        inFlight[key] = task
        defer { inFlight[key] = nil }

        return try await task.value
    }
}

actor FeedService {
    private var fetchCount = 0

    func fetchPage(_ page: Int) async throws -> [String] {
        fetchCount += 1
        try await Task.sleep(nanoseconds: 150_000_000)
        return ["page-\(page)-item-1", "page-\(page)-item-2"]
    }

    func currentFetchCount() -> Int {
        fetchCount
    }
}

@main
struct Demo {
    static func main() async throws {
        let coalescer = RequestCoalescer<Int, [String]>()
        let service = FeedService()

        async let first = coalescer.value(for: 1) {
            try await service.fetchPage(1)
        }

        async let second = coalescer.value(for: 1) {
            try await service.fetchPage(1)
        }

        let (left, right) = try await (first, second)
        let fetchCount = await service.currentFetchCount()

        print(left == right)
        print(fetchCount)
    }
}
