import Foundation

/*
 Friday — Production Patterns at Scale
 Title: From endpoint-specific API code to a composable request pipeline

 Legacy approach
 - Every screen builds URLRequest differently.
 - Auth headers, decoding, and retry rules drift over time.
 - Cross-cutting concerns like tracing and feature flags end up in view models.

 Modern approach
 - Model each request as data.
 - Centralize request execution behind middleware.
 - Keep auth, tracing, and rollout logic composable instead of hard-coded.

 Migration strategy
 1. Wrap one existing endpoint in APIRequest<Response>.
 2. Move auth/header logic into middleware.
 3. Route a single feature through RequestExecutor.
 4. Expand endpoint-by-endpoint instead of rewriting the whole networking layer.

 Production notes
 - Keep middleware small and deterministic so failures are easy to isolate.
 - Prefer typed context over global singletons when shipping experiments.
 - Make the executor boring; scale usually comes from consistency, not cleverness.
 */

struct RequestContext: Sendable {
    let requestID: UUID
    let rolloutBucket: Int
}

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

struct APIRequest<Response: Decodable>: Sendable {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?

    init(path: String, method: HTTPMethod = .get, headers: [String: String] = [:], body: Data? = nil) {
        self.path = path
        self.method = method
        self.headers = headers
        self.body = body
    }
}

struct UserProfile: Codable, Sendable {
    let id: Int
    let name: String
}

protocol RequestMiddleware: Sendable {
    func prepare(_ request: URLRequest, context: RequestContext) async throws -> URLRequest
}

actor AuthTokenStore {
    private var token: String

    init(token: String) {
        self.token = token
    }

    func readToken() -> String {
        token
    }
}

struct BearerTokenMiddleware: RequestMiddleware {
    let tokenStore: AuthTokenStore

    func prepare(_ request: URLRequest, context: RequestContext) async throws -> URLRequest {
        var request = request
        request.setValue("Bearer \(await tokenStore.readToken())", forHTTPHeaderField: "Authorization")
        return request
    }
}

struct TraceMiddleware: RequestMiddleware {
    func prepare(_ request: URLRequest, context: RequestContext) async throws -> URLRequest {
        var request = request
        request.setValue(context.requestID.uuidString, forHTTPHeaderField: "X-Request-ID")
        request.setValue("bucket-\(context.rolloutBucket)", forHTTPHeaderField: "X-Rollout-Bucket")
        return request
    }
}

struct RequestExecutor: Sendable {
    let baseURL: URL
    let session: URLSession
    let middlewares: [any RequestMiddleware]

    func execute<Response: Decodable>(
        _ apiRequest: APIRequest<Response>,
        context: RequestContext
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: apiRequest.path))
        request.httpMethod = apiRequest.method.rawValue
        request.httpBody = apiRequest.body

        for (header, value) in apiRequest.headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        for middleware in middlewares {
            request = try await middleware.prepare(request, context: context)
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum UserAPI {
    static func profile(id: Int) -> APIRequest<UserProfile> {
        APIRequest(path: "/users/\(id)", headers: ["Accept": "application/json"])
    }
}

@main
enum Demo {
    static func main() async {
        let executor = RequestExecutor(
            baseURL: URL(string: "https://example.com")!,
            session: .shared,
            middlewares: [
                BearerTokenMiddleware(tokenStore: AuthTokenStore(token: "demo-token")),
                TraceMiddleware()
            ]
        )

        let context = RequestContext(requestID: UUID(), rolloutBucket: 42)
        let request = UserAPI.profile(id: 7)

        print("Ready to execute \(request.method.rawValue) \(request.path) with \(executor.middlewares.count) middleware stages.")
        print("Request ID: \(context.requestID.uuidString)")
    }
}
