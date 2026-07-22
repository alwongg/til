// iOS Tip: Make Fluent Mutations Intentional with @discardableResult
//
// I use @discardableResult when a method has a useful return value but callers
// should be free to ignore it. It keeps fluent setup ergonomic without hiding
// an accidental ignored result behind a compiler warning.

import Foundation

final class Request {
    private(set) var headers: [String: String] = [:]
    private(set) var timeout: TimeInterval = 30

    @discardableResult
    func setHeader(_ value: String, for field: String) -> Self {
        headers[field] = value
        return self
    }

    @discardableResult
    func setTimeout(_ seconds: TimeInterval) -> Self {
        timeout = seconds
        return self
    }
}

@main
struct Demo {
    static func main() {
        let request = Request()
        request
            .setHeader("application/json", for: "Accept")
            .setTimeout(15)

        // I can also ignore the returned value when mutation is the only goal.
        request.setHeader("Bearer token", for: "Authorization")

        print(request.headers["Accept"] ?? "missing")
    }
}
