// iOS Tip — Type-Safe UserDefaults with @propertyWrapper
//
// I use this for small Codable preferences. Keeping encoding at the boundary
// means call sites stay typed, and corrupt or old values safely fall back.

import Foundation

@propertyWrapper
struct CodablePreference<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults

    init(
        _ key: String,
        default defaultValue: Value,
        store: UserDefaults = .standard
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key) else { return defaultValue }
            return (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct Settings {
    @CodablePreference("preferredAppearance", default: "system")
    var preferredAppearance: String
}
