import Foundation

enum AvatarLoadError: Error {
    case alreadyRefreshing
    case emptyFile
}

final class AvatarLoader {
    private var isRefreshing = false

    func refreshAvatar(from fileURL: URL) throws -> Data {
        guard !isRefreshing else { throw AvatarLoadError.alreadyRefreshing }

        isRefreshing = true
        defer { isRefreshing = false }

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        let data = try handle.readToEnd() ?? Data()
        guard !data.isEmpty else { throw AvatarLoadError.emptyFile }

        // I like defer here because every early return and throw still resets
        // transient state. That keeps my UI from getting stuck in “loading”.
        return data
    }
}
