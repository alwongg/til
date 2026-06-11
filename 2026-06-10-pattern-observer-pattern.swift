import Foundation

// I use the observer pattern when I want state changes to fan out without hard-wiring every consumer together.
// It keeps the publisher small and lets UI, analytics, and side effects subscribe independently.

struct BuildStatus {
    let branch: String
    let isGreen: Bool
}

final class BuildMonitor {
    typealias Observer = (BuildStatus) -> Void

    private var observers: [UUID: Observer] = [:]

    @discardableResult
    func addObserver(_ observer: @escaping Observer) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    func removeObserver(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    func publish(_ status: BuildStatus) {
        observers.values.forEach { $0(status) }
    }
}

@main
enum ObserverPatternDemo {
    static func main() {
        let monitor = BuildMonitor()

        let dashboard = monitor.addObserver { print("dashboard:", $0.branch, $0.isGreen ? "✅" : "❌") }
        _ = monitor.addObserver { if !$0.isGreen { print("pager: investigate \\($0.branch)") } }

        monitor.publish(BuildStatus(branch: "main", isGreen: true))
        monitor.publish(BuildStatus(branch: "release/1.4", isGreen: false))

        monitor.removeObserver(dashboard)
        monitor.publish(BuildStatus(branch: "hotfix/login", isGreen: true))
    }
}
