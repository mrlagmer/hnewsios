import Foundation

struct CacheEntry: Codable {
    let comment: Comment
    let timestamp: Double
}

struct StoryCacheEntry: Codable {
    let comments: [Comment]
    let timestamp: Double
}

struct StoriesCacheEntry: Codable {
    let stories: [Story]
    let timestamp: Double
}
