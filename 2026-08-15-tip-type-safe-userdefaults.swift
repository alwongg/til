// I use this wrapper to keep UserDefaults keys, defaults, and types together.
// The generic constraint prevents a typo or mismatched cast from leaking into call sites.
import Foundation

@propertyWrapper
struct Default<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults

    init(_ key: String, default defaultValue: Value, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
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
        nonmutating set {
            // Encoding makes arrays and small structs as safe to persist as primitives.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            store.set(data, forKey: key)
        }
    }
}

struct AppSettings {
    @Default("preferredTab", default: "home") var preferredTab: String
    @Default("hasSeenOnboarding", default: false) var hasSeenOnboarding: Bool
}
