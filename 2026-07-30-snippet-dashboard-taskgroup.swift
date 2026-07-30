// Swift Snippet: Load independent resources concurrently
// I use this when a screen needs several independent inputs before it can render.

import Foundation

struct Profile: Sendable { let name: String }
struct Feed: Sendable { let items: [String] }
struct BadgeCount: Sendable { let value: Int }

enum DashboardError: Error { case missingProfile }

protocol DashboardAPI: Sendable {
    func profile() async throws -> Profile
    func feed() async throws -> Feed
    func badgeCount() async throws -> BadgeCount
}

struct Dashboard: Sendable {
    let profile: Profile
    let feed: Feed
    let badgeCount: BadgeCount
}

func loadDashboard(using api: some DashboardAPI) async throws -> Dashboard {
    // These requests do not depend on one another, so serial awaits only add latency.
    async let profile = api.profile()
    async let feed = api.feed()
    async let badgeCount = api.badgeCount()

    // Awaiting this tuple preserves typed results and cancels sibling work on failure.
    return try await Dashboard(
        profile: profile,
        feed: feed,
        badgeCount: badgeCount
    )
}
