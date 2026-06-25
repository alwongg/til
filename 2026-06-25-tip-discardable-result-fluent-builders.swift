import Foundation

// I use `@discardableResult` when I want a fluent helper to *optionally* chain,
// but I don't want every intentional one-off call to need `_ = ...` noise.
struct RequestBuilder {
    private var headers: [String: String] = [:]
    private var requestTimeout: TimeInterval = 30

    @discardableResult
    mutating func header(_ key: String, _ value: String) -> Self {
        headers[key] = value
        return self
    }

    @discardableResult
    mutating func timeout(_ seconds: TimeInterval) -> Self {
        requestTimeout = seconds
        return self
    }

    func build(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
}

@main
enum Demo {
    static func main() {
        var builder = RequestBuilder()
        builder.header("Accept", "application/json")

        let request = builder
            .timeout(15)
            .build(url: URL(string: "https://example.com/me")!)

        print(request.value(forHTTPHeaderField: "Accept") ?? "missing")
        print(request.timeoutInterval)
    }
}
