import Foundation

final class RefreshGate {
    private let lock = NSLock()
    private var isRefreshing = false

    func beginRefresh() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        // I put cleanup beside acquisition so every early return stays safe.
        guard !isRefreshing else { return false }
        isRefreshing = true
        return true
    }

    func finishRefresh() {
        lock.lock()
        defer { lock.unlock() }
        isRefreshing = false
    }
}

@main
enum DeferForCleanupTip {
    static func main() {
        let gate = RefreshGate()
        guard gate.beginRefresh() else { return }
        defer { gate.finishRefresh() }

        // I can return or throw below without leaving the gate locked.
        print("Refreshing once")
    }
}
