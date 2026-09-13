// iOS Tip: Make UserDefaults type-safe with a property wrapper
//
// I keep persistence at the edge of the app. This wrapper centralizes encoding,
// defaults, and keys so feature code reads like a normal stored property.

import Foundation

@propertyWrapper
struct Defaults<Value: Codable> {
    private let key: String
    private let defaultValue: Value
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
            // Removing a value when encoding fails is worse than preserving the last good state.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct AppPreferences {
    @Defaults("hasSeenOnboarding") var hasSeenOnboarding = false
    @Defaults("preferredTab") var preferredTab = "home"
}

// For tests, inject UserDefaults(suiteName:) into a dedicated wrapper instance.
