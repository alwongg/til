// Quick Concept — Cooperative Cancellation in AsyncSequence
//
// I treat cancellation as a normal control-flow path, not an exceptional failure.
// An AsyncStream producer must stop its underlying work when the consumer leaves;
// otherwise a dismissed screen can keep networking, timers, and memory alive.

import Foundation

final class PriceFeed {
    private var task: Task<Void, Never>?

    func updates() -> AsyncStream<Int> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            task = Task {
                var price = 100
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { break }
                    price += 1
                    continuation.yield(price)
                }
                continuation.finish()
            }

            continuation.onTermination = { [weak self] _ in
                // The consumer owns demand, so its exit tears down the producer.
                self?.task?.cancel()
                self?.task = nil
            }
        }
    }
}

@main
struct Demo {
    static func main() async {
        let feed = PriceFeed()
        let consumer = Task {
            for await price in feed.updates() {
                print("Price: \(price)")
            }
        }

        try? await Task.sleep(for: .seconds(2.2))
        consumer.cancel()
    }
}
