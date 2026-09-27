// # Factory Pattern: Make Environment Wiring Explicit
//
// I use a factory when construction choices vary by environment but callers
// should depend on one stable interface. It keeps preview, staging, and live
// wiring out of a view model instead of scattering `if` statements through it.

import Foundation

protocol ProfileFetching {
    func fetchProfile(id: String) async throws -> String
}

struct LiveProfileService: ProfileFetching {
    func fetchProfile(id: String) async throws -> String {
        // The real implementation owns URLSession details at this boundary.
        "Live profile: \(id)"
    }
}

struct PreviewProfileService: ProfileFetching {
    func fetchProfile(id: String) async throws -> String {
        // Deterministic data makes SwiftUI previews and tests useful offline.
        "Preview profile: \(id)"
    }
}

enum AppEnvironment {
    case live
    case preview
}

enum ServiceFactory {
    static func makeProfileService(for environment: AppEnvironment) -> any ProfileFetching {
        switch environment {
        case .live: LiveProfileService()
        case .preview: PreviewProfileService()
        }
    }
}

// I inject the factory's result once at the composition root. Consumers only
// know the protocol, so switching implementations never changes their logic.
