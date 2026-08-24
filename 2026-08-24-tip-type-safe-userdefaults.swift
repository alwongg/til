// iOS Tip: Type-Safe UserDefaults with a Property Wrapper
//
// I use this when a preference deserves a name and a compile-time type instead
// of scattered string keys and casts across the app.

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
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return defaultValue }
            return value
        }
        nonmutating set {
            // Encoding makes arrays and small structs just as safe as Bool or String.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct AppPreferences {
    @Preference("hasSeenOnboarding", default: false) var hasSeenOnboarding: Bool
    @Preference("preferredTab", default: "home") var preferredTab: String
}

func markOnboardingComplete() {
    let preferences = AppPreferences()
    preferences.hasSeenOnboarding = true
}
