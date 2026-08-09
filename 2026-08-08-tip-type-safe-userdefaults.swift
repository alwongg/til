import Foundation

// I reach for a Codable-backed wrapper when a preference needs a stable key
// and a typed default. It keeps stringly-typed UserDefaults access at the edge.
@propertyWrapper
struct Stored<Value: Codable> {
    private let key: String
    private let defaultValue: Value
    private var store: UserDefaults = .standard

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
        nonmutating set {
            // Encoding failure should not replace a previously valid preference.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

enum Appearance: String, Codable {
    case system, light, dark
}

struct Preferences {
    // I namespace keys so they remain searchable during migrations.
    @Stored("settings.appearance") var appearance: Appearance = .system
    @Stored("settings.showsCompleted") var showsCompleted = true
}
