import Foundation

// I use commands when a UI intent should be queued, retried, or audited without
// making a view controller know how the work is performed.
protocol Command {
    associatedtype Output
    func execute() async throws -> Output
}

struct RenameProject: Command {
    let projectID: UUID
    let name: String
    let client: ProjectClient

    func execute() async throws -> Project {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RenameError.emptyName
        }
        return try await client.renameProject(id: projectID, name: name)
    }
}

protocol ProjectClient {
    func renameProject(id: UUID, name: String) async throws -> Project
}

struct Project: Sendable {
    let id: UUID
    let name: String
}

enum RenameError: Error {
    case emptyName
}

// A view model can depend on Command, then tests can substitute a deterministic
// command without constructing networking or a coordinator.
