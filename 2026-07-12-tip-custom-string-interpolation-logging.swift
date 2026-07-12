import Foundation

// I use custom string interpolation when I want logs to stay readable
// while still enforcing formatting and redaction rules in one place.
struct NetworkRequest {
    let method: String
    let path: String
    let token: String
    let duration: TimeInterval
}

struct DebugLine: ExpressibleByStringInterpolation, CustomStringConvertible {
    struct StringInterpolation: StringInterpolationProtocol {
        var output = ""

        init(literalCapacity: Int, interpolationCount: Int) {
            output.reserveCapacity(literalCapacity + interpolationCount * 12)
        }

        mutating func appendLiteral(_ literal: String) { output += literal }
        mutating func appendInterpolation<T>(_ value: T) { output += String(describing: value) }
        mutating func appendInterpolation(redacting value: String) { output += value.prefix(4) + "••••" }
        mutating func appendInterpolation(milliseconds value: TimeInterval) {
            output += String(format: "%.0fms", value * 1_000)
        }
    }

    let description: String

    init(stringLiteral value: String) { description = value }
    init(stringInterpolation: StringInterpolation) { description = stringInterpolation.output }
}

@main
struct Demo {
    static func main() {
        let request = NetworkRequest(method: "GET", path: "/v1/feed", token: "abcd1234secret", duration: 0.184)
        let line: DebugLine = "[HTTP] \(request.method) \(request.path) token=\(redacting: request.token) duration=\(milliseconds: request.duration)"
        print(line)
    }
}
