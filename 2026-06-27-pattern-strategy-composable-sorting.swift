import Foundation

// I like strategy when ranking rules change faster than the feature shell around them.
// Each rule stays isolated, tests get sharper, and I can reorder the behavior without
// turning one sort closure into a nested if-else wall.

struct Article {
    let title: String
    let comments: Int
    let isPinned: Bool
}

protocol RankingStrategy {
    func compare(_ lhs: Article, _ rhs: Article) -> Bool
}

struct PinnedFirst: RankingStrategy {
    func compare(_ lhs: Article, _ rhs: Article) -> Bool { lhs.isPinned && !rhs.isPinned }
}

struct MostCommentedFirst: RankingStrategy {
    func compare(_ lhs: Article, _ rhs: Article) -> Bool { lhs.comments > rhs.comments }
}

struct FeedRanker {
    let strategies: [RankingStrategy]

    func rank(_ articles: [Article]) -> [Article] {
        articles.sorted { lhs, rhs in
            for strategy in strategies where strategy.compare(lhs, rhs) != strategy.compare(rhs, lhs) {
                return strategy.compare(lhs, rhs)
            }
            return lhs.title < rhs.title
        }
    }
}
