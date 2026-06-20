import Foundation

/*
# Quick Concept: I use actors as ownership boundaries, not thread-safety stickers

When a search flow starts feeling fragile, I usually find the real bug isn't "concurrency" in the abstract. It's ownership. Too many places can mutate the same request lifecycle.

## Legacy approach
I keep `Task?`, `latestQuery`, loading flags, and stale-result guards inside a view model. It works for a while, but every new condition adds another branch where cancellation, ordering, or state cleanup can drift.

## Modern approach
I move the mutable request lifecycle behind one actor. The view model asks for results, but it no longer owns sequencing rules. The actor becomes the single place that decides which result is still valid.

## Migration strategy
1. Identify one async workflow that currently needs cancellation or stale-result protection.
2. Move only the mutable coordination state into an actor.
3. Keep networking and decoding outside the actor so the boundary stays small.
4. Return plain values back to the UI layer.

## Production notes
- I treat actors as ownership boundaries first, synchronization tools second.
- If an actor grows into a god object, I split by workflow, not by method count.
- I still design APIs so the UI can render partial states intentionally; actors don't replace product thinking.
*/

protocol SearchServing {
    func search(query: String) async throws -> [String]
}

struct MockSearchService: SearchServing {
    func search(query: String) async throws -> [String] {
        try await Task.sleep(for: .milliseconds(120))
        return [
            "\(query) overview",
            "\(query) examples",
            "\(query) pitfalls"
        ]
    }
}

actor SearchPipeline {
    private var generation: Int = 0

    func run(query: String, service: SearchServing) async throws -> [String] {
        generation += 1
        let currentGeneration = generation

        let results = try await service.search(query: query)

        guard currentGeneration == generation else {
            return []
        }

        return results
    }
}

@main
enum Demo {
    static func main() async {
        let pipeline = SearchPipeline()
        let service = MockSearchService()

        async let first = pipeline.run(query: "swift actors", service: service)
        async let second = pipeline.run(query: "swift macros", service: service)

        let settledResults = try? await (first, second)
        print(settledResults?.0 ?? [])   // older request can be discarded
        print(settledResults?.1 ?? [])   // latest request wins
    }
}
