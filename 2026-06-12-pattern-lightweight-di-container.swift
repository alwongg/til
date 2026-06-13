import Foundation

protocol Resolving {
    func resolve<Service>(_ type: Service.Type) -> Service
}

final class Container: Resolving {
    private var factories: [ObjectIdentifier: () -> Any] = [:]

    func register<Service>(_ type: Service.Type, factory: @escaping () -> Service) {
        factories[ObjectIdentifier(type)] = factory
    }

    func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        guard let factory = factories[ObjectIdentifier(type)], let service = factory() as? Service else {
            fatalError("Missing registration for \(type)")
        }
        return service
    }
}

protocol AnalyticsTracking {
    func track(_ event: String)
}

struct ConsoleAnalytics: AnalyticsTracking {
    func track(_ event: String) {
        print("track:", event)
    }
}

struct CheckoutViewModel {
    private let analytics: AnalyticsTracking

    init(resolver: Resolving) {
        // I like this pattern when I want composition at the edge without passing concrete types through the feature.
        self.analytics = resolver.resolve(AnalyticsTracking.self)
    }

    func completePurchase() {
        analytics.track("checkout_completed")
    }
}

@main
enum LightweightDIContainerPattern {
    static func main() {
        let container = Container()
        container.register(AnalyticsTracking.self) { ConsoleAnalytics() }

        let viewModel = CheckoutViewModel(resolver: container)
        viewModel.completePurchase()
    }
}
