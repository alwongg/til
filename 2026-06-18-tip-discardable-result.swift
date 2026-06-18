import Foundation

final class RequestBuilder {
    private(set) var headers: [String: String] = [:]

    @discardableResult
    func header(_ key: String, _ value: String) -> Self {
        // I mark builder-style mutations as discardable when the side effect is the real win.
        // That lets me keep call sites clean without sprinkling `_ =` everywhere.
        headers[key] = value
        return self
    }
}

@main
struct Demo {
    static func main() {
        let builder = RequestBuilder()

        builder.header("Authorization", "Bearer token")
        builder.header("Accept", "application/json")

        let chained = builder
            .header("User-Agent", "til-client")
            .header("X-Trace-ID", UUID().uuidString)

        print("builder headers:", builder.headers)
        print("same instance:", builder === chained)
    }
}
