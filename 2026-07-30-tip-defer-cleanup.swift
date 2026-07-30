// # TIL: Use `defer` to make cleanup survive every exit path
//
// I use `defer` when acquiring a resource creates a cleanup obligation. The
// cleanup is registered beside acquisition, so it survives `throw`, early
// `return`, and future edits that add another exit path.
//
// This is especially useful around file coordination, security-scoped URLs,
// locks, and temporary state. I keep the deferred block small and idempotent:
// it should release exactly what this scope acquired.

import Foundation

enum ImportError: Error {
    case emptyFile
}

func readDocument(at url: URL) throws -> String {
    guard url.startAccessingSecurityScopedResource() else {
        throw CocoaError(.fileNoSuchFile)
    }
    defer { url.stopAccessingSecurityScopedResource() }

    let contents = try String(contentsOf: url, encoding: .utf8)
    guard !contents.isEmpty else { throw ImportError.emptyFile }
    return contents
}

// `stopAccessingSecurityScopedResource()` runs both after a successful return
// and after either throwing operation. Without `defer`, it is too easy for a
// new guard or error path to leak the security-scoped access.
//
// Rule of thumb: register `defer` immediately after the matching acquisition;
// nested resources naturally clean up in reverse acquisition order.
