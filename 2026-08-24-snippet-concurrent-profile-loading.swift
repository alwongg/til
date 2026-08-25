import Foundation

/// I use a task group when a screen needs independent resources at the same time.
/// The group gives me structured concurrency: this function does not return until
/// every child task has either completed or propagated its failure.
func loadDashboard() async throws -> [String] {
    try await withThrowingTaskGroup(of: String.self, returning: [String].self) { group in
        for resource in ["profile", "inbox", "recommendations"] {
            group.addTask {
                try await fetch(resource)
            }
        }

        var values: [String] = []
        for try await value in group {
            values.append(value)
        }
        return values
    }
}

private func fetch(_ resource: String) async throws -> String {
    // This stands in for an independent API request.
    try await Task.sleep(nanoseconds: 100_000_000)
    return "Loaded \(resource)"
}

@main
struct ConcurrentLoadingDemo {
    static func main() async {
        do {
            let dashboard = try await loadDashboard()
            print(dashboard)
        } catch {
            // A real screen maps this to one user-facing loading state.
            print("Dashboard load failed: \(error)")
        }
    }
}
