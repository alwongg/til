import Foundation

// 2026-05-25 — Swift Snippet
// Title: withThrowingTaskGroup for concurrent API calls
//
// When I have a few independent requests, I prefer a task group over hand-managed counters.
// It keeps failure propagation and result collection in one place.

struct Endpoint: Hashable {
    let name: String
    let url: URL
}

func fetch(_ endpoint: Endpoint) async throws -> (String, Int) {
    let (_, response) = try await URLSession.shared.data(from: endpoint.url)
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
    return (endpoint.name, statusCode)
}

func loadStatuses(for endpoints: [Endpoint]) async throws -> [String: Int] {
    try await withThrowingTaskGroup(of: (String, Int).self) { group in
        for endpoint in endpoints {
            group.addTask {
                try await fetch(endpoint)
            }
        }

        var statuses: [String: Int] = [:]
        for try await (name, statusCode) in group {
            // I collect results as they finish so slow requests do not block faster ones.
            statuses[name] = statusCode
        }
        return statuses
    }
}

@main
struct DemoApp {
    static func main() async {
        let endpoints = [
            Endpoint(name: "posts", url: URL(string: "https://jsonplaceholder.typicode.com/posts")!),
            Endpoint(name: "users", url: URL(string: "https://jsonplaceholder.typicode.com/users")!),
        ]

        do {
            print(try await loadStatuses(for: endpoints))
        } catch {
            print("Request batch failed: \(error)")
        }
    }
}
