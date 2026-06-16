/*
Slot 3 — Swift Snippet
Topic: Custom SwiftUI environment values

I reach for a custom environment value when a view tree needs shared behavior, but I don't want to drag an object graph through every initializer.
This works well for small cross-cutting dependencies like formatting, feature flags, or analytics hooks that should stay easy to override in previews and tests.
*/

import SwiftUI

struct PriceFormatter {
    var string: @Sendable (Decimal) -> String

    static let live = PriceFormatter { amount in
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: number) ?? "$0.00"
    }
}

private struct PriceFormatterKey: EnvironmentKey {
    static let defaultValue = PriceFormatter.live
}

extension EnvironmentValues {
    var priceFormatter: PriceFormatter {
        get { self[PriceFormatterKey.self] }
        set { self[PriceFormatterKey.self] = newValue }
    }
}

struct PriceTag: View {
    @Environment(\.priceFormatter) private var priceFormatter
    let amount: Decimal

    var body: some View {
        Text(priceFormatter.string(amount))
            .font(.headline)
    }
}

struct DemoView: View {
    var body: some View {
        VStack(spacing: 12) {
            PriceTag(amount: 19.99)
            PriceTag(amount: 249.00)
        }
        .padding()
        // I can swap behavior at the edge instead of threading config through every child view.
        .environment(\.priceFormatter, PriceFormatter { amount in "CAD \(amount)" })
    }
}
