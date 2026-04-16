//
//  StoryFeedViewModel.swift
//  HNReader
//
//  ViewModel for managing the story feed state and business logic
//

import Foundation
import Combine

@MainActor
class StoryFeedViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stories: [Story] = []
    @Published var isLoading: Bool = true
    @Published var isLoadingMore: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var isDownloadingOffline: Bool = false
    @Published var offlineMode: Bool = false
    @Published var downloadProgress: (completed: Int, total: Int) = (0, 0)
    @Published var errorMessage: String?
    
    // MARK: - Services
    private let api = HackerNewsAPI.shared
    private let cache = CacheManager.shared
    private let preloader = WebViewPreloader.shared
    private let imageExtractor = SocialImageExtractor.shared
    
    // MARK: - Private Properties
    private var topStoryIDs: [Int] = []
    private var currentPage: Int = 0
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Setup any necessary initialization
    }
    
    // MARK: - Public Methods
    
    /// Loads the initial set of stories
    func loadInitialStories() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Try to fetch top story IDs from network
            topStoryIDs = try await api.fetchTopStoryIDs()
            
            // Load first page
            await loadPage(0)
            
            isLoading = false
        } catch {
            // Try to restore from cache
            guard let savedPage = await cache.getCurrentPage() else {
                isLoading = false
                errorMessage = "Failed to load stories"
                print("❌ Error loading initial stories (no cache): \(error)")
                return
            }
            
            // Cache fallback: restore saved state
            await restoreState()
            errorMessage = "Using cached data"
            print("⚠️ Network error, using cached data: \(error)")
            isLoading = false
        }
    }
    
    /// Loads the next page of stories
    func loadNextPage() async {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        await loadPage(currentPage)
        
        isLoadingMore = false
    }
    
    /// Refreshes the story feed
    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        
        do {
            // Reset state
            currentPage = 0
            stories = []
            offlineMode = false
            
            // Clear saved state
            await cache.saveScrollPosition(0)
            await cache.saveCurrentPage(0)
            
            // Fetch fresh top story IDs
            topStoryIDs = try await api.fetchTopStoryIDs()
            
            // Load first page
            await loadPage(0)
            
            isRefreshing = false
        } catch {
            isRefreshing = false
            errorMessage = "Failed to refresh stories"
            print("❌ Error refreshing stories: \(error)")
        }
    }
    
    /// Downloads all stories and comments for offline mode
    func downloadForOffline() async {
        isDownloadingOffline = true
        downloadProgress = (0, stories.count)
        errorMessage = nil
        
        let batchSize = 3
        let delayBetweenBatches: UInt64 = 500_000_000  // 500ms in nanoseconds
        
        do {
            for (index, story) in stories.enumerated() {
                // Fetch all comments for this story
                // Note: fetchComments respects maxCommentDepth, but we fetch all top-level comments
                let comments = try await api.fetchComments(ids: story.kids ?? [], depth: 0)
                
                // Save comments to cache
                try await cache.saveStoryComments(storyId: story.id, comments: comments)
                
                // Update progress
                downloadProgress = (index + 1, stories.count)
                
                // Add delay between batches
                if (index + 1) % batchSize == 0 && index + 1 < stories.count {
                    try await Task.sleep(nanoseconds: delayBetweenBatches)
                }
            }
            
            // Preload all story URLs
            let urls = stories.compactMap { $0.url }
            if !urls.isEmpty {
                preloader.preloadMany(urls: urls)
            }
            
            // Enable offline mode
            offlineMode = true
            isDownloadingOffline = false
        } catch {
            isDownloadingOffline = false
            errorMessage = "Failed to download for offline"
            print("❌ Error downloading for offline: \(error)")
        }
    }
    
    /// Restores the app state from cache
    func restoreState() async {
        let savedPage = await cache.getCurrentPage() ?? 0
        
        // Load stories up to saved page
        for page in 0...savedPage {
            await loadPage(page)
        }
        
        currentPage = savedPage
    }

    /// Saves the current page state to cache (called from background notification)
    func saveCurrentPageState() async {
        await cache.saveCurrentPage(currentPage)
    }
    
    // MARK: - Private Methods
    
    /// Loads a specific page of stories
    /// - Parameter page: The page number to load (0-indexed)
    private func loadPage(_ page: Int) async {
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, topStoryIDs.count)
        
        guard startIndex < topStoryIDs.count else { return }
        
        let pageStoryIDs = Array(topStoryIDs[startIndex..<endIndex])
        
        // Fetch story metadata in parallel (limit 20 concurrent requests)
        var pageStories: [Story] = []
        
        for storyID in pageStoryIDs {
            // `fetchStoryMetadata` handles its own errors and returns a fallback Story on failure.
            let story = await fetchStoryMetadata(id: storyID)
            pageStories.append(story)
        }
        
        // Append to stories array
        stories.append(contentsOf: pageStories)
    }
    
    /// Fetches story metadata including top comment and social image
    /// - Parameter id: The story ID
    /// - Returns: Story with metadata
    private func fetchStoryMetadata(id: Int) async -> Story {
        do {
            var story = try await api.fetchStory(id: id)
            
            // Fetch top comment
            if let topCommentId = story.kids?.first {
                story.topComment = try? await api.fetchComment(id: topCommentId)
            }
            
            // Extract social image
            if let url = story.url {
                story.socialImageURL = await imageExtractor.extractSocialImage(from: url)
            }
            
            return story
        } catch {
            print("❌ Error fetching story metadata for \(id): \(error)")
            // Return a default story on error
            return Story(id: id, title: "Error loading story", score: 0, descendants: 0, url: nil, by: nil, time: 0, kids: nil)
        }
    }
}

