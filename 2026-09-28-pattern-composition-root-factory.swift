# Composition-Root Factory Pattern

I keep object construction at the app boundary so feature code can depend on a protocol rather than deciding which concrete service to create. This makes previews and tests swap implementations without conditional branches inside the feature.

```swift
import Foundation

protocol ProfileLoading {
    func loadProfile(id: UUID) async throws -> Profile
}

struct Profile: Sendable {
    let id: UUID
    let name: String
}

struct LiveProfileLoader: ProfileLoading {
    func loadProfile(id: UUID) async throws -> Profile {
        // Networking belongs behind this boundary, not in the view model.
        Profile(id: id, name: "Alex")
    }
}

final class ProfileViewModel {
    private let loader: any ProfileLoading

    init(loader: any ProfileLoading) {
        self.loader = loader
    }

    func refresh(id: UUID) async throws -> Profile {
        try await loader.loadProfile(id: id)
    }
}

enum ProfileFeatureFactory {
    static func makeLive() -> ProfileViewModel {
        ProfileViewModel(loader: LiveProfileLoader())
    }
}
```

**Why I use it:** `ProfileViewModel` owns behaviour, while the factory owns wiring. In a test, I construct the view model directly with a spy loader; in production, the composition root calls `makeLive()` once. The tradeoff is one extra type, but it prevents service construction from leaking through the feature.
