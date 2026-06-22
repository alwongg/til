import Foundation

// I use a tiny container when I want dependency wiring to stay explicit
// without dragging a full framework into a feature or a sample app.
final class Container {
    enum Scope { case transient, singleton }

    private struct Entry {
        let scope: Scope
        let factory: (Container) -> Any
        var instance: Any?
    }

    private var entries: [ObjectIdentifier: Entry] = [:]

    func register<Service>(_ type: Service.Type,
                           scope: Scope = .transient,
                           factory: @escaping (Container) -> Service) {
        entries[ObjectIdentifier(type)] = Entry(scope: scope, factory: factory, instance: nil)
    }

    func resolve<Service>(_ type: Service.Type = Service.self) -> Service {
        let key = ObjectIdentifier(type)
        guard var entry = entries[key] else { fatalError("Missing registration for \(type)") }

        if entry.scope == .singleton, let cached = entry.instance as? Service {
            return cached
        }

        let service = entry.factory(self) as! Service
        if entry.scope == .singleton {
            entry.instance = service
            entries[key] = entry
        }
        return service
    }
}

protocol Logger { func log(_ message: String) }
struct ConsoleLogger: Logger {
    func log(_ message: String) { print("[log] \(message)") }
}

protocol ProfileRepository { func loadName() -> String }
struct LiveProfileRepository: ProfileRepository {
    let logger: Logger
    func loadName() -> String {
        logger.log("Loading profile")
        return "Alex"
    }
}

@main
struct DemoApp {
    static func main() {
        let container = Container()
        container.register(Logger.self, scope: .singleton) { _ in ConsoleLogger() }
        container.register(ProfileRepository.self) { c in
            LiveProfileRepository(logger: c.resolve(Logger.self))
        }

        let repository = container.resolve(ProfileRepository.self)
        print(repository.loadName())
    }
}
