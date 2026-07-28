import Foundation

@propertyWrapper
struct UserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults

    init(_ key: String, defaultValue: Value, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key) else { return defaultValue }
            // A bad persisted value should not crash launch; fall back and let the app recover.
            return (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                assertionFailure("\(Value.self) is not encodable")
                return
            }
            store.set(data, forKey: key)
        }
    }
}

enum Appearance: String, Codable {
    case system, light, dark
}

struct Settings {
    @UserDefault("appearance", defaultValue: .system) var appearance: Appearance
    @UserDefault("hasSeenOnboarding", defaultValue: false) var hasSeenOnboarding: Bool
}

@main
enum Demo {
    static func main() {
        var settings = Settings()
        settings.appearance = .dark
        print(settings.appearance)
    }
}
