/*
 # Quick Concept: Parse at the Boundary, Trust Inside

 I used to pass raw strings through every layer and validate them repeatedly.
 That made an invalid email representable everywhere. My current default is to
 parse once at the boundary, then pass a small value type through the feature.

 ## Legacy approach
 `func sendWelcome(to email: String)` makes every caller remember validation.
 The same string can be empty, malformed, or already normalized.

 ## Modern approach
 `EmailAddress` makes construction the validation point. Internal APIs receive
 a value that already satisfies the invariant, so their signatures describe
 what they actually need.

 ## Migration strategy
 Start at one boundary—form submission, decoded JSON, or a deep link. Convert
 the raw value there and return a useful error to the UI. Keep adapters at the
 edge while older callers move over; do not spread optional validation checks
 through the domain layer.

 ## Production notes
 This deliberately performs only lightweight structural validation. Email
 deliverability needs confirmation, not an increasingly clever regex. Keep
 normalization explicit, log rejected boundary input without sensitive values,
 and use a distinct type for each similarly shaped identifier.
 */

import Foundation

struct EmailAddress: Hashable, Sendable {
    let value: String

    init?(_ rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // This is a boundary guard, not an attempt to prove deliverability.
        guard normalized.contains("@"),
              normalized.split(separator: "@", maxSplits: 1).allSatisfy({ !$0.isEmpty })
        else { return nil }

        value = normalized
    }
}

struct WelcomeService {
    func sendWelcome(to email: EmailAddress) {
        // No second validation: the type is the proof of the invariant.
        print("Sending welcome email to \(email.value)")
    }
}
