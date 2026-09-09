import Foundation

// I keep this container intentionally small: it makes dependencies visible without
// introducing framework magic or a service locator scattered through feature code.
protocol Resolving {
    func resolve<Service>(_ type: Service.Type) -> Service
}

final class Container: Resolving {
    private var factories: [ObjectIdentifier: () -> Any] = [:]

    func register<Service>(_ type: Service.Type, factory: @escaping () -> Service) {
        let key = ObjectIdentifier(type)
        precondition(factories[key] == nil, "Duplicate registration: \(type)")
        factories[key] = factory
    }

    func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        let key = ObjectIdentifier(type)
        guard let factory = factories[key], let service = factory() as? Service else {
            fatalError("Missing registration: \(type)")
        }
        return service
    }
}

protocol ProfileLoading {
    func loadProfile() -> String
}

struct ProfileRepository: ProfileLoading {
    func loadProfile() -> String { "Alex" }
}

struct ProfileViewModel {
    let repository: ProfileLoading
    var title: String { "Hello, \(repository.loadProfile())" }
}

@main
struct Demo {
    static func main() {
        let container = Container()
        container.register(ProfileLoading.self) { ProfileRepository() }
        let viewModel = ProfileViewModel(repository: container.resolve())
        print(viewModel.title)
    }
}
