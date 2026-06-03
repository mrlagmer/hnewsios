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

            // Fetch comments for these top-level IDs (includes nested replies).
            // Passing the full slice lets HackerNewsAPI parallelize up to its
            // maxParallelRequests limit; awaiting one ID at a time forces serial fetches.
            let allComments = try await api.fetchComments(ids: slice)

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

            let newComments = try await api.fetchComments(ids: slice)

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
        // Index comments by id, and group child ids by parent id. We can't build
        // the tree by mutating CommentNodes in a dictionary because CommentNode is
        // a value type — appending children to `map[parentId]` mutates a copy, so
        // grandchildren attached after their parent has already been wired into
        // its own parent would be silently dropped (the symptom: deep threads
        // appearing only one level deep).
        var commentsById: [Int: Comment] = [:]
        var childIdsByParent: [Int: [Int]] = [:]

        for comment in comments where comment.isValid {
            commentsById[comment.id] = comment
            childIdsByParent[comment.parent, default: []].append(comment.id)
        }

        // Recursively materialize CommentNodes, sorting children by time ascending
        // (oldest reply first) which matches HN's display order within a thread.
        func makeNode(for id: Int) -> CommentNode? {
            guard let comment = commentsById[id] else { return nil }
            let childIds = childIdsByParent[id] ?? []
            let children = childIds
                .compactMap { commentsById[$0] }
                .sorted { ($0.time ?? 0) < ($1.time ?? 0) }
                .compactMap { makeNode(for: $0.id) }
            return CommentNode(comment: comment, children: children)
        }

        let rootIds = childIdsByParent[storyId] ?? []
        let roots = rootIds.compactMap { makeNode(for: $0) }

        // Default ordering for roots: newest top-level comment first. The view
        // controller re-sorts roots per the user's SortOption.
        return roots.sorted { ($0.comment.time ?? 0) > ($1.comment.time ?? 0) }
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
