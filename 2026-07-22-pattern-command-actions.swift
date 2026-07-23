// Command Pattern: make user intent queueable, testable, and observable.
// I use commands when a feature needs to separate "what happened" from "how it is performed."

import Foundation

protocol Command {
    func execute() async throws
}

actor Analytics {
    private(set) var events: [String] = []

    func track(_ event: String) {
        events.append(event)
    }
}

struct TrackPurchase: Command {
    let orderID: String
    let analytics: Analytics

    func execute() async throws {
        // Keeping the side effect here lets the caller stay unaware of its implementation.
        await analytics.track("purchase_completed:\(orderID)")
    }
}

actor CommandQueue {
    func submit(_ command: some Command) async throws {
        // This boundary is where I can later add retries, logging, or ordering guarantees.
        try await command.execute()
    }
}

@main
struct Demo {
    static func main() async {
        let analytics = Analytics()
        let queue = CommandQueue()
        try? await queue.submit(TrackPurchase(orderID: "A-42", analytics: analytics))
    }
}
