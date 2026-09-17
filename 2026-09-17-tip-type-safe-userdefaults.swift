# iOS Tip: Type-safe `UserDefaults` with a Property Wrapper

I keep `UserDefaults` behind a small typed boundary instead of scattering string keys and casts through my app. It makes defaults visible at the declaration site, gives me compiler-checked value types, and keeps the storage detail out of feature code.

```swift
import Foundation

@propertyWrapper
struct Default<Value> {
    let key: String
    let defaultValue: Value
    let store: UserDefaults

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
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key) }
    }
}

struct AppPreferences {
    @Default("hasSeenOnboarding", default: false)
    var hasSeenOnboarding: Bool

    @Default("preferredCurrency", default: "CAD")
    var preferredCurrency: String
}
```

I use this for simple property-list values only. For models, I prefer a dedicated `Codable` store so decoding failures and migrations are explicit instead of hidden inside a generic wrapper.
