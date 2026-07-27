// Type-Safe UserDefaults with @propertyWrapper
//
// I use this boundary to keep string keys and decoding failures out of feature code.
// A missing or malformed stored value falls back safely instead of crashing launch.

import Foundation

@propertyWrapper
struct Defaults<Value: Codable> {
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
                return defaultValue
            }
            return value
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct Settings {
    @Defaults("preferredTheme", default: "system") var preferredTheme: String
    @Defaults("hasSeenOnboarding", default: false) var hasSeenOnboarding: Bool
}

@main
struct Demo {
    static func main() {
        var settings = Settings()
        settings.hasSeenOnboarding = true
        print(settings.preferredTheme)
    }
}
