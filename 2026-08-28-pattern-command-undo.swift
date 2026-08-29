// Command Pattern: undoable editor actions
//
// I use commands when a UI event should become a testable, replayable object.
// The editor owns state; each command owns the minimum delta needed for undo.

import Foundation

final class Document {
    private(set) var text = ""

    func insert(_ value: String, at offset: Int) {
        text.insert(contentsOf: value, at: text.index(text.startIndex, offsetBy: offset))
    }

    func remove(count: Int, at offset: Int) {
        let start = text.index(text.startIndex, offsetBy: offset)
        text.removeSubrange(start..<text.index(start, offsetBy: count))
    }
}

protocol Command {
    func execute()
    func undo()
}

final class InsertText: Command {
    private let document: Document
    private let value: String
    private let offset: Int

    init(_ value: String, at offset: Int, in document: Document) {
        self.value = value; self.offset = offset; self.document = document
    }

    func execute() { document.insert(value, at: offset) }
    func undo() { document.remove(count: value.count, at: offset) }
}

final class CommandHistory {
    private var undoStack: [Command] = []

    func run(_ command: Command) {
        command.execute()
        undoStack.append(command) // Record only work that actually ran.
    }

    func undo() { undoStack.popLast()?.undo() }
}

@main
struct Demo {
    static func main() {
        let document = Document()
        let history = CommandHistory()
        history.run(InsertText("Hello", at: 0, in: document))
        history.undo()
    }
}
