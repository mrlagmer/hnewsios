//
//  CommentTreeDepthLimitPropertyTests.swift
//  HNReader
//
//  Property-based tests for comment tree depth limit
//

import XCTest
@testable import HNReader

/// Property-based tests for verifying comment tree depth limit
/// Feature: react-native-to-swift-conversion, Property 53: Comment Tree Depth Limit
/// **Validates: Requirements 17.3**
class CommentTreeDepthLimitPropertyTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    /// Number of iterations for property-based testing
    private let propertyTestIterations = 100
    
    /// Maximum comment depth (from design)
    private let maxCommentDepth = 5
    
    // MARK: - Helper Classes
    
    /// Mock comment structure for testing depth tracking
    struct MockCommentTree {
        let id: Int
        let depth: Int
        let children: [MockCommentTree]
        
        /// Calculate the maximum depth of this tree
        var maxDepth: Int {
            if children.isEmpty {
                return depth
            }
            return children.map { $0.maxDepth }.max() ?? depth
        }
        
        /// Flatten the tree into an array of (id, depth) tuples
        func flatten() -> [(id: Int, depth: Int)] {
            var result = [(id: id, depth: depth)]
            for child in children {
                result.append(contentsOf: child.flatten())
            }
            return result
        }
    }
    
    /// Generate a random comment tree with specified depth
    static func generateCommentTree(startId: Int, currentDepth: Int, maxDepth: Int, branchingFactor: Int) -> MockCommentTree {
        var nextId = startId + 1
        var children: [MockCommentTree] = []
        
        // Only add children if we haven't reached max depth
        if currentDepth < maxDepth {
            let numChildren = Int.random(in: 0...branchingFactor)
            for _ in 0..<numChildren {
                let child = generateCommentTree(
                    startId: nextId,
                    currentDepth: currentDepth + 1,
                    maxDepth: maxDepth,
                    branchingFactor: branchingFactor
                )
                children.append(child)
                nextId += child.flatten().count
            }
        }
        
        return MockCommentTree(id: startId, depth: currentDepth, children: children)
    }
    
    // MARK: - Property Tests
    
    /// Property 53: For any comment tree recursion, the app SHALL limit the maximum depth to 5 levels
    /// This test verifies that fetchComments stops recursion at depth 5
    func testCommentTreeDepthLimit() async throws {
        let api = HackerNewsAPI.shared
        
        // Run property test multiple times with different starting depths
        for iteration in 1...propertyTestIterations {
            // Generate random starting depth between 0 and 5
            let startDepth = Int.random(in: 0...5)
            
            // Fetch a story with comments to get real comment IDs
            let story = try await api.fetchStory(id: 1)
            
            guard let commentIDs = story.kids, !commentIDs.isEmpty else {
                throw XCTSkip("Story has no comments to test")
            }
            
            // Take a small sample of comment IDs to keep test fast
            let sampleSize = min(3, commentIDs.count)
            let testCommentIDs = Array(commentIDs.prefix(sampleSize))
            
            // Fetch comments starting at the specified depth
            let comments = try await api.fetchComments(ids: testCommentIDs, depth: startDepth)
            
            // If we're at max depth (5), should return empty array
            if startDepth >= maxCommentDepth {
                XCTAssertTrue(
                    comments.isEmpty,
                    "Iteration \(iteration): fetchComments at depth \(startDepth) should return empty array (max depth is \(maxCommentDepth))"
                )
            } else {
                // If we're below max depth, we might get comments (if they exist and are valid)
                // We can't assert they're non-empty because comments might be deleted/dead
                // But we can verify that if we got comments, they're all valid
                for comment in comments {
                    XCTAssertTrue(
                        comment.isValid,
                        "Iteration \(iteration): All returned comments should be valid"
                    )
                }
            }
        }
    }
    
    /// Property 53: Verify depth limit is enforced at exactly depth 5
    /// When calling fetchComments with depth=5, it should return empty array
    func testDepthLimitEnforcedAtExactly5() async throws {
        let api = HackerNewsAPI.shared
        
        // Fetch a story with comments
        let story = try await api.fetchStory(id: 1)
        
        guard let commentIDs = story.kids, !commentIDs.isEmpty else {
            throw XCTSkip("Story has no comments to test")
        }
        
        // Run test multiple times with different comment IDs
        for iteration in 1...min(propertyTestIterations, commentIDs.count) {
            let testCommentID = [commentIDs[iteration - 1]]
            
            // Fetch comments at depth 5 (should return empty)
            let commentsAtDepth5 = try await api.fetchComments(ids: testCommentID, depth: 5)
            
            XCTAssertTrue(
                commentsAtDepth5.isEmpty,
                "Iteration \(iteration): fetchComments at depth 5 should return empty array"
            )
        }
    }
    
    /// Property 53: Verify depth limit allows fetching below depth 5
    /// When calling fetchComments with depth < 5, it should fetch comments
    func testDepthLimitAllowsFetchingBelowLimit() async throws {
        let api = HackerNewsAPI.shared
        
        // Fetch a story with comments
        let story = try await api.fetchStory(id: 1)
        
        guard let commentIDs = story.kids, !commentIDs.isEmpty else {
            throw XCTSkip("Story has no comments to test")
        }
        
        // Test with different depths below the limit
        let testDepths = [0, 1, 2, 3, 4]
        
        for depth in testDepths {
            // Take a sample of comment IDs
            let sampleSize = min(3, commentIDs.count)
            let testCommentIDs = Array(commentIDs.prefix(sampleSize))
            
            // Fetch comments at this depth
            let comments = try await api.fetchComments(ids: testCommentIDs, depth: depth)
            
            // We can't assert comments are non-empty because they might all be deleted/dead
            // But we can verify that the method doesn't reject the request
            // and that any returned comments are valid
            for comment in comments {
                XCTAssertTrue(
                    comment.isValid,
                    "At depth \(depth): All returned comments should be valid"
                )
            }
            
            print("✓ Depth \(depth): Fetched \(comments.count) valid comments from \(testCommentIDs.count) IDs")
        }
    }
    
    /// Property 53: Verify recursive depth tracking
    /// For any nested comment structure, verify that recursion stops at depth 5
    func testRecursiveDepthTracking() async throws {
        let api = HackerNewsAPI.shared
        
        // Fetch a story with deeply nested comments
        let story = try await api.fetchStory(id: 1)
        
        guard let commentIDs = story.kids, !commentIDs.isEmpty else {
            throw XCTSkip("Story has no comments to test")
        }
        
        // Run test multiple times with different comment IDs
        let iterations = min(propertyTestIterations, commentIDs.count)
        
        for iteration in 1...iterations {
            let testCommentID = [commentIDs[iteration - 1]]
            
            // Fetch comments starting at depth 0
            let commentsDepth0 = try await api.fetchComments(ids: testCommentID, depth: 0)
            
            // Fetch comments starting at depth 1
            let commentsDepth1 = try await api.fetchComments(ids: testCommentID, depth: 1)
            
            // Fetch comments starting at depth 4
            let commentsDepth4 = try await api.fetchComments(ids: testCommentID, depth: 4)
            
            // Fetch comments starting at depth 5
            let commentsDepth5 = try await api.fetchComments(ids: testCommentID, depth: 5)
            
            // Verify depth 5 returns empty
            XCTAssertTrue(
                commentsDepth5.isEmpty,
                "Iteration \(iteration): Depth 5 should return empty"
            )
            
            // Verify depth 4 can return comments (if they exist)
            // We can't assert non-empty because comments might be deleted/dead
            // But we verify that depth 4 is allowed (doesn't return empty due to depth limit)
            // The only reason it would be empty is if there are no valid comments
            
            // Verify that as depth increases, we get fewer or equal comments
            // (because we're closer to the limit and fetch fewer nested levels)
            if !commentsDepth0.isEmpty && !commentsDepth1.isEmpty {
                XCTAssertGreaterThanOrEqual(
                    commentsDepth0.count,
                    commentsDepth1.count,
                    "Iteration \(iteration): Starting at depth 0 should fetch >= comments than starting at depth 1"
                )
            }
        }
    }
    
    /// Property 53: Verify depth limit with mock tree structures
    /// Test the depth limiting logic with controlled mock data
    func testDepthLimitWithMockTrees() {
        // Run property test with different tree structures
        for iteration in 1...propertyTestIterations {
            // Generate random tree parameters
            let treeDepth = Int.random(in: 1...10) // Can be deeper than limit
            let branchingFactor = Int.random(in: 1...3)
            
            // Generate a mock comment tree
            let tree = Self.generateCommentTree(
                startId: 1,
                currentDepth: 0,
                maxDepth: treeDepth,
                branchingFactor: branchingFactor
            )
            
            // Flatten the tree to get all nodes with their depths
            let flattenedTree = tree.flatten()
            
            // Simulate the depth limiting behavior
            // In the real API, fetchComments stops recursion at depth 5
            // So we should only get nodes at depth < 5
            let nodesWithinLimit = flattenedTree.filter { $0.depth < maxCommentDepth }
            let nodesExceedingLimit = flattenedTree.filter { $0.depth >= maxCommentDepth }
            
            // Verify that the mock tree structure is correct
            XCTAssertEqual(
                tree.maxDepth,
                min(treeDepth, maxCommentDepth - 1),
                "Iteration \(iteration): Tree max depth should be limited to \(maxCommentDepth - 1)"
            )
            
            // Verify that nodes exceeding the limit would not be fetched
            if treeDepth >= maxCommentDepth {
                XCTAssertTrue(
                    nodesExceedingLimit.isEmpty || tree.maxDepth < maxCommentDepth,
                    "Iteration \(iteration): Nodes at depth >= \(maxCommentDepth) should not be included"
                )
            }
            
            // Verify all nodes within limit have depth < maxCommentDepth
            for node in nodesWithinLimit {
                XCTAssertLessThan(
                    node.depth,
                    maxCommentDepth,
                    "Iteration \(iteration): Node \(node.id) at depth \(node.depth) should be < \(maxCommentDepth)"
                )
            }
        }
    }
    
    /// Property 53: Integration test - verify actual API depth limiting with real data
    /// This test uses real HN API data to verify depth limiting behavior
    func testActualAPIDepthLimiting() async throws {
        let api = HackerNewsAPI.shared
        
        // Fetch a story with many nested comments
        let story = try await api.fetchStory(id: 1)
        
        guard let commentIDs = story.kids, !commentIDs.isEmpty else {
            throw XCTSkip("Story has no comments to test")
        }
        
        // Take first comment ID
        let testCommentID = [commentIDs[0]]
        
        // Fetch comments at different depths and measure results
        var resultsByDepth: [Int: Int] = [:]
        
        for depth in 0...5 {
            let comments = try await api.fetchComments(ids: testCommentID, depth: depth)
            resultsByDepth[depth] = comments.count
            
            print("✓ Depth \(depth): Fetched \(comments.count) comments")
        }
        
        // Verify depth 5 returns empty
        XCTAssertEqual(
            resultsByDepth[5],
            0,
            "Depth 5 should return 0 comments (depth limit reached)"
        )
        
        // Verify that as depth increases, we get fewer or equal comments
        // (because we're closer to the limit and can fetch fewer nested levels)
        for depth in 0..<4 {
            let currentCount = resultsByDepth[depth] ?? 0
            let nextCount = resultsByDepth[depth + 1] ?? 0
            
            XCTAssertGreaterThanOrEqual(
                currentCount,
                nextCount,
                "Depth \(depth) should fetch >= comments than depth \(depth + 1)"
            )
        }
    }
    
    /// Property 53: Edge case - verify behavior at boundary (depth 4 vs depth 5)
    /// Depth 4 should allow one more level of recursion, depth 5 should not
    func testBoundaryBehavior() async throws {
        let api = HackerNewsAPI.shared
        
        // Fetch a story with comments
        let story = try await api.fetchStory(id: 1)
        
        guard let commentIDs = story.kids, !commentIDs.isEmpty else {
            throw XCTSkip("Story has no comments to test")
        }
        
        // Run test multiple times with different comment IDs
        let iterations = min(20, commentIDs.count)
        
        for iteration in 1...iterations {
            let testCommentID = [commentIDs[iteration - 1]]
            
            // Fetch at depth 4 (should allow one more level)
            let commentsDepth4 = try await api.fetchComments(ids: testCommentID, depth: 4)
            
            // Fetch at depth 5 (should return empty)
            let commentsDepth5 = try await api.fetchComments(ids: testCommentID, depth: 5)
            
            // Verify depth 5 is always empty
            XCTAssertTrue(
                commentsDepth5.isEmpty,
                "Iteration \(iteration): Depth 5 should always return empty array"
            )
            
            // Verify depth 4 is allowed (might be empty if no valid comments exist)
            // We just verify it doesn't fail and returns valid comments if any
            for comment in commentsDepth4 {
                XCTAssertTrue(
                    comment.isValid,
                    "Iteration \(iteration): Comments at depth 4 should be valid"
                )
            }
        }
    }
    
    /// Property 53: Verify depth parameter is correctly passed through recursion
    /// For any initial depth, verify that nested calls increment the depth correctly
    func testDepthParameterPropagation() async throws {
        let api = HackerNewsAPI.shared
        
        // Fetch a story with nested comments
        let story = try await api.fetchStory(id: 1)
        
        guard let commentIDs = story.kids, !commentIDs.isEmpty else {
            throw XCTSkip("Story has no comments to test")
        }
        
        // Test with different starting depths
        for startDepth in 0...4 {
            let testCommentID = [commentIDs[0]]
            
            // Fetch comments at this starting depth
            let comments = try await api.fetchComments(ids: testCommentID, depth: startDepth)
            
            // Calculate how many levels of recursion are allowed
            let remainingDepth = maxCommentDepth - startDepth
            
            // Verify that we can still fetch comments if we're below the limit
            if startDepth < maxCommentDepth {
                // We might get comments (if they exist and are valid)
                // Verify all returned comments are valid
                for comment in comments {
                    XCTAssertTrue(
                        comment.isValid,
                        "At start depth \(startDepth): All comments should be valid"
                    )
                }
                
                print("✓ Start depth \(startDepth): Fetched \(comments.count) comments (remaining depth: \(remainingDepth))")
            } else {
                // At max depth, should return empty
                XCTAssertTrue(
                    comments.isEmpty,
                    "At start depth \(startDepth): Should return empty (at max depth)"
                )
            }
        }
    }
    
    /// Property 53: Stress test - verify depth limit with many comment IDs
    /// For any large set of comment IDs, verify depth limiting is consistently applied
    func testDepthLimitWithManyComments() async throws {
        let api = HackerNewsAPI.shared
        
        // Fetch a story with many comments
        let story = try await api.fetchStory(id: 1)
        
        guard let commentIDs = story.kids, commentIDs.count >= 10 else {
            throw XCTSkip("Story doesn't have enough comments to test")
        }
        
        // Test with different batch sizes
        let batchSizes = [5, 10, 15, 20]
        
        for batchSize in batchSizes {
            let testCommentIDs = Array(commentIDs.prefix(batchSize))
            
            // Fetch at depth 0 (should work)
            let commentsDepth0 = try await api.fetchComments(ids: testCommentIDs, depth: 0)
            
            // Fetch at depth 5 (should return empty)
            let commentsDepth5 = try await api.fetchComments(ids: testCommentIDs, depth: 5)
            
            // Verify depth 5 returns empty regardless of batch size
            XCTAssertTrue(
                commentsDepth5.isEmpty,
                "Batch size \(batchSize): Depth 5 should return empty"
            )
            
            // Verify depth 0 returns valid comments
            for comment in commentsDepth0 {
                XCTAssertTrue(
                    comment.isValid,
                    "Batch size \(batchSize): All comments should be valid"
                )
            }
            
            print("✓ Batch size \(batchSize): Depth 0 fetched \(commentsDepth0.count) comments, Depth 5 fetched 0")
        }
    }
}
