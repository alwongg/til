import Foundation

struct Product: Sendable {
    let id: UUID
    let name: String
}

protocol ProductRepository: Sendable {
    func product(id: UUID) async throws -> Product?
}

struct InMemoryProductRepository: ProductRepository {
    private let storage: [UUID: Product]

    init(products: [Product]) {
        self.storage = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }

    func product(id: UUID) async throws -> Product? {
        storage[id]
    }
}

struct LoadProductNameUseCase: Sendable {
    let repository: any ProductRepository

    func execute(id: UUID) async throws -> String {
        guard let product = try await repository.product(id: id) else { return "Missing product" }
        return product.name
    }
}

@main
enum Demo {
    static func main() async throws {
        let featured = Product(id: UUID(), name: "Featured Headphones")
        let repository = InMemoryProductRepository(products: [featured])
        let useCase = LoadProductNameUseCase(repository: repository)

        print(try await useCase.execute(id: featured.id))
    }
}

// I reach for the repository pattern when I want feature code to depend on data shape, not transport details.
// The payoff is that the use case reads the same whether the source is memory, disk, or a remote client.
// In production that keeps tests cheap and stops view models from learning URLSession trivia they should never own.
