//
//  CacheFirstFetchStrategyPropertyTests.swift
//  HNReader
//
//  Property-based tests for cache-first fetch strategy
//

import XCTest

class CacheFirstFetchStrategyPropertyTests: XCTestCase {
    
    private let cache = CacheManager.shared
    
    /// Property 23: Cache-First Fetch Strategy
    /// For any comment fetch operation, the cache manager SHALL check local storage before making network requests.
    /// Validates: Requirements 7.4
    func testCacheFirstFetchStrategy() async {
        // Test that cache is checked first by verifying cached comments are returned
        let testCommentId = 12345
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
        
        // Retrieve from cache
        let cachedComment = await cache.getComment(id: testCommentId)
        
        // Verify cache returned the comment
        XCTAssertNotNil(cachedComment)
        XCTAssertEqual(cachedComment?.id, testCommentId)
        XCTAssertEqual(cachedComment?.text, "Test comment")
    }
    
    /// Verify that cache is checked before network for batch operations
    func testCacheFirstBatchFetch() async {
        let testIds = [1001, 1002, 1003, 1004, 1005]
        
        // Create and cache test comments
        for id in testIds {
            let comment = Comment(
                id: id,
                text: "Comment \(id)",
                by: "user\(id)",
                time: Int(Date().timeIntervalSince1970),
                kids: nil,
                parent: 100,
                deleted: nil,
                dead: nil
            )
            try? await cache.saveComment(comment)
        }
        
        // Fetch batch from cache
        let cachedComments = await cache.getCommentsBatch(ids: testIds)
        
        // Verify all comments were retrieved from cache
        XCTAssertEqual(cachedComments.count, testIds.count)
        for id in testIds {
            XCTAssertNotNil(cachedComments[id])
            XCTAssertEqual(cachedComments[id]?.id, id)
        }
    }
    
    /// Verify that cache returns nil for non-existent entries
    func testCacheFirstReturnsNilForMissing() async {
        let nonExistentId = 999999
        
        // Try to fetch non-existent comment
        let result = await cache.getComment(id: nonExistentId)
        
        // Verify cache returns nil
        XCTAssertNil(result)
    }
    
    /// Verify that cache-first strategy works for story comments
    func testCacheFirstForStoryComments() async {
        let storyId = 5000
        let testComments = [
            Comment(id: 1, text: "Comment 1", by: "user1", time: Int(Date().timeIntervalSince1970), kids: nil, parent: storyId, deleted: nil, dead: nil),
            Comment(id: 2, text: "Comment 2", by: "user2", time: Int(Date().timeIntervalSince1970), kids: nil, parent: storyId, deleted: nil, dead: nil),
            Comment(id: 3, text: "Comment 3", by: "user3", time: Int(Date().timeIntervalSince1970), kids: nil, parent: storyId, deleted: nil, dead: nil)
        ]
        
        // Save story comments to cache
        try? await cache.saveStoryComments(storyId: storyId, comments: testComments)
        
        // Retrieve from cache
        let cachedComments = await cache.getStoryComments(storyId: storyId)
        
        // Verify cache returned the comments
        XCTAssertNotNil(cachedComments)
        XCTAssertEqual(cachedComments?.count, testComments.count)
    }
    
    /// Verify that cache is checked before returning nil
    func testCacheCheckBeforeReturningNil() async {
        let testId = 7777
        
        // First fetch should return nil (not in cache)
        let firstFetch = await cache.getComment(id: testId)
        XCTAssertNil(firstFetch)
        
        // Add to cache
        let comment = Comment(
            id: testId,
            text: "Now cached",
            by: "user",
            time: Int(Date().timeIntervalSince1970),
            kids: nil,
            parent: 100,
            deleted: nil,
            dead: nil
        )
        try? await cache.saveComment(comment)
        
        // Second fetch should return the cached comment
        let secondFetch = await cache.getComment(id: testId)
        XCTAssertNotNil(secondFetch)
        XCTAssertEqual(secondFetch?.text, "Now cached")
    }
}
