import Foundation

// I use this wrapper when a preference is part of the app's vocabulary.
// Codable keeps the stored representation consistent across reads and writes.
@propertyWrapper
struct UserDefault<Value: Codable> {
    private let key: String
    private let defaultValue: Value
    private let storage: UserDefaults

    init(wrappedValue: Value, _ key: String, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.storage = storage
    }

    var wrappedValue: Value {
        get {
            guard let data = storage.data(forKey: key),
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            // Encoding makes reads and writes agree on one representation.
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            storage.set(data, forKey: key)
        }
    }
}

enum AppPreferences {
    @UserDefault("hasSeenOnboarding") static var hasSeenOnboarding = false
    @UserDefault("preferredTab") static var preferredTab = "home"
}
