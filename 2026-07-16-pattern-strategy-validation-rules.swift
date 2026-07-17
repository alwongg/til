import Foundation

// I use Strategy when a feature has one stable workflow but interchangeable rules.
protocol ValidationStrategy {
    func validate(_ value: String) throws
}

struct NonEmpty: ValidationStrategy {
    func validate(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError("This field is required")
        }
    }
}

struct MinimumLength: ValidationStrategy {
    let count: Int

    func validate(_ value: String) throws {
        guard value.count >= count else {
            throw ValidationError("Enter at least \(count) characters")
        }
    }
}

struct ValidationError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct FieldValidator {
    let strategies: [any ValidationStrategy]

    func validate(_ value: String) throws {
        // I keep orchestration fixed while each rule stays independently testable.
        for strategy in strategies { try strategy.validate(value) }
    }
}

@main
enum Demo {
    static func main() {
        let username = FieldValidator(strategies: [NonEmpty(), MinimumLength(count: 4)])
        do { try username.validate("alex"); print("Valid") }
        catch { print(error.localizedDescription) }
    }
}

// In production, I inject strategies at the feature boundary instead of branching
// inside the validator. Adding a rule then changes composition, not stable code.
