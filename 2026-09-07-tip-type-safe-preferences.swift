import Foundation

@propertyWrapper
struct Preference<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let defaults: UserDefaults

    init(_ key: String, default defaultValue: Value, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.defaults = defaults
    }

    var wrappedValue: Value {
        get {
            guard let data = defaults.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return defaultValue
            }
            return value
        }
        nonmutating set {
            // Encoding keeps stored values explicit instead of relying on untyped casts.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }
}

struct AppSettings {
    @Preference("hasSeenOnboarding", default: false) var hasSeenOnboarding: Bool
    @Preference("preferredTab", default: "home") var preferredTab: String
}
