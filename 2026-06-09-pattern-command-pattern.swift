import Foundation

// I reach for the command pattern when a button tap should become replayable work instead of inlined mutation.
// That makes undo, logging, batching, and delayed execution much easier to layer on later.

struct Playlist {
    var songs: [String] = []
}

struct Command {
    let execute: (inout Playlist) -> Void
    let undo: (inout Playlist) -> Void
}

struct CommandRunner {
    private var history: [Command] = []

    mutating func run(_ command: Command, on playlist: inout Playlist) {
        command.execute(&playlist)
        history.append(command)
    }

    mutating func undoLast(on playlist: inout Playlist) {
        guard let command = history.popLast() else { return }
        command.undo(&playlist)
    }
}

extension Command {
    static func addSong(_ song: String) -> Command {
        Command(
            execute: { $0.songs.append(song) },
            undo: { _ = $0.songs.popLast() }
        )
    }
}

@main
enum CommandPatternDemo {
    static func main() {
        var playlist = Playlist()
        var runner = CommandRunner()

        runner.run(.addSong("Intro"), on: &playlist)
        runner.run(.addSong("Deep Work"), on: &playlist)
        print("after commands:", playlist.songs)

        runner.undoLast(on: &playlist)
        print("after undo:", playlist.songs)
    }
}
