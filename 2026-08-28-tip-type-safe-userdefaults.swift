# Type-safe `UserDefaults` with a property wrapper

I treat `UserDefaults` as a tiny persistence boundary, not a stringly-typed global. This wrapper keeps the key, default value, and Codable conversion in one place, so call sites stay honest and testable.

```swift
import Foundation

@propertyWrapper
struct Preference<Value: Codable> {
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
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return defaultValue }
            return value
        }
        nonmutating set {
            // Encoding here keeps the storage format consistent for every preference.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct Settings {
    @Preference("hasSeenOnboarding", default: false)
    var hasSeenOnboarding: Bool

    @Preference("preferredTab", default: "home")
    var preferredTab: String
}
```

The `newValue != nil` branch works for every `Codable` value, but it is only meaningful for optionals. In production I would make that policy explicit with a separate optional wrapper, inject a suite-backed `UserDefaults` in tests, and reserve this for small preferences—not app data that needs migrations or queries.
