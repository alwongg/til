// iOS Tip: Type-safe UserDefaults with @propertyWrapper
//
// I use this for small Codable settings where a string key and a cast would
// otherwise leak into every call site. The fallback remains explicit and
// decoding failures heal themselves instead of crashing launch.

import Foundation

@propertyWrapper
struct Default<Value: Codable> {
    let key: String
    let fallback: Value
    let store: UserDefaults

    init(_ key: String, default fallback: Value, store: UserDefaults = .standard) {
        self.key = key
        self.fallback = fallback
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return fallback
            }
            return value
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct AppSettings {
    @Default("hasSeenOnboarding", default: false) var hasSeenOnboarding: Bool
    @Default("preferredTab", default: "home") var preferredTab: String
}

// The property declaration carries both the key and its safe default.
