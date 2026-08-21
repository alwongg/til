// Command pattern: model user actions as values so I can compose and undo them.
import Foundation

struct Draft {
    var title = ""
    var tags: [String] = []
}

protocol DraftCommand {
    mutating func execute(on draft: inout Draft)
    mutating func undo(on draft: inout Draft)
}

struct SetTitle: DraftCommand {
    let newTitle: String
    private var previousTitle = ""

    init(newTitle: String) {
        self.newTitle = newTitle
    }

    mutating func execute(on draft: inout Draft) {
        previousTitle = draft.title
        draft.title = newTitle
    }

    mutating func undo(on draft: inout Draft) {
        draft.title = previousTitle
    }
}

struct AddTag: DraftCommand {
    let tag: String

    mutating func execute(on draft: inout Draft) {
        // Keeping this idempotent avoids duplicate tags when UI events replay.
        guard !draft.tags.contains(tag) else { return }
        draft.tags.append(tag)
    }

    mutating func undo(on draft: inout Draft) {
        draft.tags.removeAll { $0 == tag }
    }
}

struct DraftEditor {
    private(set) var draft = Draft()
    private var history: [any DraftCommand] = []

    mutating func apply(_ command: some DraftCommand) {
        var command = command
        command.execute(on: &draft)
        history.append(command)
    }

    mutating func undo() {
        guard var command = history.popLast() else { return }
        command.undo(on: &draft)
    }
}

@main
struct Demo {
    static func main() {
        var editor = DraftEditor()
        editor.apply(SetTitle(newTitle: "Ship the draft"))
        editor.apply(AddTag(tag: "swift"))
        editor.undo()
        print(editor.draft)
    }
}
