import Foundation

/// I use this when a preference needs a real type and a safe default,
/// rather than an untyped string key scattered through a feature.
@propertyWrapper
struct UserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    var store: UserDefaults = .standard

    init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            guard let data = store.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else { return defaultValue }
            return value
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct AppPreferences {
    @UserDefault("showCompletedTasks") var showCompletedTasks = false
    @UserDefault("recentProjectIDs") var recentProjectIDs: [UUID] = []
}

// The declaration owns both the key and its fallback value. A missing or
// malformed stored value degrades safely instead of leaking optional handling
// into every call site.
