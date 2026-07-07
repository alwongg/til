import Foundation

// I use withThrowingTaskGroup when a screen needs a few independent requests
// and I want failure + cancellation semantics to stay explicit.
// The important part is returning typed results from each child task instead of
// reaching for shared mutable state.

struct User: Decodable {}
struct Stats: Decodable {}
struct Activity: Decodable {}

struct DashboardData {
    let user: User
    let stats: Stats
    let activity: [Activity]
}

enum DashboardPiece {
    case user(User)
    case stats(Stats)
    case activity([Activity])
}

struct DashboardAPI {
    let session: URLSession = .shared

    func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func loadDashboard(userURL: URL, statsURL: URL, activityURL: URL) async throws -> DashboardData {
        try await withThrowingTaskGroup(of: DashboardPiece.self) { group in
            group.addTask { .user(try await fetch(User.self, from: userURL)) }
            group.addTask { .stats(try await fetch(Stats.self, from: statsURL)) }
            group.addTask { .activity(try await fetch([Activity].self, from: activityURL)) }

            var user: User?
            var stats: Stats?
            var activity: [Activity] = []

            for try await piece in group {
                switch piece {
                case .user(let value): user = value
                case .stats(let value): stats = value
                case .activity(let value): activity = value
                }
            }

            guard let user, let stats else {
                throw URLError(.badServerResponse)
            }

            return DashboardData(user: user, stats: stats, activity: activity)
        }
    }
}
