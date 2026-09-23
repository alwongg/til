# Bridging delegate callbacks into `AsyncStream`

When I inherit a delegate- or closure-based API, I convert it at the boundary instead of letting callbacks leak into a feature. `AsyncStream` gives the rest of my code structured iteration, cancellation, and a single async vocabulary.

```swift
import Foundation

protocol TemperatureSensorDelegate: AnyObject {
    func sensor(_ sensor: TemperatureSensor, didRead celsius: Double)
}

final class TemperatureSensor {
    weak var delegate: TemperatureSensorDelegate?

    func start() { /* Hardware begins delivering readings. */ }
    func stop() { /* Hardware stops delivering readings. */ }
}

final class TemperatureReadings: NSObject, TemperatureSensorDelegate {
    private let sensor: TemperatureSensor
    private var continuation: AsyncStream<Double>.Continuation?

    init(sensor: TemperatureSensor) {
        self.sensor = sensor
        super.init()
    }

    func stream() -> AsyncStream<Double> {
        AsyncStream { continuation in
            self.continuation = continuation
            self.sensor.delegate = self
            self.sensor.start()

            continuation.onTermination = { [weak self] _ in
                // Cancellation must release the delegate path and hardware work.
                self?.sensor.stop()
                self?.sensor.delegate = nil
                self?.continuation = nil
            }
        }
    }

    func sensor(_ sensor: TemperatureSensor, didRead celsius: Double) {
        continuation?.yield(celsius)
    }

    func finish() {
        continuation?.finish()
    }
}
```

## Why I use this

- My view model can use `for await` instead of owning delegate lifetime.
- Task cancellation triggers `onTermination`, so I stop underlying work rather than leaving sensors or subscriptions alive.
- I keep the adapter as the only place that knows the legacy callback shape.

## Production note

For events where every value matters, I choose an explicit buffering policy and record when `yield` drops a value. For state-like events such as connectivity, `.bufferingNewest(1)` is usually the honest model; for ordered transactions, I use a different durable delivery mechanism rather than pretending an in-memory stream is a queue.
