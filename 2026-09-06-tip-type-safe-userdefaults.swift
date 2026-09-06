// I use a tiny key type so UserDefaults access stays discoverable and type-safe.
// The default belongs to the key; callers never need to remember a fallback.
import Foundation

struct DefaultsKey<Value> {
    let name: String
    let defaultValue: Value
}

@propertyWrapper
struct UserDefault<Value> {
    let key: DefaultsKey<Value>
    let store: UserDefaults

    init(_ key: DefaultsKey<Value>, store: UserDefaults = .standard) {
        self.key = key
        self.store = store
    }

    var wrappedValue: Value {
        get { store.object(forKey: key.name) as? Value ?? key.defaultValue }
        nonmutating set { store.set(newValue, forKey: key.name) }
    }
}

enum Settings {
    static let hasSeenOnboarding = DefaultsKey(name: "hasSeenOnboarding", defaultValue: false)
}

struct AppPreferences {
    @UserDefault(Settings.hasSeenOnboarding) var hasSeenOnboarding: Bool
}
