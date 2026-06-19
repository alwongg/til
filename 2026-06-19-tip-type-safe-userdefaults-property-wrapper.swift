import Foundation

@propertyWrapper
struct UserDefault<Value> {
    private let key: String
    private let defaultValue: Value
    private let storage: UserDefaults

    init(_ key: String, defaultValue: Value, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }

    var wrappedValue: Value {
        get { storage.object(forKey: key) as? Value ?? defaultValue }
        set { storage.set(newValue, forKey: key) }
    }
}

struct AppSettings {
    @UserDefault("has_seen_onboarding", defaultValue: false)
    var hasSeenOnboarding: Bool

    @UserDefault("launch_count", defaultValue: 0)
    var launchCount: Int

    mutating func recordLaunch() {
        launchCount += 1
    }
}

func makePreviewSettings() -> AppSettings {
    var settings = AppSettings()
    settings.recordLaunch()
    settings.hasSeenOnboarding = true
    return settings
}
