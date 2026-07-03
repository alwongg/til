import Foundation

// Production Patterns at Scale — Request Context with TaskLocal
// 2026-07-03
//
// I keep seeing the same scaling failure in mature iOS codebases:
// logging, analytics, feature flags, and request correlation start as easy singletons,
// then slowly turn into hidden global state that makes incidents harder to debug.
//
// Legacy approach
// - Analytics.shared.track(...)
// - Logger.shared.info(...)
// - APIClient.shared.fetch(...)
//
// That looks convenient, but once a screen fans out into multiple async tasks,
// I lose the story of which user action created which network call and which log line.
//
// Modern approach
// I prefer a lightweight RequestContext that travels with the work itself.
// TaskLocal gives me scoped propagation through async call trees without forcing every
// function signature to carry five unrelated parameters.
//
// Migration strategy
// 1. Start by introducing RequestContext and a context-aware logger.
// 2. Bridge existing singleton services so they can optionally read the current context.
// 3. Move high-value flows first: checkout, onboarding, search, sync.
// 4. Add correlation IDs to network headers and log payloads before deleting old globals.
//
// Production notes
// - Keep the context small and value-typed.
// - Never store mutable UI objects inside it.
// - Treat TaskLocal as request scope, not app-wide state.
// - Fall back safely when work starts outside an instrumented flow.

struct RequestContext: Sendable {
    let correlationID: UUID
    let feature: String
    let source: String
    let userID: String?

    init(
        correlationID: UUID = UUID(),
        feature: String,
        source: String,
        userID: String? = nil
    ) {
        self.correlationID = correlationID
        self.feature = feature
        self.source = source
        self.userID = userID
    }
}

enum CurrentRequestContext {
    @TaskLocal static var value: RequestContext?
}

struct LogEntry: Sendable {
    let level: String
    let message: String
    let metadata: [String: String]
}

actor ContextLogger {
    private(set) var entries: [LogEntry] = []

    func info(_ message: String, extra: [String: String] = [:]) {
        let context = CurrentRequestContext.value
        var metadata = extra
        metadata["feature"] = context?.feature ?? "unknown"
        metadata["source"] = context?.source ?? "unknown"
        metadata["correlation_id"] = context?.correlationID.uuidString ?? "missing"
        if let userID = context?.userID {
            metadata["user_id"] = userID
        }

        entries.append(LogEntry(level: "info", message: message, metadata: metadata))
    }
}

struct NetworkRequest: Sendable {
    let path: String
    let headers: [String: String]
}

struct APIClient: Sendable {
    let logger: ContextLogger

    func makeRequest(path: String) async -> NetworkRequest {
        let context = CurrentRequestContext.value
        await logger.info("Preparing request", extra: ["path": path])

        var headers: [String: String] = [:]
        if let context {
            headers["X-Correlation-ID"] = context.correlationID.uuidString
            headers["X-Feature"] = context.feature
            if let userID = context.userID {
                headers["X-User-ID"] = userID
            }
        }

        return NetworkRequest(path: path, headers: headers)
    }
}

struct CheckoutService: Sendable {
    let client: APIClient
    let logger: ContextLogger

    func loadCheckout() async -> NetworkRequest {
        await logger.info("Checkout flow started")
        return await client.makeRequest(path: "/checkout")
    }
}

enum CheckoutFlow {
    static func run(logger: ContextLogger) async -> NetworkRequest {
        let service = CheckoutService(client: APIClient(logger: logger), logger: logger)
        let context = RequestContext(feature: "checkout", source: "cart_button", userID: "user-42")

        return await CurrentRequestContext.$value.withValue(context) {
            await service.loadCheckout()
        }
    }
}
