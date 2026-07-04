import Foundation

// Pattern: Lightweight DI container
// I use this when I want feature code to depend on capabilities, not constructors.
// The container stays tiny, audit-friendly, and easy to swap in tests.

final class Container {
    private var factories: [ObjectIdentifier: (Container) -> Any] = [:]

    func register<Service>(_ type: Service.Type, factory: @escaping (Container) -> Service) {
        factories[ObjectIdentifier(type)] = { container in factory(container) }
    }

    func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        guard let service = factories[ObjectIdentifier(type)]?(self) as? Service else {
            fatalError("Missing registration for \(type)")
        }
        return service
    }
}

protocol Analytics {
    func track(_ event: String)
}

struct ConsoleAnalytics: Analytics {
    func track(_ event: String) { print("track:", event) }
}

struct CheckoutViewModel {
    let analytics: Analytics

    func checkout() {
        analytics.track("checkout_tapped")
    }
}

@main
struct Demo {
    static func main() {
        let container = Container()
        container.register(Analytics.self) { _ in ConsoleAnalytics() }

        let viewModel = CheckoutViewModel(analytics: container.resolve())
        viewModel.checkout()
    }
}
