import Foundation

extension Sequence where Element == String {
    func parsedIntegers_compactMap() -> [Int] {
        compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(trimmed)
        }
    }

    func parsedIntegers_filterThenMap() -> [Int] {
        filter {
            Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        }
        .map {
            Int($0.trimmingCharacters(in: .whitespacesAndNewlines))!
        }
    }
}

@main
struct Demo {
    static func main() {
        let rawIDs = ["42", " 7", "abc", "", "100"]

        let preferred = rawIDs.parsedIntegers_compactMap()
        let olderStyle = rawIDs.parsedIntegers_filterThenMap()

        print(preferred)
        print(olderStyle)
    }
}
