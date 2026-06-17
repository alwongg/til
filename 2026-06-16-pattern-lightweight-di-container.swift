import Foundation

// I keep this container tiny on purpose: enough for app composition, not enough to hide dependencies.
final class Container {
    private var factories: [ObjectIdentifier: (Container) -> Any] = [:]

    func register<Service>(_ type: Service.Type, factory: @escaping (Container) -> Service) {
        factories[ObjectIdentifier(type)] = factory
    }

    func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        guard let factory = factories[ObjectIdentifier(type)], let service = factory(self) as? Service else {
            fatalError("Missing registration for \(type)")
        }
        return service
    }
}

protocol Logger {
    func log(_ message: String)
}

struct ConsoleLogger: Logger {
    func log(_ message: String) {
        print("LOG:", message)
    }
}

struct FeedRepository {
    let logger: Logger

    func refresh() {
        // I inject edges once, then keep feature code explicit and testable.
        logger.log("Refreshing feed")
    }
}

@main
struct DemoApp {
    static func main() {
        let container = Container()
        container.register(Logger.self) { _ in ConsoleLogger() }
        container.register(FeedRepository.self) { c in FeedRepository(logger: c.resolve()) }

        let repository: FeedRepository = container.resolve()
        repository.refresh()
    }
}
