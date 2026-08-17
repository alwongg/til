// Command Pattern: reversible editor actions
//
// I use commands when a UI action needs history, analytics, or undo without
// teaching the view layer how the underlying model mutates.

protocol Command {
    func execute()
    func undo()
}

final class Document {
    private(set) var text = ""

    func append(_ value: String) { text += value }
    func removeLast(_ count: Int) {
        text.removeLast(min(count, text.count))
    }
}

final class InsertText: Command {
    private let document: Document
    private let value: String

    init(document: Document, value: String) {
        self.document = document
        self.value = value
    }

    func execute() { document.append(value) }
    func undo() { document.removeLast(value.count) }
}

final class Editor {
    private var history: [Command] = []

    func perform(_ command: Command) {
        command.execute()
        history.append(command)
    }

    func undo() { history.popLast()?.undo() }
}

// The view model depends on Editor, so persistence or telemetry can be added
// around perform(_:) without changing every button action.
