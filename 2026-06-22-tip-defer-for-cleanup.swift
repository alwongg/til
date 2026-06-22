import Foundation

// Tip: I use defer when a function has one setup phase and several exit paths.
// It keeps cleanup beside the setup instead of scattering it across success
// and failure branches, which makes maintenance safer under pressure.

private struct ImportPayload: Decodable {
    let title: String
}

enum ImportError: Error {
    case emptyData
}

final class ImportSession {
    private(set) var isImporting = false
    private var stagedFiles: [URL] = []

    func stage(_ fileURL: URL) {
        stagedFiles.append(fileURL)
    }

    func importTitle(from data: Data) throws -> String {
        isImporting = true
        defer {
            isImporting = false
            stagedFiles.removeAll()
        }

        guard !data.isEmpty else { throw ImportError.emptyData }

        let payload = try JSONDecoder().decode(ImportPayload.self, from: data)
        return payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
