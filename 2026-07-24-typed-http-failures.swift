import Foundation

/*
 Production at Scale: Make HTTP Failures Typed

 Legacy: screens inspect URLResponse themselves and collapse every non-200 case
 into URLError(.badServerResponse). That loses the status and payload needed for
 retry policy, sign-out decisions, and useful diagnostics.

 Modern: one transport boundary classifies the failure; repositories decide the
 product response. I migrate one endpoint family at a time, map APIError where
 product context exists, then move the next family. Retries stay outside this
 client because retryability is a business decision, not a property of requests.
*/

enum APIError: Error, Sendable {
    case invalidResponse
    case httpStatus(Int, body: Data)
    case decoding(Error)
}

struct Endpoint<Response: Decodable & Sendable>: Sendable {
    let request: URLRequest
}

actor APIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint<Response>
    ) async throws -> Response {
        let (data, response) = try await session.data(for: endpoint.request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            // Preserving the payload lets an upstream repository recover by API code.
            throw APIError.httpStatus(http.statusCode, body: data)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

/*
 Production notes:
 - I observe status, decoding, and transport failures independently.
 - Injecting URLSession makes protocol-stub tests possible without changing callers.
 - I preserve raw error Data until the API contract requires typed error decoding.
*/
