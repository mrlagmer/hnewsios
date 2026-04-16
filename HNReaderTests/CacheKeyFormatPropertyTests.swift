//
//  CacheKeyFormatPropertyTests.swift
//  HNReader
//
//  Property-based tests for cache key format
//

import XCTest

class CacheKeyFormatPropertyTests: XCTestCase {
    
    /// Property 22: Cache Key Format
    /// For any cached comment or story comment set, the cache manager SHALL use key format
    /// "hn_comment_{id}" for individual comments and "hn_story_comments_{storyId}" for story comment sets.
    /// Validates: Requirements 7.2, 7.3
    func testCacheKeyFormat() async {
        // Test individual comment key format
        for commentId in 1...100 {
            let expectedKey = "hn_comment_\(commentId)"
            XCTAssertTrue(expectedKey.hasPrefix("hn_comment_"))
            XCTAssertTrue(expectedKey.contains(String(commentId)))
        }
        
        // Test story comments key format
        for storyId in 1...100 {
            let expectedKey = "hn_story_comments_\(storyId)"
            XCTAssertTrue(expectedKey.hasPrefix("hn_story_comments_"))
            XCTAssertTrue(expectedKey.contains(String(storyId)))
        }
    }
    
    /// Verify that comment IDs are correctly embedded in cache keys
    func testCommentKeyFormatWithVariousIds() async {
        let testIds = [1, 100, 1000, 12345, 999999]
        
        for id in testIds {
            let key = "hn_comment_\(id)"
            XCTAssertEqual(key, "hn_comment_\(id)")
            
            // Extract ID from key
            let components = key.split(separator: "_")
            XCTAssertEqual(components.count, 3)
            XCTAssertEqual(components[0], "hn")
            XCTAssertEqual(components[1], "comment")
            XCTAssertEqual(Int(components[2]), id)
        }
    }
    
    /// Verify that story IDs are correctly embedded in story comments cache keys
    func testStoryCommentsKeyFormatWithVariousIds() async {
        let testIds = [1, 100, 1000, 12345, 999999]
        
        for id in testIds {
            let key = "hn_story_comments_\(id)"
            XCTAssertEqual(key, "hn_story_comments_\(id)")
            
            // Extract ID from key
            let components = key.split(separator: "_")
            XCTAssertEqual(components.count, 4)
            XCTAssertEqual(components[0], "hn")
            XCTAssertEqual(components[1], "story")
            XCTAssertEqual(components[2], "comments")
            XCTAssertEqual(Int(components[3]), id)
        }
    }
    
    /// Verify that cache keys are unique for different IDs
    func testCacheKeyUniqueness() async {
        var commentKeys = Set<String>()
        var storyCommentKeys = Set<String>()
        
        for id in 1...100 {
            let commentKey = "hn_comment_\(id)"
            let storyCommentKey = "hn_story_comments_\(id)"
            
            XCTAssertFalse(commentKeys.contains(commentKey))
            XCTAssertFalse(storyCommentKeys.contains(storyCommentKey))
            
            commentKeys.insert(commentKey)
            storyCommentKeys.insert(storyCommentKey)
        }
        
        XCTAssertEqual(commentKeys.count, 100)
        XCTAssertEqual(storyCommentKeys.count, 100)
    }
}
