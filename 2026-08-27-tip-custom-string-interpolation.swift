// iOS Tip: Custom String Interpolation for Safe, Readable Logs
//
// I use custom interpolation to make sensitive values explicit at the call site.
// The default is redaction, so adding a new field to a log statement is safer.

import Foundation

struct RedactedLog: ExpressibleByStringInterpolation, CustomStringConvertible {
    private var value = ""

    init(stringLiteral value: String) {
        self.value = value
    }

    init(stringInterpolation: StringInterpolation) {
        value = stringInterpolation.output
    }

    var description: String { value }

    struct StringInterpolation: StringInterpolationProtocol {
        var output = ""

        init(literalCapacity: Int, interpolationCount: Int) {
            output.reserveCapacity(literalCapacity)
        }

        mutating func appendLiteral(_ literal: String) {
            output += literal
        }

        mutating func appendInterpolation<T>(_ value: T) {
            output += "<redacted>"
        }

        mutating func appendInterpolation<T>(_ value: T, public isPublic: Bool) {
            output += isPublic ? String(describing: value) : "<redacted>"
        }
    }
}

@main
struct Demo {
    static func main() {
        let userID = "u_123"
        let email = "alex@example.com"
        let message: RedactedLog = "Sync started for user=\(userID, public: true), email=\(email)"
        print(message) // Sync started for user=u_123, email=<redacted>
    }
}
