// iOS Tip: Make Cleanup Structural with defer
//
// I reach for `defer` when a resource or UI state must be restored on every
// exit path. Register cleanup immediately after acquisition, rather than
// duplicating it beside each return or throw.

import Foundation

enum ImportError: Error {
    case emptyPayload
}

final class ImportController {
    private(set) var isImporting = false

    func importPayload(_ payload: Data) throws -> Int {
        isImporting = true
        defer { isImporting = false }
        // Cleanup is registered before validation, so failures cannot leave UI stuck.

        guard !payload.isEmpty else { throw ImportError.emptyPayload }

        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        // The file is removed whether decoding succeeds, returns early, or throws.

        try payload.write(to: temporaryURL, options: .atomic)
        return payload.count
    }
}

@main
struct Demo {
    static func main() {
        let controller = ImportController()
        let bytes = try? controller.importPayload(Data("cache me".utf8))
        print("Imported \(bytes ?? 0) bytes; busy: \(controller.isImporting)")
    }
}
