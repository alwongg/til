import Foundation

/*
# Slot 1/4 — Swift Language Evolution
## Sendable-first API design

I used to treat concurrency safety as cleanup work after the feature was already shipping.
The modern Swift direction is the opposite: I design the boundary as Sendable first, then I fill in the implementation.

## Legacy approach
I would start with a mutable reference type, share it across tasks, and trust code review to catch race conditions.
That worked until async work spread through the app and the unsafe edges got harder to reason about.

## Modern approach
I now isolate mutable state in an actor and make dependencies explicitly Sendable.
That forces the API surface to explain how work crosses task boundaries.

## Migration strategy
1. Find shared mutable services that are touched from multiple tasks.
2. Move their storage behind an actor before adding more async features.
3. Mark protocols and lightweight dependency containers as Sendable.
4. Let compiler warnings show me where hidden sharing still exists.

## Production notes
- `Sendable` is not a style preference. It is a pressure test for whether my abstraction is actually safe to move between tasks.
- I try to keep the actor boundary small. If everything becomes one giant actor, I just replace data races with contention.
- When a type cannot honestly be Sendable, I treat that as architecture feedback, not annotation busywork.
*/

protocol ImageFetching: Sendable {
    func fetch(from url: URL) async throws -> Data
}

struct LiveImageFetcher: ImageFetching {
    func fetch(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

actor ImageCache {
    private var storage: [URL: Data] = [:]

    func value(for url: URL) -> Data? {
        storage[url]
    }

    func insert(_ data: Data, for url: URL) {
        storage[url] = data
    }
}

struct FeedImagePipeline: Sendable {
    let fetcher: any ImageFetching
    let cache: ImageCache

    func imageData(for url: URL) async throws -> Data {
        if let cached = await cache.value(for: url) {
            return cached
        }

        let data = try await fetcher.fetch(from: url)
        await cache.insert(data, for: url)
        return data
    }
}

enum MigrationStep: String, CaseIterable {
    case isolateSharedState = "Move shared mutable state behind an actor"
    case markDependencies = "Require Sendable dependencies at the boundary"
    case removeImplicitSharing = "Replace hidden singleton access with explicit injection"
}

@main
enum LessonDemo {
    static func main() async {
        let pipeline = FeedImagePipeline(fetcher: LiveImageFetcher(), cache: ImageCache())
        _ = pipeline

        for step in MigrationStep.allCases {
            print("• \(step.rawValue)")
        }
    }
}
