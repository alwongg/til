// Type-Safe UserDefaults with a Property Wrapper
// I keep preference keys next to their defaults so call sites cannot drift into stringly-typed reads.

import Foundation

@propertyWrapper
struct Preference<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults

    init(_ key: String, default defaultValue: Value, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return defaultValue // A missing or stale value should not make launch fragile.
            }
            return value
        }
        nonmutating set {
            // Encoding makes the same wrapper work for enums and structs, not only primitives.
            let data = try? JSONEncoder().encode(newValue)
            store.set(data, forKey: key)
        }
    }
}

final class AppSettings {
    @Preference("hasSeenOnboarding", default: false) var hasSeenOnboarding: Bool
    @Preference("preferredTab", default: "home") var preferredTab: String
}
