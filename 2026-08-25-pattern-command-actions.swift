import Foundation

// I model user intent as data so it can be queued, logged, retried, or tested.
protocol Command {
    func execute() async throws
}

actor TodoStore {
    private(set) var items: [String] = []

    func add(_ title: String) {
        items.append(title)
    }

    func remove(_ title: String) {
        items.removeAll { $0 == title }
    }
}

struct AddTodo: Command {
    let title: String
    let store: TodoStore

    func execute() async throws {
        await store.add(title)
    }
}

struct RemoveTodo: Command {
    let title: String
    let store: TodoStore

    func execute() async throws {
        await store.remove(title)
    }
}

struct CommandQueue {
    func run(_ commands: [any Command]) async throws {
        for command in commands {
            try await command.execute()
        }
    }
}
