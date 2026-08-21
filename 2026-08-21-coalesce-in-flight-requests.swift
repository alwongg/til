// Production Pattern: Coalesce Identical In-Flight Requests
//
// Legacy approach
// I used to let every screen trigger its own request. It looked harmless until a
// list, detail view, and pull-to-refresh all asked for the same resource. That
// multiplied radio work, rate-limit exposure, and inconsistent loading states.
//
// Modern approach
// This actor keeps one Task per key. Concurrent callers join the same Task, then
// the first completed waiter clears it. The cache remains a separate concern:
// coalescing is only about work already in flight.

import Foundation

actor RequestCoalescer<Key: Hashable & Sendable, Value: Sendable> {
    private var inFlight: [Key: Task<Value, Error>] = [:]

    func value(
        for key: Key,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let task: Task<Value, Error>

        if let existing = inFlight[key] {
            task = existing
        } else {
            let created = Task { try await operation() }
            inFlight[key] = created
            task = created
        }

        defer {
            // Removing after completion lets the next caller deliberately start fresh.
            // A completed Task is not accidentally used as a cache entry.
            inFlight[key] = nil
        }
        return try await task.value
    }
}

struct Product: Sendable, Decodable {
    let id: UUID
    let name: String
}

protocol ProductLoading: Sendable {
    func loadProduct(id: UUID) async throws -> Product
}

final class ProductService: ProductLoading, Sendable {
    private let coalescer = RequestCoalescer<UUID, Product>()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadProduct(id: UUID) async throws -> Product {
        try await coalescer.value(for: id) { [session] in
            let url = URL(string: "https://api.example.com/products/\(id.uuidString)")!
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw URLError(.badServerResponse)
            }
            return try JSONDecoder().decode(Product.self, from: data)
        }
    }
}

// Migration strategy
// I introduce this behind an existing repository protocol and measure request
// count per endpoint first. I only coalesce idempotent reads; writes need explicit
// command semantics because collapsing them can lose user intent.
//
// Production notes
// I keep cache TTL, retries, and cancellation policy outside this type. In
// particular, one caller cancelling should not cancel shared work for every other
// caller unless the product requirement says it should.
