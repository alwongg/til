// iOS Tip: Type-safe UserDefaults with a property wrapper
//
// I use this when a preference deserves a real name, a real type, and a single
// default value. Call sites stay small; the storage boundary stays explicit.

import Foundation

@propertyWrapper
struct Default<Value: Codable> {
    let key: String
    let fallback: Value
    let store: UserDefaults = .standard

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return fallback }
            return value
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct AppPreferences {
    @Default(key: "showsOnboarding", fallback: true)
    var showsOnboarding: Bool

    @Default(key: "preferredTab", fallback: "home")
    var preferredTab: String
}

// I keep keys beside the feature's settings, not scattered through view code.
