// Quick Concept: Make time a dependency, not a global
//
// I reach for Date.now by default, but it quietly makes expiry, cooldown, and
// “today” behaviour hard to test. A small Clock protocol lets production own
// real time while tests own a deterministic timeline.
//
// Legacy approach
// Date.now is read directly inside the feature. Tests then need sleeps, broad
// assertions, or fragile date construction.
//
// Modern approach
// Inject a tiny source of time at the boundary. The domain code asks for “now”
// without knowing where it comes from.

import Foundation

protocol DateProviding: Sendable {
    var now: Date { get }
}

struct SystemDateProvider: DateProviding {
    var now: Date { .now }
}

struct FixedDateProvider: DateProviding {
    let now: Date
}

struct ExpiringValue<Value>: Sendable where Value: Sendable {
    let value: Value
    let expiresAt: Date

    func isValid(using clock: some DateProviding) -> Bool {
        // Equality is expired: callers never get one ambiguous boundary tick.
        clock.now < expiresAt
    }
}

@main
struct Demo {
    static func main() {
        let expiry = Date(timeIntervalSince1970: 1_000)
        let cache = ExpiringValue(value: "profile", expiresAt: expiry)

        let beforeExpiry = FixedDateProvider(
            now: Date(timeIntervalSince1970: 999)
        )
        let atExpiry = FixedDateProvider(now: expiry)

        assert(cache.isValid(using: beforeExpiry))
        assert(!cache.isValid(using: atExpiry))
    }
}

// Migration strategy
// 1. Add DateProviding at the feature boundary.
// 2. Pass it into the smallest unit that makes a time-based decision.
// 3. Use FixedDateProvider in tests to cover before/at/after expiry exactly.
//
// Production note
// Keep the protocol narrow. If I need sleeps, timers, or scheduling, I graduate
// to Swift's Clock APIs instead of growing this into a vague “utilities” type.
