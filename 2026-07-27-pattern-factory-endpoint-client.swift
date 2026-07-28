# Factory Pattern: Build Endpoint Clients at the Edge

I use a factory when construction has policy—base URLs, headers, authentication—not just a long initializer. The app selects its environment at composition time, and feature code receives a ready-to-use client instead of learning how networking is wired.

```swift
import Foundation

enum APIEnvironment {
    case production
    case staging
}

struct APIClient {
    let baseURL: URL
    let defaultHeaders: [String: String]
}

enum APIClientFactory {
    static func make(environment: APIEnvironment, token: String?) -> APIClient {
        let baseURL: URL = switch environment {
        case .production: URL(string: "https://api.example.com")!
        case .staging: URL(string: "https://staging-api.example.com")!
        }

        var headers = ["Accept": "application/json"]
        if let token {
            headers["Authorization"] = "Bearer \(token)"
        }
        return APIClient(baseURL: baseURL, defaultHeaders: headers)
    }
}

struct ProfileService {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client // Dependencies arrive configured, not discovered here.
    }
}
```

The factory is an edge boundary, so I call it from the app composition root—not from a view model. That makes environment choice explicit and lets tests inject an `APIClient` with a local URL directly.

I keep a factory small and deterministic. If it starts reading global state, opening databases, or branching on user flows, I split those decisions into collaborators. The payoff is that construction policy evolves in one place while feature code stays focused on its job.
