import Foundation

// I use custom CodingKeys when the backend naming is locked,
// but I still want Swift models to read like app code instead of wire format.
// The mapping keeps decoding noise at the boundary and preserves a cleaner domain type.

struct FeedItem: Decodable {
    let id: UUID
    let title: String
    let commentCount: Int
    let isPinned: Bool
    let publishedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id = "feed_id"
        case title = "headline"
        case commentCount = "comment_count"
        case isPinned = "is_pinned"
        case publishedAt = "published_at"
    }
}

@main
struct Demo {
    static func main() throws {
        let json = Data(#"""
        {
          "feed_id": "A3F9B9C7-6A90-4E31-B2F6-5B50B1D4D9B3",
          "headline": "Shipping thinner view models",
          "comment_count": 12,
          "is_pinned": true,
          "published_at": "2026-07-10T14:30:00Z"
        }
        """#.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let item = try decoder.decode(FeedItem.self, from: json)
        print("\(item.title) · \(item.commentCount) comments · pinned=\(item.isPinned)")
    }
}
