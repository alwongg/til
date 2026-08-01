# Parse, Don’t Validate: Model the States I Actually Allow

When I represent a request as a bag of optional fields, every caller has to remember the same validation rules. I prefer parsing raw input once at the boundary, then passing a type that makes the valid state explicit.

## Legacy approach

```swift
struct LegacyRequest {
    let email: String?
    let password: String?
}

func signIn(_ request: LegacyRequest) throws {
    guard let email = request.email, email.contains("@"),
          let password = request.password, password.count >= 12 else {
        throw SignInError.invalidInput
    }
    // Every new entry point must repeat this guard.
}
```

## Modern approach

```swift
import Foundation

enum SignInError: Error {
    case invalidEmail
    case weakPassword
}

struct Email: Sendable, Hashable {
    let value: String

    init(_ rawValue: String) throws {
        let candidate = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.contains("@") else { throw SignInError.invalidEmail }
        value = candidate
    }
}

struct Password: Sendable {
    let value: String

    init(_ rawValue: String) throws {
        guard rawValue.count >= 12 else { throw SignInError.weakPassword }
        value = rawValue
    }
}

struct SignInRequest: Sendable {
    let email: Email
    let password: Password
}

func signIn(_ request: SignInRequest) {
    print("Signing in \(request.email.value)")
}

@main
struct Demo {
    static func main() throws {
        let request = try SignInRequest(
            email: Email("alex@example.com"),
            password: Password("long-enough-password")
        )
        signIn(request)
    }
}
```

## Migration strategy

I keep DTOs permissive at the network/UI boundary, add small parsing initializers beside the use case, and migrate one entry point at a time. The domain layer only accepts `SignInRequest`, so duplicated guards disappear rather than drift.

## Production note

The `Email` check above is deliberately lightweight: product-specific email policy belongs in one parser, not scattered regexes. I also avoid logging `Password.value`; wrapping the secret makes that review boundary obvious.
