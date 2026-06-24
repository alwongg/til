import Foundation

struct User: Decodable { let id: Int; let name: String }
struct Project: Decodable { let id: Int; let title: String }
struct NotificationItem: Decodable { let id: Int; let body: String }

struct DashboardData {
    let user: User
    let projects: [Project]
    let notifications: [NotificationItem]
}

struct APIClient {
    let session: URLSession = .shared

    func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func loadDashboard() async throws -> DashboardData {
        let userURL = URL(string: "https://example.com/user")!
        let projectsURL = URL(string: "https://example.com/projects")!
        let notificationsURL = URL(string: "https://example.com/notifications")!

        enum PartialResult {
            case user(User)
            case projects([Project])
            case notifications([NotificationItem])
        }

        return try await withThrowingTaskGroup(of: PartialResult.self) { group in
            group.addTask { .user(try await fetch(User.self, from: userURL)) }
            group.addTask { .projects(try await fetch([Project].self, from: projectsURL)) }
            group.addTask { .notifications(try await fetch([NotificationItem].self, from: notificationsURL)) }

            var user: User?
            var projects: [Project] = []
            var notifications: [NotificationItem] = []

            for try await result in group {
                switch result {
                case .user(let value): user = value
                case .projects(let value): projects = value
                case .notifications(let value): notifications = value
                }
            }

            guard let user else { throw URLError(.cannotParseResponse) }
            return DashboardData(user: user, projects: projects, notifications: notifications)
        }
    }
}

@main
enum Demo {
    static func main() async {
        let client = APIClient()
        do {
            let dashboard = try await client.loadDashboard()
            print("Loaded \(dashboard.projects.count) projects for \(dashboard.user.name)")
        } catch {
            print("Failed to load dashboard: \(error)")
        }
    }
}
