import Foundation

// type-safe UserDefaults with @propertyWrapper
//
// I use a tiny property wrapper when I want feature code to read like state instead
// of stringly-typed persistence. The wrapper centralizes the key, the default value,
// and the storage mechanism so I don't scatter magic strings across the app.

enum DefaultsKey {
    static let hasSeenOnboarding = "has_seen_onboarding"
    static let launchCount = "launch_count"
}

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

struct AppPreferences {
    @UserDefault(key: DefaultsKey.hasSeenOnboarding, defaultValue: false)
    var hasSeenOnboarding: Bool

    @UserDefault(key: DefaultsKey.launchCount, defaultValue: 0)
    var launchCount: Int

    mutating func recordLaunch() {
        // The caller updates app state; persistence is an implementation detail.
        launchCount += 1
    }
}
