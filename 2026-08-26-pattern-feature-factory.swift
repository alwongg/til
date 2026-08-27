# Factory Pattern: Keep Construction at the Composition Root

When a feature needs a service, I avoid letting the view model decide which concrete implementation to create. That decision belongs at the composition root, where environment-specific wiring is visible and testable.

```swift
import Foundation

protocol ProfileLoading {
    func loadProfile(id: String) async throws -> Profile
}

struct Profile: Sendable {
    let id: String
    let displayName: String
}

final class ProfileViewModel {
    private let loader: any ProfileLoading

    init(loader: any ProfileLoading) {
        self.loader = loader
    }

    func refresh(id: String) async throws -> Profile {
        try await loader.loadProfile(id: id)
    }
}

enum ProfileFeatureFactory {
    static func makeLive() -> ProfileViewModel {
        ProfileViewModel(loader: URLSessionProfileLoader())
    }

    static func makePreview() -> ProfileViewModel {
        ProfileViewModel(loader: PreviewProfileLoader())
    }
}

struct URLSessionProfileLoader: ProfileLoading {
    func loadProfile(id: String) async throws -> Profile {
        // The transport concern stays behind the protocol boundary.
        Profile(id: id, displayName: "Live profile")
    }
}

struct PreviewProfileLoader: ProfileLoading {
    func loadProfile(id: String) async throws -> Profile {
        Profile(id: id, displayName: "Preview profile")
    }
}
```

I use a small factory when a feature has a few well-known assembly modes: live, preview, and test. The view model stays focused on behaviour, while the factory makes dependencies explicit. For larger apps, this becomes a feature-level composition root rather than a global service locator.

**Production note:** Keep factories close to the feature they assemble. A giant `AppFactory` eventually becomes hidden global state with a nicer name.
