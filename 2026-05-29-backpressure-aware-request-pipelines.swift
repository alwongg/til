// Friday: From Fire-and-Forget Fetches to a Backpressure-Aware Request Pipeline
//
// I hit this pattern when an app scales past a couple of happy-path screens.
// The legacy version usually works in development, then production traffic exposes
// duplicate requests, race conditions, and wasted battery when the same resource
// gets fetched from multiple entry points.
//
// The transformation is not "use async/await everywhere".
// It's: centralize request ownership, deduplicate in-flight work, and make
// cancellation a first-class behavior.

import Foundation

struct FeedItem: Decodable, Sendable, Identifiable {
    let id: UUID
    let title: String
}

protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

// MARK: - Legacy approach
//
// What I see in older codebases:
// - each caller creates its own Task
// - no deduplication when the same endpoint is requested twice
// - no shared retry policy or response validation
// - cancellation is local, so upstream features can still keep redundant work alive
//
// final class FeedService {
//     func loadFeed() async throws -> [FeedItem] {
//         let url = URL(string: "https://example.com/feed")!
//         let (data, _) = try await URLSession.shared.data(from: url)
//         return try JSONDecoder().decode([FeedItem].self, from: data)
//     }
// }
//
// This is fine for a demo. It gets noisy in production once search, refresh,
// home widgets, and background warmup all hit the same data source.

// MARK: - Modern approach
//
// I prefer an actor that owns in-flight work. That gives me one place to
// deduplicate requests and one place to reason about lifecycle.

actor FeedRepository {
    private let client: HTTPClient
    private let decoder: JSONDecoder
    private var inFlight: [URL: Task<[FeedItem], Error>] = [:]

    init(client: HTTPClient, decoder: JSONDecoder = JSONDecoder()) {
        self.client = client
        self.decoder = decoder
    }

    func loadFeed(for url: URL) async throws -> [FeedItem] {
        if let existingTask = inFlight[url] {
            return try await existingTask.value
        }

        let task = Task<[FeedItem], Error> {
            defer { Task { await self.removeTask(for: url) }() }

            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.cachePolicy = .reloadRevalidatingCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await client.data(for: request)
            try Self.validate(response: response)
            return try decoder.decode([FeedItem].self, from: data)
        }

        inFlight[url] = task
        return try await task.value
    }

    func cancelLoad(for url: URL) {
        inFlight[url]?.cancel()
        inFlight[url] = nil
    }

    private func removeTask(for url: URL) {
        inFlight[url] = nil
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw RepositoryError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw RepositoryError.httpStatus(http.statusCode)
        }
    }
}

enum RepositoryError: Error {
    case invalidResponse
    case httpStatus(Int)
}

// MARK: - Migration strategy
//
// How I usually move a production app without blowing up risk:
// 1. Keep the view models unchanged and replace only the service dependency.
// 2. Route the highest-volume endpoint through the repository first.
// 3. Add metrics around duplicate request reduction and cancellation rate.
// 4. Move retry and cache semantics into the repository only after ownership is clear.
//
// The key is that the architecture shift comes before policy layering.
// If I add retries before deduplication, I can accidentally amplify load.

@main
struct DemoApp {
    static func main() async {
        let repository = FeedRepository(client: URLSessionHTTPClient())
        let url = URL(string: "https://example.com/feed")!

        await withTaskGroup(of: Void.self) { group in
            for index in 1...3 {
                group.addTask {
                    do {
                        let items = try await repository.loadFeed(for: url)
                        print("Caller \(index) received \(items.count) items")
                    } catch {
                        print("Caller \(index) failed: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Production notes
//
// A few things I care about in the real app:
// - If different callers need different auth headers, the request identity cannot be URL-only.
// - I keep actor-owned state small. Large caches belong in a dedicated cache layer.
// - Cancellation should be product-aware. A background refresh may deserve different treatment
//   than a user-driven pull-to-refresh.
// - If I need retries, I add them around the transport boundary with jitter, not inside the UI.
//
// The practical win is boring reliability: fewer duplicate requests, cleaner logs,
// and less "why did this screen trigger the same endpoint four times?" debugging.
