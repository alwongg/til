import Foundation

// I use `compactMap` when a transformation can legitimately fail.
// It keeps the intent in one pass: invalid values disappear while valid ones
// become the shape the rest of my code actually wants to consume.
struct RawUser {
    let id: String
    let favoriteNumber: String?
}

struct UserSummary: CustomStringConvertible {
    let id: String
    let favoriteNumber: Int

    var description: String {
        "\(id): \(favoriteNumber)"
    }
}

func summaries(from raws: [RawUser]) -> [UserSummary] {
    raws.compactMap { raw in
        guard let favoriteNumber = raw.favoriteNumber,
              let parsed = Int(favoriteNumber) else {
            // I drop bad input at the boundary so downstream code stays boring.
            return nil
        }

        return UserSummary(id: raw.id, favoriteNumber: parsed)
    }
}

@main
struct Demo {
    static func main() {
        let raws = [
            RawUser(id: "u1", favoriteNumber: "7"),
            RawUser(id: "u2", favoriteNumber: nil),
            RawUser(id: "u3", favoriteNumber: "not-a-number"),
            RawUser(id: "u4", favoriteNumber: "42")
        ]

        let result = summaries(from: raws)
        result.forEach { print($0) }
    }
}
