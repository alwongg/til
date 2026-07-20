// iOS Tip: Type-safe UserDefaults with a property wrapper
//
// I keep persistence details at the boundary instead of scattering string keys
// and casts across view models. Codable makes the stored representation explicit,
// while the supplied default keeps a missing value from becoming an optional leak.

import Foundation

@propertyWrapper
struct Default<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let defaults: UserDefaults

    init(wrappedValue defaultValue: Value, _ key: String, defaults: UserDefaults = .standard) {
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
        set {
            // Encoding failures should be visible in development rather than silently losing state.
            guard let data = try? JSONEncoder().encode(newValue) else {
                assertionFailure("Could not encode \(Value.self) for \(key)")
                return
            }
            defaults.set(data, forKey: key)
        }
    }
}

struct AppPreferences {
    @Default("hasSeenOnboarding") var hasSeenOnboarding = false
    @Default("preferredTab") var preferredTab = "home"
}
