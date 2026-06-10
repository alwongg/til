/// 2026-06-10 Tip: Prefer compactMap over filter + map
/// I use compactMap when validation and transformation happen together.
/// It keeps the pipeline single-pass and removes force unwrap pressure.

import Foundation

struct APIUser: Decodable {
    let id: Int?
    let email: String?
}

struct UserSummary: CustomStringConvertible {
    let id: Int
    let email: String
    var description: String { "\(id): \(email)" }
}

enum UserMapper {
    static func summaries(from payload: [APIUser]) -> [UserSummary] {
        payload.compactMap { user in
            guard let id = user.id,
                  let email = user.email?.lowercased(),
                  !email.isEmpty else {
                return nil
            }
            return UserSummary(id: id, email: email)
        }
    }

    static func legacySummaries(from payload: [APIUser]) -> [UserSummary] {
        payload
            .filter { $0.id != nil && !($0.email?.isEmpty ?? true) }
            .map { UserSummary(id: $0.id!, email: $0.email!.lowercased()) }
    }
}

@main
struct Demo {
    static func main() {
        let payload = [
            APIUser(id: 1, email: "ALEX@EXAMPLE.COM"),
            APIUser(id: nil, email: "skip@example.com"),
            APIUser(id: 2, email: nil)
        ]

        let summaries = UserMapper.summaries(from: payload)
        precondition(summaries.count == 1)
        print(summaries[0])
    }
}
