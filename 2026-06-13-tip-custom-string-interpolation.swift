/// 2026-06-13 Tip: Custom string interpolation for diagnostic logs
/// I like using string interpolation to make debug output readable without scattering formatting rules around the codebase.

import Foundation

struct NetworkTrace: CustomStringConvertible {
    let requestID: UUID
    let endpoint: String
    let latency: Duration
    let statusCode: Int

    var description: String {
        "Trace[\(requestID.uuidString.prefix(6))] \(endpoint)"
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation(trace value: NetworkTrace) {
        let milliseconds = value.latency.components.seconds * 1_000
            + value.latency.components.attoseconds / 1_000_000_000_000_000

        // I keep formatting logic here so log call sites stay compact and consistent.
        appendLiteral("\(value.description) → status=\(value.statusCode) latency=\(Int(milliseconds))ms")
    }
}

@main
enum CustomInterpolationTip {
    static func main() {
        let trace = NetworkTrace(
            requestID: UUID(uuidString: "12345678-1234-1234-1234-1234567890AB")!,
            endpoint: "/v1/feed",
            latency: .milliseconds(184),
            statusCode: 200
        )

        print("debug: \(trace: trace)")
    }
}
