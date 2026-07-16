// # TIL: Group collections in one pass with Dictionary(grouping:by:)
//
// I use `Dictionary(grouping:by:)` when I need buckets, rather than
// hand-rolling a loop with optional dictionary values. The intent stays clear,
// and Swift preserves the source order inside each group.

import Foundation

struct Purchase {
    let category: String
    let amount: Decimal
}

func totalsByCategory(_ purchases: [Purchase]) -> [String: Decimal] {
    let groups = Dictionary(grouping: purchases, by: \.category)

    return groups.mapValues { purchases in
        purchases.reduce(Decimal.zero) { total, purchase in
            total + purchase.amount
        }
    }
}

@main
enum Demo {
    static func main() {
        let purchases = [
            Purchase(category: "Books", amount: 25),
            Purchase(category: "Food", amount: 14),
            Purchase(category: "Books", amount: 40)
        ]

        print(totalsByCategory(purchases))
    }
}
