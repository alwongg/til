// Swift Language Evolution — replacing stringly failures with typed boundaries
// I use this migration when a legacy callback API has outgrown its error contract.

import Foundation

// Legacy: every failure arrives as an optional Error, so callers must guess.
final class LegacyProfileService {
    func loadProfile(completion: @escaping (Data?, Error?) -> Void) {
        completion(nil, URLError(.notConnectedToInternet))
    }
}

struct Profile: Decodable, Sendable {
    let id: UUID
    let name: String
}

enum ProfileLoadError: Error, Sendable {
    case offline
    case invalidResponse
    case decoding
}

protocol ProfileLoading: Sendable {
    // Modern: the signature documents the only failures this boundary exposes.
    func loadProfile() async throws(ProfileLoadError) -> Profile
}

struct RemoteProfileLoader: ProfileLoading {
    let session: URLSession
    let url: URL

    func loadProfile() async throws(ProfileLoadError) -> Profile {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                throw ProfileLoadError.invalidResponse
            }
            return try JSONDecoder().decode(Profile.self, from: data)
        } catch let error as ProfileLoadError {
            throw error
        } catch is DecodingError {
            throw .decoding
        } catch {
            throw .offline
        }
    }
}

@MainActor
final class ProfileViewModel {
    private(set) var profile: Profile?
    private(set) var message: String?

    // The UI gets product-level states instead of transport implementation details.
    func refresh(using loader: some ProfileLoading) async {
        do {
            profile = try await loader.loadProfile()
            message = nil
        } catch .offline {
            message = "You're offline. Pull to refresh when you're back."
        } catch .invalidResponse, .decoding {
            message = "We couldn't load your profile. Try again shortly."
        } catch {
            // Keep this fallback while callers compiled against older toolchains migrate.
            message = "We couldn't load your profile. Try again shortly."
        }
    }
}

/*
Migration strategy I use:
1. Wrap one callback endpoint behind an async protocol, without changing all callers.
2. Collapse vendor/URL errors into a small domain error at that boundary.
3. Move screens one at a time to `await`, then delete the callback overload after adoption.

Production note: typed throws are most valuable at module boundaries. I do not expose
URLSession, decoding, or SDK-specific errors to view models; that makes tests precise
and keeps a networking swap from becoming a UI migration.
*/
