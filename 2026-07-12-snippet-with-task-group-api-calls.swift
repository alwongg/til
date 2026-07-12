import Foundation

struct User: Decodable { let id: Int; let name: String }
struct FeedItem: Decodable { let id: Int; let title: String }
struct Dashboard {
    let user: User
    let feed: [FeedItem]
    let unreadCount: Int
}

enum DashboardPart {
    case user(User)
    case feed([FeedItem])
    case unreadCount(Int)
}

struct DashboardLoader {
    let fetchUser: () async throws -> User
    let fetchFeed: () async throws -> [FeedItem]
    let fetchUnreadCount: () async throws -> Int

    func load() async throws -> Dashboard {
        var user: User?
        var feed: [FeedItem] = []
        var unreadCount = 0

        try await withThrowingTaskGroup(of: DashboardPart.self) { group in
            group.addTask { .user(try await fetchUser()) }
            group.addTask { .feed(try await fetchFeed()) }
            group.addTask { .unreadCount(try await fetchUnreadCount()) }

            for try await part in group {
                switch part {
                case .user(let value): user = value
                case .feed(let value): feed = value
                case .unreadCount(let value): unreadCount = value
                }
            }
        }

        // I like this shape because each request stays independent, but the
        // call site still gets one fully assembled model for rendering.
        guard let user else { throw CocoaError(.coderValueNotFound) }
        return Dashboard(user: user, feed: feed, unreadCount: unreadCount)
    }
}
