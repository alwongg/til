import Foundation

protocol PricingService {
    func subtotal(for items: [CartItem]) -> Decimal
}

protocol TaxService {
    func tax(for subtotal: Decimal) -> Decimal
}

protocol ReceiptService {
    func makeReceipt(subtotal: Decimal, tax: Decimal) -> String
}

struct CartItem {
    let name: String
    let price: Decimal
}

struct DefaultPricingService: PricingService {
    func subtotal(for items: [CartItem]) -> Decimal {
        items.reduce(0) { $0 + $1.price }
    }
}

struct OntarioTaxService: TaxService {
    func tax(for subtotal: Decimal) -> Decimal {
        subtotal * Decimal(string: "0.13")!
    }
}

struct TextReceiptService: ReceiptService {
    func makeReceipt(subtotal: Decimal, tax: Decimal) -> String {
        let total = subtotal + tax
        return "Subtotal: \(subtotal) | Tax: \(tax) | Total: \(total)"
    }
}

struct CheckoutFacade {
    private let pricing: PricingService
    private let tax: TaxService
    private let receipt: ReceiptService

    init(
        pricing: PricingService = DefaultPricingService(),
        tax: TaxService = OntarioTaxService(),
        receipt: ReceiptService = TextReceiptService()
    ) {
        self.pricing = pricing
        self.tax = tax
        self.receipt = receipt
    }

    func checkout(items: [CartItem]) -> String {
        let subtotal = pricing.subtotal(for: items)
        let salesTax = tax.tax(for: subtotal)
        return receipt.makeReceipt(subtotal: subtotal, tax: salesTax)
    }
}
