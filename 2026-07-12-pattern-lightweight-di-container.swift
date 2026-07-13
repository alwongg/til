import Foundation

// I keep this container intentionally tiny so the dependency graph stays easy to reason about.
// The value is not "framework magic" — it's one place to assemble production wiring.
final class Container {
    typealias Factory = (Container) -> Any
    private var factories: [ObjectIdentifier: Factory] = [:]

    func register<Service>(_ type: Service.Type = Service.self,
                           factory: @escaping (Container) -> Service) {
        factories[ObjectIdentifier(type)] = { container in factory(container) }
    }

    func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        guard let factory = factories[ObjectIdentifier(type)],
              let service = factory(self) as? Service else {
            fatalError("Missing registration for \(type)")
        }
        return service
    }
}

protocol Networking {
    func get(path: String) async throws -> Data
}

struct LiveNetworking: Networking {
    func get(path: String) async throws -> Data {
        Data("GET \(path)".utf8)
    }
}

struct UserRepository {
    let networking: any Networking

    func loadUser(id: String) async throws -> String {
        let data = try await networking.get(path: "/users/\(id)")
        return String(decoding: data, as: UTF8.self)
    }
}

@main
enum DemoApp {
    static func main() async throws {
        let container = Container()

        container.register(Networking.self) { _ in
            LiveNetworking()
        }

        container.register(UserRepository.self) { container in
            UserRepository(networking: container.resolve(Networking.self))
        }

        let repository: UserRepository = container.resolve()
        _ = try await repository.loadUser(id: "42")
    }
}
