import Foundation

// I use defer when a resource must be released on every exit path.
final class ActivityIndicator {
    private(set) var isAnimating = false

    func start() { isAnimating = true }
    func stop() { isAnimating = false }
}

enum ProfileError: Error {
    case unavailable
}

struct ProfileLoader {
    let indicator: ActivityIndicator

    func loadProfile(id: UUID) async throws -> String {
        indicator.start()
        defer { indicator.stop() }

        // Early throws stay safe as this method grows more validation branches.
        guard id.uuidString.isEmpty == false else {
            throw ProfileError.unavailable
        }

        try await Task.sleep(for: .milliseconds(10))
        return "Profile \(id.uuidString.prefix(8))"
    }
}

@main
struct Demo {
    static func main() async {
        let indicator = ActivityIndicator()
        let loader = ProfileLoader(indicator: indicator)
        _ = try? await loader.loadProfile(id: UUID())
        precondition(indicator.isAnimating == false)
    }
}
