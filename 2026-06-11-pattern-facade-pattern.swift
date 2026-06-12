import Foundation

// I reach for a facade when a feature needs a clean entry point over several noisy subsystems.
// The payoff is simpler call sites and one place to evolve the workflow when dependencies change.

struct ReleaseNotes {
    let version: String
    let highlights: [String]
}

struct ReleaseFacade {
    let notesLoader: () -> ReleaseNotes
    let artifactUploader: (String) -> URL
    let notifier: (String) -> Void

    func publish() -> URL {
        let notes = notesLoader()
        let payload = """
        Version: \(notes.version)
        Highlights: \(notes.highlights.joined(separator: ", "))
        """

        let url = artifactUploader(payload)
        notifier("Release \(notes.version) shipped: \(url.absoluteString)")
        return url
    }
}

@main
enum FacadePatternDemo {
    static func main() {
        let facade = ReleaseFacade(
            notesLoader: { .init(version: "2.3.0", highlights: ["Offline cache", "Faster launch"]) },
            artifactUploader: { payload in
                print("uploading payload:\n\(payload)")
                return URL(string: "https://example.com/releases/2.3.0")!
            },
            notifier: { print("slack:", $0) }
        )

        let url = facade.publish()
        print("published to", url.absoluteString)
    }
}
