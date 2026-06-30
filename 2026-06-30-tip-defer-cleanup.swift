import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ReleaseChecklist {
    let steps: [String]

    func step(at index: Int) -> String {
        // Returning a fallback keeps the call site readable while still
        // making the out-of-bounds case explicit.
        self.steps[safe: index] ?? "Missing step"
    }
}
