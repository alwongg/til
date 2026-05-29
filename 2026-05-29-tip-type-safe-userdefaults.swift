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
    // I like keeping keys near their usage so migrations stay obvious.
    @UserDefault(key: "has_seen_onboarding", defaultValue: false)
    static var hasSeenOnboarding: Bool

    // The wrapper gives me one source of truth for fallback values.
    @UserDefault(key: "launch_count", defaultValue: 0)
    static var launchCount: Int

    @UserDefault(key: "last_selected_tab", defaultValue: "home")
    static var lastSelectedTab: String
}

func recordLaunch() {
    AppDefaults.launchCount += 1

    if !AppDefaults.hasSeenOnboarding {
        AppDefaults.hasSeenOnboarding = true
    }
}

// The win is not fewer lines. The win is removing stringly-typed reads
// from view models and features so refactors fail in one place instead of five.
print(AppDefaults.launchCount)
