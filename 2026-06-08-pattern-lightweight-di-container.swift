import Foundation

// I like a tiny DI container when a feature has a few shared services but I don't want constructor plumbing in every call site.
// The key is to keep registration explicit and resolution type-safe instead of drifting into stringly runtime lookups.

struct Resolver {
    private var factories: [ObjectIdentifier: () -> Any] = [:]

    mutating func register<Service>(_ type: Service.Type, factory: @escaping () -> Service) {
        factories[ObjectIdentifier(type)] = factory
    }

    func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        guard let factory = factories[ObjectIdentifier(type)], let service = factory() as? Service else {
            preconditionFailure("Missing registration for \(type)")
        }
        return service
    }
}

protocol AnalyticsLogging {
    func track(_ event: String)
}

struct ConsoleAnalytics: AnalyticsLogging {
    func track(_ event: String) {
        print("tracked: \(event)")
    }
}

struct ProfileViewModel {
    private let analytics: AnalyticsLogging

    init(analytics: AnalyticsLogging) {
        self.analytics = analytics
    }

    func didTapEdit() {
        analytics.track("profile_edit_tapped")
    }
}

var container = Resolver()
container.register(AnalyticsLogging.self) { ConsoleAnalytics() }
container.register(ProfileViewModel.self) { ProfileViewModel(analytics: container.resolve()) }

let viewModel: ProfileViewModel = container.resolve()
viewModel.didTapEdit()

// In production I keep the container at the composition root, then pass concrete dependencies into the feature boundary.
