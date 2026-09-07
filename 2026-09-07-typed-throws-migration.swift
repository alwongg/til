// Swift Language Evolution: Constrain an API Boundary with Typed Throws
//
// I used to expose `async throws` at every networking boundary. It is flexible,
// but callers then have to infer whether a failure is transport, HTTP, decoding,
// or cancellation. That makes recovery policy inconsistent across features.
//
// Modern approach: normalize unknown system errors at the boundary and expose a
// closed failure contract. The rest of the feature can switch exhaustively over
// APIError instead of depending on URLSession or JSONDecoder details.
//
// Migration strategy:
// 1. Introduce a feature-local error enum around one client method.
// 2. Map framework errors at that boundary; do not leak them into view models.
// 3. Convert adjacent callers one at a time, then make retry and UI states
//    exhaustive. Keep third-party errors internal to the client.
//
// Production notes: typed throws clarify recovery, but they are not a reason to
// erase diagnostics. I log the underlying transport detail at the boundary while
// returning a stable, product-level error to callers.

import Foundation

enum APIError: Error, Sendable {
    case invalidResponse
    case decoding
    case transport(String)
    case cancelled
}

struct Profile: Decodable, Sendable {
    let id: UUID
    let name: String
}

struct ProfileClient {
    func loadProfile(id: UUID) async throws(APIError) -> Profile {
        let url = URL(string: "https://example.com/profiles/\(id.uuidString)")!

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                throw APIError.invalidResponse
            }

            do {
                return try JSONDecoder().decode(Profile.self, from: data)
            } catch {
                throw APIError.decoding
            }
        } catch let error as APIError {
            throw error
        } catch is CancellationError {
            throw APIError.cancelled
        } catch {
            // The app can log `error` here; callers get a stable failure shape.
            throw APIError.transport(error.localizedDescription)
        }
    }
}

// A caller now owns an explicit recovery decision:
func userMessage(for error: APIError) -> String {
    switch error {
    case .invalidResponse: "The server returned an unexpected response."
    case .decoding: "The app needs an update to read this data."
    case .transport: "Check your connection and try again."
    case .cancelled: ""
    }
}
