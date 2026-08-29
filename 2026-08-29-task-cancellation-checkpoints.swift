import Foundation

// Quick Concept: Cancellation Checkpoints
//
// I treat cancellation as a normal control-flow path, not an exceptional failure.
// A task can be cancelled while awaiting, but CPU work between suspension points
// will keep running unless I explicitly give it a checkpoint.

enum ThumbnailError: Error {
    case invalidData
}

func makeThumbnail(from data: Data) async throws -> Data {
    try Task.checkCancellation()

    // Decode is intentionally separated from the expensive transform so each
    // phase has a clear place to stop when the screen no longer needs the work.
    guard !data.isEmpty else { throw ThumbnailError.invalidData }

    let transformed = data.enumerated().map { index, byte -> UInt8 in
        // A real image pipeline would resize or encode here.
        // This lightweight transform keeps the example Foundation-only.
        byte ^ UInt8(index & 0xFF)
    }

    try Task.checkCancellation()
    return Data(transformed)
}

func loadThumbnail(from data: Data) async -> Result<Data, Error>? {
    do {
        return .success(try await makeThumbnail(from: data))
    } catch is CancellationError {
        // A cancelled cell or view has no user-visible error to present.
        return nil
    } catch {
        return .failure(error)
    }
}
