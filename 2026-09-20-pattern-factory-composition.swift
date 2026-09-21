// Pattern: Factory — composing a feature without leaking concrete dependencies
// I use a factory at the composition boundary: views receive a ready-to-use
// model, while construction details stay in one replaceable place.

import Foundation

protocol ProfileLoading {
    func loadProfile(id: UUID) async throws -> Profile
}

struct Profile: Sendable {
    let id: UUID
    let name: String
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
    static func makeViewModel() -> ProfileViewModel {
        // The app chooses production wiring here, not inside the view model.
        ProfileViewModel(loader: LiveProfileRepository())
    }
}

struct LiveProfileRepository: ProfileLoading {
    func loadProfile(id: UUID) async throws -> Profile {
        Profile(id: id, name: "Alex")
    }
}
