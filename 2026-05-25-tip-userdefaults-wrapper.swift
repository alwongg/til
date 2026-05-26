import Foundation

// 2026-05-25 — iOS Tip
// Title: Type-safe UserDefaults with @propertyWrapper
//
// I like pushing UserDefaults behind a tiny typed layer so the call sites stay boring.
// The wrapper keeps keys in one place and makes defaults explicit.

@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value
    let storage: UserDefaults

    init(key: String, defaultValue: Value, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }

    var wrappedValue: Value {
        get {
            // I always fall back to a real default so reads never return an accidental nil.
            storage.object(forKey: key) as? Value ?? defaultValue
        }
        set {
            // Keeping the write path tiny makes this easy to audit in production.
            storage.set(newValue, forKey: key)
        }
    }
}

enum Settings {
    @UserDefault(key: "has_seen_onboarding", defaultValue: false)
    static var hasSeenOnboarding: Bool

    @UserDefault(key: "launch_count", defaultValue: 0)
    static var launchCount: Int
}

func recordLaunch() {
    Settings.launchCount += 1
    if !Settings.hasSeenOnboarding {
        Settings.hasSeenOnboarding = true
    }

    print("Launch count: \(Settings.launchCount)")
}

recordLaunch()
