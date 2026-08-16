// iOS Tip: Group Once, Then Render
//
// I reach for Dictionary(grouping:by:) when a screen needs sections. It keeps
// the grouping rule in one place, rather than scattering filtering logic
// across every section in the view layer.

import Foundation

struct Transaction: Identifiable {
    enum Kind: String, CaseIterable { case food, travel, work }

    let id: UUID
    let kind: Kind
    let merchant: String
    let amount: Decimal
}

func sections(for transactions: [Transaction]) -> [(kind: Transaction.Kind, items: [Transaction])] {
    let grouped = Dictionary(grouping: transactions, by: \.kind)

    // I iterate the enum, not dictionary keys, so empty states and ordering
    // remain deliberate instead of depending on hash order.
    return Transaction.Kind.allCases.compactMap { kind in
        guard let items = grouped[kind], !items.isEmpty else { return nil }
        return (kind, items.sorted { $0.merchant < $1.merchant })
    }
}

// In SwiftUI, I can feed `sections` directly to `ForEach`, with section
// ownership staying out of the view. This is easier to test and extend.