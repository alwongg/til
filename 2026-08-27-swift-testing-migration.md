# Migrating iOS Tests from XCTest to Swift Testing

I am not treating Swift Testing as a cosmetic syntax swap. The useful shift is that test intent, inputs, and execution policy become part of the test declaration instead of being spread across `setUp`, `XCTAssert*`, and naming conventions.

## Legacy approach

```swift
final class PriceFormatterTests: XCTestCase {
    private var formatter: PriceFormatter!

    override func setUp() {
        formatter = PriceFormatter(locale: Locale(identifier: "en_CA"))
    }

    func testFormatsWholeDollarAmount() {
        XCTAssertEqual(formatter.string(for: 12), "$12.00")
    }

    func testFormatsNegativeAmount() {
        XCTAssertEqual(formatter.string(for: -12), "-$12.00")
    }
}
```

This works, but the duplicated test shape hides the table of behaviour I actually care about. It also makes parallel execution dangerous when mutable fixture state leaks between tests.

## Modern approach

```swift
import Foundation
import Testing

struct PriceFormatterTests {
    @Test(arguments: [
        (Decimal(12), "$12.00"),
        (Decimal(-12), "-$12.00"),
        (Decimal(string: "12.5")!, "$12.50")
    ])
    func formatsCanadianPrices(amount: Decimal, expected: String) {
        let formatter = PriceFormatter(locale: Locale(identifier: "en_CA"))
        #expect(formatter.string(for: amount) == expected)
    }
}
```

Each argument becomes an independently reported case. I keep dependencies local to the test unless construction is expensive and demonstrably safe to share. `#expect` records a non-fatal failure, which is ideal when a table should report every broken row; I use `try #require(...)` when later assertions would be meaningless without a value.

## Migration strategy

1. Add `import Testing` to a new test file while keeping existing XCTest targets intact. Xcode can run both frameworks in the same test bundle.
2. Migrate pure, parameter-heavy tests first: formatters, reducers, validation, and parsers. They show the readability win immediately.
3. Replace mutable `setUp` fixtures with factory methods or local `let` values. This exposes accidental shared state before parallel tests expose it in CI.
4. Keep XCTest where platform APIs or existing helpers make it the pragmatic choice. A mixed suite is better than a rushed rewrite.
5. Turn on parallel test execution in CI only after validating that injected clocks, file stores, and network stubs are isolated per test.

## Production notes

- Use descriptive test names even with parameterized cases; the name is what survives in CI failure output.
- Put locale, calendar, clock, and UUID generation behind injected dependencies. Tests should not depend on the machine running Xcode Cloud.
- Use traits deliberately for serialization, time limits, or conditions. A trait is an explicit execution contract, not a workaround for flaky tests.
- When a migration changes failures, check assertion semantics before assuming product code regressed: `#expect` continues while `#require` stops the current test.

The outcome I want is not “a modern test framework.” I want a suite where failures tell me the input, the expected contract, and the dependency boundary that broke.
