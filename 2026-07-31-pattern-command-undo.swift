# Command Pattern: Undoable Editor Actions

I use commands when a feature needs a stable boundary between a UI event and a reversible state change. The view model records a command; the command owns both the mutation and the inverse.

```swift
protocol EditorCommand {
    mutating func execute(on document: inout Document)
    mutating func undo(on document: inout Document)
}

struct Document {
    var title: String
}

struct RenameCommand: EditorCommand {
    let newTitle: String
    private var previousTitle: String?

    mutating func execute(on document: inout Document) {
        previousTitle = document.title // Capture before changing state so undo is exact.
        document.title = newTitle
    }

    mutating func undo(on document: inout Document) {
        guard let previousTitle else { return }
        document.title = previousTitle
    }
}

struct Editor {
    private(set) var document: Document
    private var undoStack: [any EditorCommand] = []

    mutating func perform(_ command: some EditorCommand) {
        var command = command
        command.execute(on: &document)
        undoStack.append(command)
    }

    mutating func undo() {
        guard var command = undoStack.popLast() else { return }
        command.undo(on: &document)
    }
}
```

**Why I reach for it:** the UI can issue semantic actions (`RenameCommand`, `DeleteBlockCommand`) without duplicating mutation logic. Undo, analytics, and later persistence have one interception point.

**Production note:** I keep commands small and deterministic. For expensive operations, I store an inverse patch rather than a full model snapshot; for remote writes, I treat local undo and server compensation as separate concerns.
