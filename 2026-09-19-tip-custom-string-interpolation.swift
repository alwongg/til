# Make debug logs legible with custom string interpolation

When I am diagnosing a state transition, I want one compact log line—not a pile of optional unwrapping and formatting at every call site. A small interpolation extension keeps the presentation rule next to the type while leaving the model itself unchanged.

```swift
import Foundation

struct RequestContext {
    let requestID: UUID
    let userID: String?
    let attempt: Int
}

extension String.StringInterpolation {
    mutating func appendInterpolation(_ context: RequestContext) {
        let user = context.userID ?? "anonymous"
        appendLiteral("request=\(context.requestID.uuidString.prefix(8)) user=\(user) attempt=\(context.attempt)")
    }
}

@main
struct Demo {
    static func main() {
        let context = RequestContext(requestID: UUID(), userID: nil, attempt: 2)
        print("Retrying \(context)")
    }
}
```

I use this for diagnostics, analytics labels, and internal tooling—not user-facing copy. The interpolation is intentionally deterministic: it redacts absent identity into `anonymous` and shortens the request ID. For sensitive models, I make redaction the default here rather than trusting every future log call site to remember it.