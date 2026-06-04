# Type-safe UserDefaults with `@propertyWrapper`

I like hiding `UserDefaults` behind a small typed layer so the call site stays boring and I stop sprinkling string keys across the app.

```swift
import Foundation

@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    var storage: UserDefaults = .standard

    var wrappedValue: Value {
        get { storage.object(forKey: key) as? Value ?? defaultValue }
        set { storage.set(newValue, forKey: key) }
    }
}

enum AppDefaults {
    @UserDefault(key: "hasSeenOnboarding", defaultValue: false)
    static var hasSeenOnboarding: Bool

    @UserDefault(key: "launchCount", defaultValue: 0)
    static var launchCount: Int

    @UserDefault(key: "preferredAccentColor", defaultValue: "blue")
    static var preferredAccentColor: String
}

func recordLaunch() {
    AppDefaults.launchCount += 1

    if AppDefaults.launchCount == 1 {
        AppDefaults.hasSeenOnboarding = true
    }
}
```

A few production notes from using this pattern:
- It works best for primitives and simple payloads. For richer models, I usually wrap `Codable` encode/decode separately instead of pretending `UserDefaults` is a database.
- The main win is centralization. Keys live in one place, refactors are safer, and feature code reads like state instead of storage plumbing.
- If I need test isolation, I inject a custom `UserDefaults(suiteName:)` into the wrapper rather than sharing `.standard`.
