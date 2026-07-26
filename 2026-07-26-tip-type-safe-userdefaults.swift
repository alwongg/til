// iOS Tip: Type-safe UserDefaults with @propertyWrapper
//
// I use this wrapper for small, durable preferences. It keeps string keys at
// the boundary and lets Codable define the storage contract, so a missing or
// malformed value falls back safely instead of crashing a launch.

import Foundation

@propertyWrapper
struct Stored<Value: Codable> {
    let key: String
    let defaultValue: Value
    var defaults: UserDefaults = .standard

    init(wrappedValue: Value, _ key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
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
            // Encoding makes the same wrapper work for enums and small structs,
            // not only the primitive types supported directly by UserDefaults.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key)
        }
    }
}

struct Preferences {
    @Stored("hapticsEnabled") var hapticsEnabled = true
    @Stored("launchCount") var launchCount = 0
}

// I keep this for preferences, not secrets or large cached data.
