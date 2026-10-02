// I use a tiny property wrapper when a preference deserves a name, a type, and one default.
// It keeps string keys at the boundary instead of scattering casts across feature code.
import Foundation

@propertyWrapper
struct UserDefault<Value: Codable> {
    let key: String
    let defaultValue: Value
    private let store: UserDefaults

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
            // Encoding every Codable value avoids an unsafe `as?` at each call site.
            let data = try? JSONEncoder().encode(newValue)
            store.set(data, forKey: key)
        }
    }
}

enum Settings {
    @UserDefault("showCompletedTasks") static var showCompletedTasks = false
    @UserDefault("recentProjectIDs") static var recentProjectIDs: [UUID] = []
}
