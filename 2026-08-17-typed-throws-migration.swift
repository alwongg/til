import Foundation

/// # Typed throws: turning error contracts into part of the API
///
/// I used to expose validation failures as `throws` and rely on callers to
/// discover the possible errors from implementation details. That made a small
/// domain contract easy to accidentally widen during refactors.
///
/// ## Legacy approach
/// `func makeName(_ raw: String) throws -> DisplayName`
///
/// The untyped signature says that *any* error may escape. Callers cannot tell
/// whether they should handle validation, persistence, or transport failures.
///
/// ## Modern approach
/// I use typed throws at domain boundaries when the error set is deliberately
/// small and stable. The signature now documents what recovery is meaningful.
enum DisplayNameError: Error, Equatable {
    case empty
    case tooShort(minimum: Int)
}

struct DisplayName: Equatable {
    let value: String

    init(_ raw: String) throws(DisplayNameError) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }
        guard trimmed.count >= 2 else { throw .tooShort(minimum: 2) }
        value = trimmed
    }
}

func makeDisplayName(from raw: String) throws(DisplayNameError) -> DisplayName {
    try DisplayName(raw)
}

/// ## Migration strategy
/// I start at pure domain functions, where every failure is already expected.
/// At SDK or I/O boundaries I keep untyped `throws`: those dependencies can
/// legitimately add new failure modes. I translate them into a typed domain
/// error only at the boundary where the app chooses a recovery path.
///
/// ## Production notes
/// Typed throws are not a reason to erase diagnostics. I log the original
/// infrastructure error before mapping it, then return a small error vocabulary
/// that the UI can render and test exhaustively. The payoff is safer refactors:
/// adding a new domain failure makes affected call sites visible at compile time.
