import Foundation

@propertyWrapper
struct UserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults

    init(
        _ key: String,
        defaultValue: Value,
        store: UserDefaults = .standard
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return defaultValue }
            return value
        }
        set {
            // Encoding keeps arrays and structs type-safe without force casts.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct AppSettings: Codable, Equatable {
    var hasSeenOnboarding = false
    var preferredTab = "home"
}

struct SettingsStore {
    @UserDefault("app.settings", defaultValue: AppSettings())
    var settings: AppSettings
}
