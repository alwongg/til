// iOS Tip: Make cleanup structural with defer
//
// When I acquire a resource, I put its cleanup beside the acquisition.
// That keeps early returns and thrown errors from silently leaking work.

import Foundation

final class ActivityTracker {
    private(set) var isActive = false

    func begin() { isActive = true }
    func end() { isActive = false }
}

enum ImportError: Error { case invalidPayload }

func importProfile(_ payload: Data, tracker: ActivityTracker) throws -> String {
    tracker.begin()
    defer {
        // This runs on every exit path, including `throw` below.
        tracker.end()
    }

    guard !payload.isEmpty else { throw ImportError.invalidPayload }
    return "Imported \(payload.count) bytes"
}
