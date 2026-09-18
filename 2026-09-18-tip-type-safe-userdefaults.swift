# Type-safe `UserDefaults` with a property wrapper

I use `UserDefaults` for small, durable preferences—not application state. The easy version is a stringly-typed key scattered across views and services. I prefer putting the key, default, and persistence boundary in one declaration.

```swift
import Foundation

@propertyWrapper
struct Default<Value: Codable> {
    let key: String
    let fallback: Value
    private let store: UserDefaults

    init(_ key: String, default fallback: Value, store: UserDefaults = .standard) {
        self.key = key
        self.fallback = fallback
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return fallback
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
    @Default("settings.hapticsEnabled", default: true)
    var hapticsEnabled: Bool

    @Default("settings.preferredTab", default: "home")
    var preferredTab: String
}
```

The wrapper makes defaults discoverable and testable: inject a dedicated `UserDefaults(suiteName:)` store in tests. I also namespace keys so a future migration can identify ownership quickly. For values that should not be silently replaced after corruption, I expose decoding failures through diagnostics instead of treating the fallback as success.