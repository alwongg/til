import Foundation

struct Photo: Sendable {
    let name: String
    let isFavorite: Bool
    let createdAt: Date
}

protocol PhotoSortStrategy {
    func sort(_ photos: [Photo]) -> [Photo]
}

struct FavoritesFirstSortStrategy: PhotoSortStrategy {
    func sort(_ photos: [Photo]) -> [Photo] {
        photos.sorted {
            ($0.isFavorite ? 0 : 1, $1.createdAt) < ($1.isFavorite ? 0 : 1, $0.createdAt)
        }
    }
}

struct NewestFirstSortStrategy: PhotoSortStrategy {
    func sort(_ photos: [Photo]) -> [Photo] {
        photos.sorted { $0.createdAt > $1.createdAt }
    }
}

struct PhotoFeedSorter {
    var strategy: any PhotoSortStrategy

    func makeFeed(from photos: [Photo]) -> [Photo] {
        strategy.sort(photos)
    }
}

let photos = [
    Photo(name: "Receipt", isFavorite: false, createdAt: .now.addingTimeInterval(-60)),
    Photo(name: "Dog", isFavorite: true, createdAt: .now.addingTimeInterval(-3600)),
    Photo(name: "Sunset", isFavorite: false, createdAt: .now)
]

let sorter = PhotoFeedSorter(strategy: FavoritesFirstSortStrategy())
print(sorter.makeFeed(from: photos).map(\.name))

// I use the strategy pattern when product wants to swap behavior without teaching the caller about branching rules.
// In production that keeps A/B tests, premium sorting, and user preferences out of the screen layer.
