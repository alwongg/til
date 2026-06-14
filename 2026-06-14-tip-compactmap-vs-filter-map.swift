import Foundation

struct User: Decodable {
    let id: Int
    let username: String?
}

enum UserNameExtractor {
    static func displayNames(from users: [User]) -> [String] {
        // I use compactMap when filtering nils and transforming in one pass.
        // It keeps the intent obvious and avoids building an intermediate array.
        users.compactMap { user in
            guard let username = user.username?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !username.isEmpty else {
                return nil
            }
            return username.lowercased()
        }
    }

    static func legacyDisplayNames(from users: [User]) -> [String] {
        // filter + map is still fine, but it splits one idea across two passes.
        users
            .filter { ($0.username?.isEmpty == false) }
            .map { $0.username!.lowercased() }
    }
}

@main
struct Demo {
    static func main() {
        let users = [
            User(id: 1, username: "Alex"),
            User(id: 2, username: nil),
            User(id: 3, username: "  Mochi  ")
        ]

        _ = UserNameExtractor.displayNames(from: users)
    }
}
