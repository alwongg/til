import Foundation

struct Payload: Decodable {
    let values: [String?]
}

func normalizedTags(from payload: Payload) -> [String] {
    payload.values.compactMap { rawValue in
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)

        // I normalize while unwrapping so downstream code receives a real invariant:
        // non-empty tags only, with no second cleanup pass to forget.
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }
}

func legacyNormalizedTags(from payload: Payload) -> [String] {
    payload.values
        .filter { $0 != nil }
        .map { $0!.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .map { $0.lowercased() }
}

// I reach for compactMap when one transform can also decide whether an element survives.
// filter + map is clearer when filtering and transformation are genuinely separate decisions.
