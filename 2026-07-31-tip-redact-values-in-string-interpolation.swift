import Foundation

struct AccountSnapshot {
    let id: UUID
    let email: String
    let isPremium: Bool
}

extension String.StringInterpolation {
    mutating func appendInterpolation(redacting value: String?) {
        appendLiteral(value.map { "<redacted:\($0.count) chars>" } ?? "nil")
    }

    mutating func appendInterpolation(_ snapshot: AccountSnapshot, debug: Bool) {
        appendLiteral("AccountSnapshot(id: \(snapshot.id), email: ")
        appendInterpolation(redacting: snapshot.email)
        appendLiteral(", premium: \(snapshot.isPremium))")
    }
}

func log(_ snapshot: AccountSnapshot) {
    // I keep the call site expressive while making accidental PII logging harder.
    let message = "Loaded \(snapshot, debug: true)"
    print(message)
}

@main
struct Demo {
    static func main() {
        log(AccountSnapshot(id: UUID(), email: "alex@example.com", isPremium: true))
    }
}
