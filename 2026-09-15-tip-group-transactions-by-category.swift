// I use Dictionary(grouping:by:) when the grouping key is real domain data.
// It keeps the grouping pass linear and lets the result express the UI sections directly.

import Foundation

struct Transaction: Identifiable {
    let id: UUID
    let merchant: String
    let category: Category
    let amount: Decimal
}

enum Category: String, CaseIterable {
    case groceries, transport, subscriptions
}

func totalsByCategory(_ transactions: [Transaction]) -> [Category: Decimal] {
    let grouped = Dictionary(grouping: transactions, by: \.category)

    return grouped.mapValues { transactions in
        // Reducing inside each bucket keeps the aggregation next to the grouping rule.
        transactions.reduce(Decimal.zero) { $0 + $1.amount }
    }
}

func sections(for transactions: [Transaction]) -> [(category: Category, items: [Transaction])] {
    Dictionary(grouping: transactions, by: \.category)
        .map { (category: $0.key, items: $0.value) }
        .sorted { $0.category.rawValue < $1.category.rawValue }
}
