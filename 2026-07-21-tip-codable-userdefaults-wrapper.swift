// iOS Tip: Type-safe UserDefaults with a Codable property wrapper
//
// I treat UserDefaults as a small persistence boundary, not a stringly-typed
// bucket. This wrapper keeps the key, default value, and Codable conversion in
// one place, so call sites stay boring and refactors stay searchable.

import Foundation

enum PreferenceKey: String {
    case preferredTheme
    case launchCount
}

@propertyWrapper
struct Preference<Value: Codable> {
    let key: PreferenceKey
    let defaultValue: Value
    private let store: UserDefaults

    init(wrappedValue: Value, _ key: PreferenceKey, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key.rawValue),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return defaultValue }
            return value
        }
        nonmutating set {
            // Failed encoding should not replace a known-good stored value.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key.rawValue)
        }
    }
}

enum Theme: String, Codable { case system, light, dark }

final class AppPreferences {
    @Preference(.preferredTheme) var preferredTheme: Theme = .system
    @Preference(.launchCount) var launchCount: Int = 0
}
