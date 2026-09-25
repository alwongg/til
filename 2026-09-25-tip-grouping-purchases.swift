import Foundation

struct Purchase: Sendable {
    let customerID: UUID
    let amount: Decimal
}

func totalsByCustomer(for purchases: [Purchase]) -> [UUID: Decimal] {
    Dictionary(grouping: purchases, by: \.customerID)
        .mapValues { customerPurchases in
            // Group first, then reduce locally: this keeps the aggregation explicit.
            customerPurchases.reduce(Decimal.zero) { $0 + $1.amount }
        }
}

func customerIDsWithMultiplePurchases(in purchases: [Purchase]) -> Set<UUID> {
    let purchasesByCustomer = Dictionary(grouping: purchases, by: \.customerID)

    // The grouped dictionary is also a useful boundary for business rules.
    return Set(
        purchasesByCustomer
            .filter { $0.value.count > 1 }
            .map(\ .key)
    )
}
