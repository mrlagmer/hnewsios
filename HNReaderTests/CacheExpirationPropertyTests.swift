//
//  CacheExpirationPropertyTests.swift
//  HNReader
//
//  Property-based tests for cache expiration
//

import XCTest

class CacheExpirationPropertyTests: XCTestCase {
    
    private let cache = CacheManager.shared
    
    /// Property 24: Cache Expiration
    /// For any cached comment older than 24 hours, the cache manager SHALL treat it as expired and refetch from the network.
    /// Validates: Requirements 7.5
    func testCacheExpirationAfter24Hours() async {
        let testCommentId = 20000
        let testComment = Comment(
            id: testCommentId,
            text: "Test comment",
            by: "testuser",
            time: Int(Date().timeIntervalSince1970),
            kids: nil,
            parent: 100,
            deleted: nil,
            dead: nil
        )
        
        // Save comment to cache
        try? await cache.saveComment(testComment)
        
        // Verify comment is in cache
        var cachedComment = await cache.getComment(id: testCommentId)
        XCTAssertNotNil(cachedComment)
        
        // Simulate cache file being old (25 hours old)
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        let fileName = "hn_comment_\(testCommentId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        // Set file modification date to 25 hours ago
        let oldDate = Date().addingTimeInterval(-25 * 60 * 60)
        try? fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileURL.path)
        
        // Try to retrieve expired comment
        cachedComment = await cache.getComment(id: testCommentId)
        
        // Verify expired comment is treated as nil (expired)
        XCTAssertNil(cachedComment)
    }
    
    /// Verify that recent cache entries are not expired
    func testRecentCacheNotExpired() async {
        let testCommentId = 20001
        let testComment = Comment(
            id: testCommentId,
            text: "Recent comment",
            by: "testuser",
            time: Int(Date().timeIntervalSince1970),
            kids: nil,
            parent: 100,
            deleted: nil,
            dead: nil
        )
        
        // Save comment to cache
        try? await cache.saveComment(testComment)
        
        // Immediately retrieve (should not be expired)
        let cachedComment = await cache.getComment(id: testCommentId)
        
        // Verify recent comment is still valid
        XCTAssertNotNil(cachedComment)
        XCTAssertEqual(cachedComment?.id, testCommentId)
    }
    
    /// Verify that cache expiration works for story comments
    func testStoryCommentsCacheExpiration() async {
        let storyId = 6000
        let testComments = [
            Comment(id: 1, text: "Comment 1", by: "user1", time: Int(Date().timeIntervalSince1970), kids: nil, parent: storyId, deleted: nil, dead: nil)
        ]
        
        // Save story comments to cache
        try? await cache.saveStoryComments(storyId: storyId, comments: testComments)
        
        // Verify comments are in cache
        var cachedComments = await cache.getStoryComments(storyId: storyId)
        XCTAssertNotNil(cachedComments)
        
        // Simulate cache file being old (25 hours old)
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        let fileName = "hn_story_comments_\(storyId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        // Set file modification date to 25 hours ago
        let oldDate = Date().addingTimeInterval(-25 * 60 * 60)
        try? fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileURL.path)
        
        // Try to retrieve expired story comments
        cachedComments = await cache.getStoryComments(storyId: storyId)
        
        // Verify expired comments are treated as nil
        XCTAssertNil(cachedComments)
    }
    
    /// Verify that cache expiration boundary is exactly 24 hours
    func testCacheExpirationBoundary() async {
        let testCommentId = 20002
        let testComment = Comment(
            id: testCommentId,
            text: "Boundary test",
            by: "testuser",
            time: Int(Date().timeIntervalSince1970),
            kids: nil,
            parent: 100,
            deleted: nil,
            dead: nil
        )
        
        // Save comment to cache
        try? await cache.saveComment(testComment)
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        let fileName = "hn_comment_\(testCommentId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        // Test just under 24 hours (should not be expired)
        let almostExpiredDate = Date().addingTimeInterval(-(24 * 60 * 60 - 1))
        try? fileManager.setAttributes([.modificationDate: almostExpiredDate], ofItemAtPath: fileURL.path)
        
        var cachedComment = await cache.getComment(id: testCommentId)
        XCTAssertNotNil(cachedComment, "Comment just under 24 hours should not be expired")
        
        // Test just over 24 hours (should be expired)
        let expiredDate = Date().addingTimeInterval(-(24 * 60 * 60 + 1))
        try? fileManager.setAttributes([.modificationDate: expiredDate], ofItemAtPath: fileURL.path)
        
        cachedComment = await cache.getComment(id: testCommentId)
        XCTAssertNil(cachedComment, "Comment just over 24 hours should be expired")
    }
    
    /// Verify that multiple cache entries expire independently
    func testMultipleCacheEntriesExpireIndependently() async {
        let testIds = [20003, 20004, 20005]
        
        // Create and cache test comments
        for id in testIds {
            let comment = Comment(
                id: id,
                text: "Comment \(id)",
                by: "user",
                time: Int(Date().timeIntervalSince1970),
                kids: nil,
                parent: 100,
                deleted: nil,
                dead: nil
            )
            try? await cache.saveComment(comment)
        }
        
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        
        // Expire only the first comment
        let fileName = "hn_comment_\(testIds[0]).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        let oldDate = Date().addingTimeInterval(-25 * 60 * 60)
        try? fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileURL.path)
        
        // Verify first is expired, others are not
        let comment1 = await cache.getComment(id: testIds[0])
        let comment2 = await cache.getComment(id: testIds[1])
        let comment3 = await cache.getComment(id: testIds[2])
        
        XCTAssertNil(comment1, "First comment should be expired")
        XCTAssertNotNil(comment2, "Second comment should not be expired")
        XCTAssertNotNil(comment3, "Third comment should not be expired")
    }
}
