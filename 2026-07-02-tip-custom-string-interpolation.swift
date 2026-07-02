// Tip: custom string interpolation for cleaner debug logs
// I use this when I want richer debug output without building ad-hoc formatting helpers everywhere.
// The win is local readability: the call site stays tiny, but the formatting rules stay consistent.

import Foundation

extension String.StringInterpolation {
    mutating func appendInterpolation<T: CustomStringConvertible>(_ label: String, _ value: T?) {
        if let value {
            appendLiteral("\(label)=\(value)")
        } else {
            appendLiteral("\(label)=nil")
        }
    }

    mutating func appendInterpolation(redacting value: String) {
        appendLiteral("••••\(value.suffix(4))")
    }
}

@main
enum Demo {
    static func main() {
        let requestID: UUID? = UUID()
        let token = "user-session-secret-7F42"

        // I keep the log line focused and let interpolation handle the formatting policy.
        print("auth.start [\("requestID", requestID)] token=\(redacting: token)")
    }
}
