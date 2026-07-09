import Foundation

// I reach for `defer` when setup and teardown should stay in the same visual block.
// It keeps cleanup honest even after early returns or thrown errors show up later.
final class ImageDecoder {
    private var activeRequests = 0

    func decode(_ bytes: Data) throws -> String {
        activeRequests += 1
        defer { activeRequests -= 1 }

        guard !bytes.isEmpty else {
            throw CocoaError(.coderInvalidValue)
        }

        let text = String(decoding: bytes, as: UTF8.self)
        return "decoded: \(text) | active=\(activeRequests)"
    }
}

@main
enum Demo {
    static func main() {
        let decoder = ImageDecoder()

        do {
            print(try decoder.decode(Data("thumb".utf8)))
            print(try decoder.decode(Data()))
        } catch {
            // The useful part is that `activeRequests` is still balanced on both paths.
            print("cleanup still ran: \(error.localizedDescription)")
        }
    }
}
