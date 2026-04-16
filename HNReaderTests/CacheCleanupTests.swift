//
//  CacheCleanupTests.swift
//  HNReader
//
//  Unit tests for cache cleanup functionality
//

import XCTest

class CacheCleanupTests: XCTestCase {
    
    private let cache = CacheManager.shared
    private let fileManager = FileManager.default
    
    override func setUp() {
        super.setUp()
        // Clean up test cache files before each test
        cleanupTestCacheFiles()
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up test cache files after each test
        cleanupTestCacheFiles()
    }
    
    /// Test that cleanup removes entries older than 24 hours
    func testCleanupRemovesExpiredEntries() async {
        let testCommentIds = [30001, 30002, 30003]
        
        // Create and cache test comments
        for id in testCommentIds {
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
        
        // Verify all comments are cached
        for id in testCommentIds {
            let comment = await cache.getComment(id: id)
            XCTAssertNotNil(comment, "Comment \(id) should be in cache before cleanup")
        }
        
        // Make first two comments old (25 hours)
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        let oldDate = Date().addingTimeInterval(-25 * 60 * 60)
        
        for id in [testCommentIds[0], testCommentIds[1]] {
            let fileName = "hn_comment_\(id).json"
            let fileURL = cacheDirectory.appendingPathComponent(fileName)
            try? fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileURL.path)
        }
        
        // Run cleanup
        await cache.cleanupExpiredCache()
        
        // Verify old entries are removed
        let comment1 = await cache.getComment(id: testCommentIds[0])
        let comment2 = await cache.getComment(id: testCommentIds[1])
        XCTAssertNil(comment1, "Old comment 1 should be removed by cleanup")
        XCTAssertNil(comment2, "Old comment 2 should be removed by cleanup")
        
        // Verify recent entry is preserved
        let comment3 = await cache.getComment(id: testCommentIds[2])
        XCTAssertNotNil(comment3, "Recent comment should be preserved by cleanup")
    }
    
    /// Test that cleanup preserves recent entries
    func testCleanupPreservesRecentEntries() async {
        let testCommentIds = [30004, 30005, 30006]
        
        // Create and cache test comments
        for id in testCommentIds {
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
        
        // Run cleanup (all entries are recent)
        await cache.cleanupExpiredCache()
        
        // Verify all recent entries are preserved
        for id in testCommentIds {
            let comment = await cache.getComment(id: id)
            XCTAssertNotNil(comment, "Recent comment \(id) should be preserved by cleanup")
        }
    }
    
    /// Test that cleanup handles mixed old and new entries
    func testCleanupHandlesMixedEntries() async {
        let oldIds = [30007, 30008]
        let newIds = [30009, 30010]
        
        // Create old entries
        for id in oldIds {
            let comment = Comment(
                id: id,
                text: "Old comment \(id)",
                by: "user",
                time: Int(Date().timeIntervalSince1970),
                kids: nil,
                parent: 100,
                deleted: nil,
                dead: nil
            )
            try? await cache.saveComment(comment)
        }
        
        // Create new entries
        for id in newIds {
            let comment = Comment(
                id: id,
                text: "New comment \(id)",
                by: "user",
                time: Int(Date().timeIntervalSince1970),
                kids: nil,
                parent: 100,
                deleted: nil,
                dead: nil
            )
            try? await cache.saveComment(comment)
        }
        
        // Age the old entries
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        let oldDate = Date().addingTimeInterval(-25 * 60 * 60)
        
        for id in oldIds {
            let fileName = "hn_comment_\(id).json"
            let fileURL = cacheDirectory.appendingPathComponent(fileName)
            try? fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileURL.path)
        }
        
        // Run cleanup
        await cache.cleanupExpiredCache()
        
        // Verify old entries are removed
        for id in oldIds {
            let comment = await cache.getComment(id: id)
            XCTAssertNil(comment, "Old comment \(id) should be removed")
        }
        
        // Verify new entries are preserved
        for id in newIds {
            let comment = await cache.getComment(id: id)
            XCTAssertNotNil(comment, "New comment \(id) should be preserved")
        }
    }
    
    /// Test that cleanup works with story comments
    func testCleanupRemovesExpiredStoryComments() async {
        let storyIds = [7001, 7002]
        
        // Create story comments
        for storyId in storyIds {
            let comments = [
                Comment(id: 1, text: "Comment 1", by: "user1", time: Int(Date().timeIntervalSince1970), kids: nil, parent: storyId, deleted: nil, dead: nil)
            ]
            try? await cache.saveStoryComments(storyId: storyId, comments: comments)
        }
        
        // Age the first story comments
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        let oldDate = Date().addingTimeInterval(-25 * 60 * 60)
        
        let fileName = "hn_story_comments_\(storyIds[0]).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        try? fileManager.setAttributes([.modificationDate: oldDate], ofItemAtPath: fileURL.path)
        
        // Run cleanup
        await cache.cleanupExpiredCache()
        
        // Verify old story comments are removed
        let oldStoryComments = await cache.getStoryComments(storyId: storyIds[0])
        XCTAssertNil(oldStoryComments, "Old story comments should be removed")
        
        // Verify recent story comments are preserved
        let newStoryComments = await cache.getStoryComments(storyId: storyIds[1])
        XCTAssertNotNil(newStoryComments, "Recent story comments should be preserved")
    }
    
    /// Test that cleanup doesn't fail on empty cache directory
    func testCleanupHandlesEmptyCache() async {
        // This should not throw or crash
        await cache.cleanupExpiredCache()
        
        // Verify cache is still functional
        let comment = Comment(
            id: 30011,
            text: "Test",
            by: "user",
            time: Int(Date().timeIntervalSince1970),
            kids: nil,
            parent: 100,
            deleted: nil,
            dead: nil
        )
        try? await cache.saveComment(comment)
        
        let retrieved = await cache.getComment(id: 30011)
        XCTAssertNotNil(retrieved, "Cache should still work after cleanup on empty directory")
    }
    
    // MARK: - Helper Methods
    
    private func cleanupTestCacheFiles() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        
        // Remove all test cache files (IDs starting with 3 or 7)
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in files {
                let fileName = fileURL.lastPathComponent
                if fileName.contains("hn_comment_3") || fileName.contains("hn_comment_7") ||
                   fileName.contains("hn_story_comments_7") {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        } catch {
            // Silently fail if directory doesn't exist
        }
    }
}
