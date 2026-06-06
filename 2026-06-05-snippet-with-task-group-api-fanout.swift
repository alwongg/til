// I use withThrowingTaskGroup when a screen needs multiple independent resources at once.
import Foundation

struct Endpoint<T: Decodable> {
    let url: URL
}

struct DashboardPayload: Decodable {
    let profile: Profile
    let notifications: [NotificationItem]
    let stats: Stats
}

struct Profile: Decodable { let name: String }
struct NotificationItem: Decodable { let id: UUID; let message: String }
struct Stats: Decodable { let streak: Int }

func fetch<T: Decodable>(_ endpoint: Endpoint<T>) async throws -> T {
    let (data, _) = try await URLSession.shared.data(from: endpoint.url)
    return try JSONDecoder().decode(T.self, from: data)
}

func loadDashboard(profile: Endpoint<Profile>, notifications: Endpoint<[NotificationItem]>, stats: Endpoint<Stats>) async throws -> DashboardPayload {
    var loadedProfile: Profile?
    var loadedNotifications: [NotificationItem]?
    var loadedStats: Stats?

    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask { loadedProfile = try await fetch(profile) }
        group.addTask { loadedNotifications = try await fetch(notifications) }
        group.addTask { loadedStats = try await fetch(stats) }

        // I let the first thrown error cancel sibling work so the screen never mixes fresh and stale data.
        try await group.waitForAll()
    }

    return DashboardPayload(
        profile: loadedProfile!,
        notifications: loadedNotifications!,
        stats: loadedStats!
    )
}
