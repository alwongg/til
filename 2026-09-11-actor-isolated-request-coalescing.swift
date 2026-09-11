// Production Pattern: Actor-Isolated Request Coalescing
//
// I use this when several SwiftUI views can ask for the same resource at once.
// The actor owns cache and in-flight state, so duplicate requests become one task.

import Foundation

actor DataLoader {
    private var cache: [URL: Data] = [:]
    private var inFlight: [URL: Task<Data, Error>] = [:]

    func data(for url: URL) async throws -> Data {
        if let cached = cache[url] {
            return cached
        }

        if let existing = inFlight[url] {
            return try await existing.value
        }

        let task = Task<Data, Error> {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                throw URLError(.badServerResponse)
            }
            return data
        }
        inFlight[url] = task

        do {
            let result = try await task.value
            cache[url] = result
            inFlight[url] = nil
            return result
        } catch {
            // Failed work must not poison future retries.
            inFlight[url] = nil
            throw error
        }
    }

    func invalidate(_ url: URL) {
        cache[url] = nil
    }
}

@main
struct Demo {
    static func main() async {
        let loader = DataLoader()
        let url = URL(string: "https://example.com/avatar.png")!
        async let first = loader.data(for: url)
        async let second = loader.data(for: url)
        _ = try? await (first, second)
    }
}

/*
# Coalesce duplicate network work with an actor

## The legacy shape
I used to put an `NSCache` next to a networking service and call it finished. Under SwiftUI, two views can appear in the same render pass, both miss the cache, and both start identical requests. The bug is expensive, intermittent, and invisible in happy-path testing.

## The modern shape
I keep both completed values and in-flight `Task`s inside an actor. The first caller creates the work; later callers await that same task. Actor isolation makes the check-and-insert sequence atomic without serial queues or locks.

## Migration strategy
1. Start with one high-fan-out endpoint such as avatars, product images, or configuration.
2. Keep the loader behind a protocol so feature code does not learn about its cache policy.
3. Add memory limits, TTLs, and observability only after request coalescing is measured.
4. Define invalidation at the domain boundary—for example, after an avatar upload succeeds.

## Production notes
- Never retain failed tasks: every retry must get a fresh request.
- Cache decoded images separately from raw `Data` when decoding is the bottleneck.
- Inject the transport in tests to verify that concurrent callers produce one request.
- Decide explicitly whether one caller's cancellation should cancel shared work. For shared resources, I usually let the work finish for remaining waiters.
*/
