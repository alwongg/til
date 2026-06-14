import Foundation

// I use Endpoint to keep each request self-contained and easy to fan out in parallel.
struct Endpoint<Response: Sendable>: Sendable {
    let name: String
    let load: @Sendable () async throws -> Response
}

enum BatchLoader {
    static func fetchAll<Response: Sendable>(
        _ endpoints: [Endpoint<Response>]
    ) async throws -> [String: Response] {
        try await withThrowingTaskGroup(of: (String, Response).self) { group in
            for endpoint in endpoints {
                group.addTask {
                    // The task returns a tiny tuple so the group stays cheap to coordinate.
                    (endpoint.name, try await endpoint.load())
                }
            }

            var results: [String: Response] = [:]
            for try await (name, response) in group {
                // I key by feature name so partial refreshes are easy to diff upstream.
                results[name] = response
            }
            return results
        }
    }
}

@main
struct Demo {
    static func main() async {
        let endpoints = [
            Endpoint(name: "profile") { "Ada" },
            Endpoint(name: "tier") { "pro" },
            Endpoint(name: "region") { "ca-central" }
        ]

        do {
            let snapshot = try await BatchLoader.fetchAll(endpoints)
            assert(snapshot.keys.count == 3)
            _ = snapshot
        } catch {
            assertionFailure("Batch fetch failed: \(error)")
        }
    }
}
