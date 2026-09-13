// Factory Pattern: keep feature assembly at the boundary
//
// I use a factory when a screen needs several collaborators. The view model
// receives protocols, while this is the one place that chooses live services.
// Tests can still construct CheckoutViewModel with fakes directly.

import Foundation

protocol PaymentSubmitting {
    func submit(amount: Decimal) async throws -> String
}

struct LivePaymentService: PaymentSubmitting {
    func submit(amount: Decimal) async throws -> String {
        // The transport detail stays outside the UI layer.
        "receipt-\(amount)"
    }
}

@MainActor
final class CheckoutViewModel {
    private let payments: any PaymentSubmitting

    init(payments: any PaymentSubmitting) {
        self.payments = payments
    }

    func checkout(amount: Decimal) async throws -> String {
        try await payments.submit(amount: amount)
    }
}

@MainActor
enum CheckoutFactory {
    static func makeViewModel() -> CheckoutViewModel {
        // Composition roots make ownership and production wiring easy to audit.
        CheckoutViewModel(payments: LivePaymentService())
    }
}

// I keep factories feature-scoped; one global container tends to hide dependencies.
