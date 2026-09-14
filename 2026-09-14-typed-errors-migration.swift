// Swift Language Evolution: Migrating String Errors to Typed Domain Errors
//
// I used to return `Result<Value, Error>` everywhere. It was flexible, but each
// caller had to rediscover which failures were expected. I now make the failure
// vocabulary explicit at the boundary where I can actually act on it.

import Foundation

// Legacy: callers can only inspect an opaque Error at runtime.
func legacyLoadProfile(id: String) -> Result<String, Error> {
    guard !id.isEmpty else { return .failure(URLError(.badURL)) }
    return .success("Alex")
}

// Modern: this enum is part of the feature contract, not an implementation detail.
enum ProfileLoadError: Error, Equatable {
    case invalidID
    case offline
    case notFound
}

struct ProfileService {
    func loadProfile(id: String, isOnline: Bool) -> Result<String, ProfileLoadError> {
        guard !id.isEmpty else { return .failure(.invalidID) }
        guard isOnline else { return .failure(.offline) }
        guard id == "alex" else { return .failure(.notFound) }
        return .success("Alex Wong")
    }
}

// Migration strategy:
// 1. Introduce the domain error beside the existing API.
// 2. Map transport errors once in the repository, not in every view model.
// 3. Move callers to exhaustive handling, then retire the opaque endpoint.
func userMessage(for error: ProfileLoadError) -> String {
    switch error {
    case .invalidID: "I cannot load a profile without an ID."
    case .offline: "I will retry when the connection returns."
    case .notFound: "That profile no longer exists."
    }
}

// Production notes:
// - Keep typed errors small and user-meaningful; do not mirror every HTTP code.
// - Preserve diagnostic context separately (logs/metrics) so UI contracts stay stable.
// - Convert third-party errors at the repository boundary to prevent SDK leakage.
