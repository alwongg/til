// iOS Tip — Type-safe UserDefaults with a property wrapper
//
// I keep UserDefaults for small preferences, but I do not let string keys
// and casts leak through a feature. This wrapper makes the default explicit
// and uses Codable so a refactor fails at compile time instead of at launch.

import Foundation

@propertyWrapper
struct Preference<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults

    init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return defaultValue }
            return value
        }
        set {
            // Encoding every value keeps Bool, enum, and struct preferences consistent.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

enum AppTheme: String, Codable { case system, light, dark }

struct Settings {
    @Preference("settings.appTheme") var appTheme: AppTheme = .system
}
