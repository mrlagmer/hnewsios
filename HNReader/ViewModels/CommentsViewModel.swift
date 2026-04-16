//
//  CommentsViewModel.swift
//  HNReader
//
//  ViewModel for managing comments for a story
//

import Foundation
import Combine

@MainActor
class CommentsViewModel: ObservableObject {
    @Published var commentTree: [CommentNode] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasLoadedAll: Bool = false
    @Published var errorMessage: String?

    private let api = HackerNewsAPI.shared
    private let cache = CacheManager.shared

    private let storyId: Int
    private let totalComments: Int?
    private var preloadedComments: [Comment]?

    private var loadedTopLevelCount: Int = 0
    private let topLevelBatchSize: Int = 10

    init(storyId: Int, totalComments: Int? = nil, preloadedComments: [Comment]? = nil) {
        self.storyId = storyId
        self.totalComments = totalComments
        self.preloadedComments = preloadedComments
    }

    func loadInitialComments() async {
        isLoading = true
        errorMessage = nil

        // If preloaded comments provided, build tree from them
        if let preloaded = preloadedComments {
            commentTree = buildCommentTree(from: preloaded)
            loadedTopLevelCount = commentTree.count
            hasLoadedAll = true
            isLoading = false
            return
        }

        // Check cache for story comments first
        if let cached = await cache.getStoryComments(storyId: storyId) {
            commentTree = buildCommentTree(from: cached)
            loadedTopLevelCount = commentTree.count
            hasLoadedAll = true
            isLoading = false
            print("✓ Using cached comments for story \(storyId)")
            return
        }

        do {
            // Fetch story to get top-level comment IDs
            let story = try await api.fetchStory(id: storyId)
            let topLevelIDs = story.kids ?? []

            // Determine slice for initial load
            let slice = Array(topLevelIDs.prefix(topLevelBatchSize))

            // Fetch comments for these top-level IDs (includes nested replies)
            var allComments: [Comment] = []
            for id in slice {
                let fetched = try await api.fetchComments(ids: [id])
                allComments.append(contentsOf: fetched)
            }

            // Save to cache
            try await cache.saveStoryComments(storyId: storyId, comments: allComments)

            // Build tree
            commentTree = buildCommentTree(from: allComments)
            loadedTopLevelCount = commentTree.count
            hasLoadedAll = loadedTopLevelCount >= (topLevelIDs.count)
            isLoading = false
        } catch {
            // Try to load from cache on network failure
            if let cached = await cache.getStoryComments(storyId: storyId) {
                commentTree = buildCommentTree(from: cached)
                loadedTopLevelCount = commentTree.count
                hasLoadedAll = true
                errorMessage = "Using cached comments"
                print("⚠️ Network error, using cached comments: \(error)")
            } else {
                errorMessage = "Failed to load comments"
                print("❌ Error loading initial comments (no cache): \(error)")
            }
            isLoading = false
        }
    }

    func loadMoreComments() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        errorMessage = nil

        do {
            let story = try await api.fetchStory(id: storyId)
            let topLevelIDs = story.kids ?? []

            guard loadedTopLevelCount < topLevelIDs.count else {
                hasLoadedAll = true
                isLoadingMore = false
                return
            }

            let start = loadedTopLevelCount
            let end = min(start + topLevelBatchSize, topLevelIDs.count)
            let slice = Array(topLevelIDs[start..<end])

            var newComments: [Comment] = []
            for id in slice {
                let fetched = try await api.fetchComments(ids: [id])
                newComments.append(contentsOf: fetched)
            }

            // Merge with existing flattened comments then rebuild tree to dedupe
            // Retrieve existing flattened comments by flattening current tree
            var flattened: [Comment] = flattenCommentTree(commentTree)
            flattened.append(contentsOf: newComments)

            // Save combined to cache
            try await cache.saveStoryComments(storyId: storyId, comments: flattened)

            // Rebuild tree
            commentTree = buildCommentTree(from: flattened)
            loadedTopLevelCount = commentTree.count
            hasLoadedAll = loadedTopLevelCount >= topLevelIDs.count
            isLoadingMore = false
        } catch {
            isLoadingMore = false
            errorMessage = "Failed to load more comments"
            print("❌ Error loading more comments: \(error)")
        }
    }

    func buildCommentTree(from comments: [Comment]) -> [CommentNode] {
        var map: [Int: CommentNode] = [:]

        // Create nodes for valid comments
        for comment in comments where comment.isValid {
            map[comment.id] = CommentNode(comment: comment, children: [])
        }

        // Attach children to parents
        for node in map.values {
            let parentId = node.comment.parent
            if parentId == storyId {
                // top-level, will be root
                continue
            }
            if var parentNode = map[parentId] {
                parentNode.children.append(node)
                map[parentId] = parentNode
            }
        }

        // Roots are comments whose parent == storyId
        let roots = map.values.filter { $0.comment.parent == storyId }

        // Preserve original order by comment time (descending recent first)
        let sortedRoots = roots.sorted { ($0.comment.time ?? 0) > ($1.comment.time ?? 0) }
        return sortedRoots
    }

    func toggleCollapse(nodeId: Int) {
        func toggle(in nodes: inout [CommentNode]) -> Bool {
            for idx in nodes.indices {
                if nodes[idx].id == nodeId {
                    nodes[idx].isCollapsed.toggle()
                    return true
                }
                if toggle(in: &nodes[idx].children) {
                    return true
                }
            }
            return false
        }

        var copy = commentTree
        _ = toggle(in: &copy)
        commentTree = copy
    }

    // Helper to flatten tree into comments array
    private func flattenCommentTree(_ nodes: [CommentNode]) -> [Comment] {
        var result: [Comment] = []
        for node in nodes {
            result.append(node.comment)
            if !node.children.isEmpty {
                result.append(contentsOf: flattenCommentTree(node.children))
            }
        }
        return result
    }
}
