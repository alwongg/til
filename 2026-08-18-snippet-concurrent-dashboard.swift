import Foundation

// I use async let when a screen needs a fixed, small set of independent values.
// If either request fails, Swift cancels its sibling rather than letting stale work run on.
struct Dashboard: Sendable {
    let profileName: String
    let unreadCount: Int
}

enum DashboardService {
    static func load() async throws -> Dashboard {
        async let profileName = fetchProfileName()
        async let unreadCount = fetchUnreadCount()

        return try await Dashboard(
            profileName: profileName,
            unreadCount: unreadCount
        )
    }

    private static func fetchProfileName() async throws -> String {
        try await Task.sleep(for: .milliseconds(80))
        return "Alex"
    }

    private static func fetchUnreadCount() async throws -> Int {
        try await Task.sleep(for: .milliseconds(40))
        return 3
    }
}

@main
struct Demo {
    static func main() async {
        do {
            let dashboard = try await DashboardService.load()
            print("\(dashboard.profileName): \(dashboard.unreadCount) unread")
        } catch is CancellationError {
            // Cancellation is control flow; I avoid showing it as a user-facing error.
        } catch {
            print("Could not load dashboard: \(error)")
        }
    }
}
