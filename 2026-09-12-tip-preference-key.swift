// iOS Tip: Type-Safe UserDefaults with a Property Wrapper
//
// I use this pattern when a preference deserves a stable key, a documented default,
// and a single conversion boundary. It keeps stringly-typed reads out of views.

import Foundation

@propertyWrapper
struct Default<Value: Codable> {
    let key: String
    let fallback: Value
    var store: UserDefaults = .standard

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return fallback }
            return value
        }
        nonmutating set {
            let data = try? JSONEncoder().encode(newValue)
            store.set(data, forKey: key)
        }
    }
}

struct AppPreferences {
    @Default(key: "settings.hapticsEnabled", fallback: true)
    var hapticsEnabled: Bool

    @Default(key: "settings.lastSync", fallback: nil)
    var lastSync: Date?
}

func updatePreferences() {
    var preferences = AppPreferences()
    preferences.hapticsEnabled = false
    preferences.lastSync = .now
}
