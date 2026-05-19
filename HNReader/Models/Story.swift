//
//  Story.swift
//  HNReader
//
//  Model representing a Hacker News story
//

import Foundation

struct Story: Codable, Identifiable {
    let id: Int
    let title: String
    let score: Int
    let descendants: Int  // Comment count
    let url: String?
    let by: String?
    let time: Int
    let kids: [Int]?      // Top-level comment IDs

    // Computed/transient properties (not from API)
    var topComment: Comment?
    var socialImageURL: URL?
    var allComments: [Comment]?

    // Validation
    var isValid: Bool {
        !title.isEmpty && id > 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, score, descendants, url, by, time, kids, deleted, dead
        case topComment, socialImageURL
    }

    init(id: Int, title: String, score: Int, descendants: Int, url: String?, by: String?, time: Int, kids: [Int]?) {
        self.id = id
        self.title = title
        self.score = score
        self.descendants = descendants
        self.url = url
        self.by = by
        self.time = time
        self.kids = kids
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Reject deleted or dead items so they don't appear in the feed.
        let deleted = (try? container.decode(Bool.self, forKey: .deleted)) ?? false
        let dead = (try? container.decode(Bool.self, forKey: .dead)) ?? false
        if deleted || dead {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "Story is deleted or dead"
            )
        }

        // HN items occasionally omit optional fields (jobs lack descendants,
        // brand-new posts may be missing score). Decode defensively so
        // legitimate stories aren't dropped from the feed.
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.score = try container.decodeIfPresent(Int.self, forKey: .score) ?? 0
        self.descendants = try container.decodeIfPresent(Int.self, forKey: .descendants) ?? 0
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
        self.by = try container.decodeIfPresent(String.self, forKey: .by)
        self.time = try container.decodeIfPresent(Int.self, forKey: .time) ?? 0
        self.kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        self.topComment = try container.decodeIfPresent(Comment.self, forKey: .topComment)
        self.socialImageURL = try container.decodeIfPresent(URL.self, forKey: .socialImageURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(score, forKey: .score)
        try container.encode(descendants, forKey: .descendants)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(by, forKey: .by)
        try container.encode(time, forKey: .time)
        try container.encodeIfPresent(kids, forKey: .kids)
        try container.encodeIfPresent(topComment, forKey: .topComment)
        try container.encodeIfPresent(socialImageURL, forKey: .socialImageURL)
    }
}

