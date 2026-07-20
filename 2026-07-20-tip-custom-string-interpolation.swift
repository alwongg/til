// I make logs searchable by teaching string interpolation one domain-specific value.
// This keeps call sites readable and avoids ad-hoc, inconsistently formatted strings.

struct RequestContext: Sendable {
    let method: String
    let path: String
    let statusCode: Int
    let requestID: String
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ context: RequestContext) {
        appendLiteral("[\(context.requestID)] \(context.method) \(context.path) → \(context.statusCode)")
    }
}

@main
enum Demo {
    static func main() {
        let context = RequestContext(
            method: "GET",
            path: "/v1/profile",
            statusCode: 200,
            requestID: "a4f9"
        )

        // I get a consistent log format without sacrificing the familiar API.
        let message = "Network request \(context)"
        print(message)
    }
}
