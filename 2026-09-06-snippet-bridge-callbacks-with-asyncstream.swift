import Foundation

final class LocationManager {
    private var onLocation: ((Double) -> Void)?

    func startUpdates(_ handler: @escaping (Double) -> Void) {
        onLocation = handler
    }

    func stopUpdates() {
        onLocation = nil
    }

    func simulateLocation(_ latitude: Double) {
        onLocation?(latitude)
    }
}

func locationUpdates(from manager: LocationManager) -> AsyncStream<Double> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        manager.startUpdates { latitude in
            continuation.yield(latitude)
        }

        continuation.onTermination = { _ in
            manager.stopUpdates()
        }
    }
}

@main
struct Demo {
    static func main() async {
        let manager = LocationManager()
        let stream = locationUpdates(from: manager)

        let consumer = Task {
            for await latitude in stream {
                print("Location: \(latitude)")
                break
            }
        }

        manager.simulateLocation(43.6532)
        _ = await consumer.value
    }
}
