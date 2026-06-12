/// 2026-06-12 Tip: Use defer for cleanup
/// I reach for defer when I need teardown to stay coupled to setup.
/// It keeps the happy path readable and the failure path honest.

import Foundation

final class SessionTracker {
    private let lock = NSLock()
    private var activeSessions: Set<UUID> = []

    func withSession<T>(_ id: UUID, perform work: () throws -> T) rethrows -> T {
        lock.lock()
        activeSessions.insert(id)
        defer {
            // I keep cleanup beside acquisition so early returns and throws cannot leak state.
            activeSessions.remove(id)
            lock.unlock()
        }
        return try work()
    }

    var activeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return activeSessions.count
    }
}

@main
enum DeferCleanupTip {
    static func main() {
        let tracker = SessionTracker()
        let sessionID = UUID()

        let result = try? tracker.withSession(sessionID) { "sync-complete" }
        precondition(tracker.activeCount == 0)
        print(result ?? "missing")
    }
}
