// Architecture Patterns Evolved: Replace Delegate Sprawl with Feature Actions
//
// I still like delegates for a tightly scoped UIKit relationship. The failure mode
// I see in larger features is that a view controller slowly becomes a switchboard:
// child delegates, completion closures, notification observers, and navigation
// decisions all land in one object.
//
// Legacy approach
// A child calls `delegate?.didSave(profile)`, then its parent decides whether to
// dismiss, refresh, show an error, and notify another screen. Adding a new outcome
// means changing protocols across the tree.
//
// Modern approach
// I model feature outputs as a closed Action enum. The coordinator owns navigation;
// the view model owns async work; the view renders state and emits intent. This gives
// each feature one explicit outbound channel that stays easy to test.

import Foundation

enum ProfileAction: Equatable {
    case saved(id: UUID)
    case cancelled
    case failed(message: String)
}

protocol ProfileRepository {
    func save(name: String) async throws -> UUID
}

@MainActor
final class ProfileViewModel {
    private let repository: ProfileRepository
    private(set) var isSaving = false
    var onAction: (ProfileAction) -> Void = { _ in }

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func save(name: String) {
        guard !isSaving else { return } // Duplicate taps must not create two writes.
        isSaving = true

        Task {
            defer { isSaving = false }
            do {
                let id = try await repository.save(name: name)
                onAction(.saved(id: id))
            } catch {
                onAction(.failed(message: error.localizedDescription))
            }
        }
    }

    func cancel() {
        onAction(.cancelled)
    }
}

// The coordinator translates feature outcomes into app flow. The view model never
// imports UIKit or SwiftUI navigation types, so its behaviour remains unit-testable.
@MainActor
final class ProfileCoordinator {
    func start(repository: ProfileRepository) -> ProfileViewModel {
        let viewModel = ProfileViewModel(repository: repository)
        viewModel.onAction = { [weak self] action in self?.handle(action) }
        return viewModel
    }

    private func handle(_ action: ProfileAction) {
        switch action {
        case .saved: break // dismiss and refresh the originating feature
        case .cancelled: break // dismiss without mutation
        case .failed: break // route to the presentation layer's error state
        }
    }
}

// Migration strategy
// 1. Wrap one existing delegate callback in an Action enum; do not rewrite the UI.
// 2. Move routing branches to the coordinator, keeping persistence in the repository.
// 3. Add focused tests for actions before deleting the legacy delegate protocol.
//
// Production note: make actions domain-oriented (`.saved(id:)`) rather than UI-oriented
// (`.dismiss`). That keeps the feature reusable when the next presentation changes.
