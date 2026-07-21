// Architecture Patterns Evolved — reducer-driven feature boundaries
//
// I use this shape when a feature outgrows a view model full of unrelated
// methods. The reducer makes state transitions explicit, while dependencies
// stay injectable and easy to replace in tests.

import Foundation

struct Profile: Equatable, Sendable {
    let id: UUID
    let displayName: String
}

protocol ProfileLoading: Sendable {
    func loadProfile() async throws -> Profile
}

@MainActor
final class ProfileFeature {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded(Profile)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private let loader: any ProfileLoading

    init(loader: any ProfileLoading) {
        self.loader = loader
    }

    func send(_ action: Action) async {
        switch action {
        case .appeared, .retryTapped:
            phase = .loading
            do {
                // The side effect lives at the edge; every resulting state is visible here.
                phase = .loaded(try await loader.loadProfile())
            } catch {
                phase = .failed("Could not load profile")
            }
        }
    }

    enum Action {
        case appeared
        case retryTapped
    }
}

// Legacy: a view model exposes load(), retry(), refresh(), and mutates several
// booleans. Call ordering becomes an undocumented part of the API.
//
// Modern: model the feature as state + actions + injected effects. Views render
// Phase and send Action; they do not decide how networking or retries work.
//
// Migration strategy:
// 1. Replace one cluster of booleans with a small Phase enum.
// 2. Route the existing entry point through send(.appeared).
// 3. Inject a protocol-backed loader, then add focused state-transition tests.
//
// Production notes: keep long-lived streams in a cancellable task owned by the
// feature, map domain errors to user-safe messages at this boundary, and split
// only when the action/state surface is no longer cohesive.
