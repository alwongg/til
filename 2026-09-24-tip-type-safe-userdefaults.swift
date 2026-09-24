# Type-safe `UserDefaults` with a property wrapper

I treat `UserDefaults` as a small preferences store, not an untyped string-key dictionary scattered through views. A property wrapper keeps the key, default, and serialization policy in one place.

```swift
import Foundation

@propertyWrapper
struct UserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    let store: UserDefaults

    init(wrappedValue: Value, key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
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
        set {
            // Encoding every Codable value makes the wrapper work for enums and structs too.
            store.set(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }
}

final class AppPreferences {
    @UserDefault(key: "hasSeenOnboarding") var hasSeenOnboarding = false
    @UserDefault(key: "preferredTab") var preferredTab = "home"
}
```

The important production choice is the fallback: a missing, removed, or no-longer-decodable value returns the declared default instead of leaking an optional through the app. I use stable, namespaced keys and keep wrappers in a dedicated preferences type, so migrations are searchable. For sensitive data, I use Keychain instead; `UserDefaults` is not encrypted.
