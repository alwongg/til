import Foundation

/// I use this wrapper when a preference deserves a typed API instead of a stringly-typed call site.
@propertyWrapper
struct UserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults = .standard

    init(wrappedValue: Value, _ key: String) {
        self.defaultValue = wrappedValue
        self.key = key
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            // Encoding every value the same way keeps custom Codable preferences possible too.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

enum AppPreferences {
    @UserDefault("hasSeenOnboarding") static var hasSeenOnboarding = false
    @UserDefault("preferredTab") static var preferredTab = "home"
}

// AppPreferences.hasSeenOnboarding = true
