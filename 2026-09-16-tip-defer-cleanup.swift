// # iOS Tip: Use `defer` to make cleanup survive every exit path
//
// I reach for `defer` when acquiring a resource and releasing it must not depend
// on remembering every return or throw. Keeping acquisition and cleanup adjacent
// makes the critical section easy to audit during review.

import Foundation

final class RefreshGate {
    private let lock = NSLock()

    func perform<Value>(_ work: () throws -> Value) rethrows -> Value {
        lock.lock()
        defer {
            // This runs for a normal return and for every thrown error.
            lock.unlock()
        }

        return try work()
    }
}

enum RefreshError: Error {
    case offline
}

func loadCachedProfile(using gate: RefreshGate, isOnline: Bool) throws -> String {
    try gate.perform {
        guard isOnline else { throw RefreshError.offline }
        return "cached-profile"
    }
}

// `defer` is not a substitute for structured concurrency or actor isolation.
// I use it for small, synchronous ownership boundaries like locks, file handles,
// and temporary state restoration.
