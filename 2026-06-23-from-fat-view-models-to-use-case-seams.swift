import Foundation

// From fat view models to use-case seams
//
// Legacy approach
// I used to let one screen model own transport, filtering, sorting, retry
// policy, and UI mapping. That gets a feature out the door, but it also means
// every new business rule lands in the same object.
//
// Modern approach
// My default now is to let the view model coordinate state while a focused use
// case owns the business decision. I still like simple code, but I want one
// explicit seam where the product rule lives.
//
// Migration strategy
// 1. Leave the view and navigation flow alone.
// 2. Extract the most repeated business rule into a single use case.
// 3. Move sorting, filtering, and retry policy behind that seam.
// 4. Keep the repository boundary narrow so tests stay cheap.
//
// Production notes
// - I add protocols at infrastructure edges, not on every type.
// - A use case should read like one decision, not a mini-framework.
// - This split makes previews and tests easier because fake repositories are tiny.
// - When a screen grows, I add more focused use cases instead of a manager object.

enum OrdersError: Error {
    case transport
}

struct Order: Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let isActive: Bool
    let createdAt: Date
}

final class LegacyOrdersClient: @unchecked Sendable {
    func fetchOrders() async throws -> [Order] {
        [
            Order(id: UUID(), title: "Newest active", isActive: true, createdAt: .now),
            Order(id: UUID(), title: "Inactive", isActive: false, createdAt: .now.addingTimeInterval(-120)),
            Order(id: UUID(), title: "Older active", isActive: true, createdAt: .now.addingTimeInterval(-240))
        ]
    }
}

final class LegacyOrdersViewModel {
    private let client: LegacyOrdersClient
    private(set) var visibleOrders: [Order] = []
    private(set) var errorMessage: String?

    init(client: LegacyOrdersClient) {
        self.client = client
    }

    func refresh() async {
        do {
            let response = try await client.fetchOrders()
            visibleOrders = response
                .filter { $0.isActive }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Couldn't load orders. Pull to retry."
        }
    }
}

protocol OrdersRepository: Sendable {
    func fetchOrders() async throws -> [Order]
}

struct LiveOrdersRepository: OrdersRepository {
    private let client: LegacyOrdersClient

    init(client: LegacyOrdersClient) {
        self.client = client
    }

    func fetchOrders() async throws -> [Order] {
        try await client.fetchOrders()
    }
}

struct LoadActiveOrdersUseCase: Sendable {
    private let repository: OrdersRepository

    init(repository: OrdersRepository) {
        self.repository = repository
    }

    func execute() async throws -> [Order] {
        let orders = try await repository.fetchOrders()
        return orders
            .filter { $0.isActive }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

final class OrdersViewModel {
    private let loadOrders: LoadActiveOrdersUseCase
    private(set) var visibleOrders: [Order] = []
    private(set) var errorMessage: String?

    init(loadOrders: LoadActiveOrdersUseCase) {
        self.loadOrders = loadOrders
    }

    func refresh() async {
        do {
            visibleOrders = try await loadOrders.execute()
        } catch {
            errorMessage = "Couldn't load orders. Pull to retry."
        }
    }
}

@main
struct LessonDemo {
    static func main() async {
        let client = LegacyOrdersClient()

        let legacy = LegacyOrdersViewModel(client: client)
        await legacy.refresh()

        let repository = LiveOrdersRepository(client: client)
        let useCase = LoadActiveOrdersUseCase(repository: repository)
        let modern = OrdersViewModel(loadOrders: useCase)
        await modern.refresh()

        assert(legacy.visibleOrders.count == modern.visibleOrders.count)
    }
}
