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
    /// Which ranked feed is currently shown in the header tab switcher.
    enum FeedTab {
        case top
        case new
    }

    // MARK: - Published Properties
    @Published var stories: [Story] = []
    @Published var isLoading: Bool = true
    @Published var isLoadingMore: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var isDownloadingOffline: Bool = false
    @Published var offlineMode: Bool = false
    @Published var downloadProgress: (completed: Int, total: Int) = (0, 0)
    @Published var errorMessage: String?
    @Published var lastFetchedAt: Date = Date()
    @Published var hasMoreStories: Bool = false

    // New feed (`/newest`) state — recency-ordered, loaded lazily the first
    // time the user switches to the New tab.
    @Published var feedTab: FeedTab = .top
    @Published var newStories: [Story] = []
    @Published var isLoadingNew: Bool = false
    @Published var isLoadingMoreNew: Bool = false
    @Published var hasMoreNewStories: Bool = false
    /// Count of stories that arrived since the New feed was first opened
    /// (drives the "N new since you opened" pill). Populated on refresh.
    @Published var newSinceOpened: Int = 0

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

    // New feed bookkeeping
    private var newStoryIDs: [Int] = []
    private var newCurrentPage: Int = 0
    private var hasLoadedNew: Bool = false
    /// Snapshot of every story ID present when the New feed first loaded. Any ID
    /// fetched later that isn't in here is "new since you opened".
    private var baselineNewIDs: Set<Int> = []
    
    // MARK: - Initialization
    init() {
        // Setup any necessary initialization
    }
    
    // MARK: - Public Methods
    
    /// Loads the initial set of stories
    func loadInitialStories() async {
        isLoading = true
        errorMessage = nil

        if await restoreStoriesFromCache() {
            isLoading = false
            return
        }
        
        do {
            // Try to fetch top story IDs from network
            topStoryIDs = try await api.fetchTopStoryIDs()
            
            // Load first page
            lastFetchedAt = Date()
            await loadPage(0)

            isLoading = false
        } catch {
            // Try to restore from cache
            guard await restoreStoriesFromCache() else {
                isLoading = false
                errorMessage = "Failed to load stories"
                print("❌ Error loading initial stories (no cache): \(error)")
                return
            }
            
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

    // MARK: - New Feed (`/newest`)

    /// Switches the active feed tab, lazily loading the New feed the first time
    /// it's shown.
    func selectTab(_ tab: FeedTab) async {
        guard tab != feedTab else { return }
        feedTab = tab

        if tab == .new && !hasLoadedNew {
            await loadNewStories()
        }
    }

    /// Loads the first page of the newest submissions and establishes the
    /// baseline against which "new since opened" is measured.
    func loadNewStories() async {
        isLoadingNew = true
        errorMessage = nil

        do {
            newStoryIDs = try await api.fetchNewStoryIDs()
            // Everything currently in the feed is the baseline; nothing is
            // flagged "new" on the very first load.
            baselineNewIDs = Set(newStoryIDs)
            newSinceOpened = 0
            newCurrentPage = 0
            newStories = []
            await loadNewPage(0)
            hasLoadedNew = true
            isLoadingNew = false
        } catch {
            isLoadingNew = false
            errorMessage = "Failed to load new stories"
            print("❌ Error loading new stories: \(error)")
        }
    }

    /// Loads the next page of the newest submissions.
    func loadNextNewPage() async {
        guard !isLoadingMoreNew else { return }

        isLoadingMoreNew = true
        newCurrentPage += 1
        await loadNewPage(newCurrentPage)
        isLoadingMoreNew = false
    }

    /// Re-fetches the newest submissions, flagging any that arrived since the
    /// feed was first opened and surfacing their count via `newSinceOpened`.
    func refreshNewStories() async {
        do {
            let freshIDs = try await api.fetchNewStoryIDs()
            newSinceOpened = freshIDs.filter { !baselineNewIDs.contains($0) }.count
            newStoryIDs = freshIDs
            newCurrentPage = 0
            newStories = []
            await loadNewPage(0)
        } catch {
            errorMessage = "Failed to refresh new stories"
            print("❌ Error refreshing new stories: \(error)")
        }
    }

    /// Acknowledges the freshly arrived items (e.g. after tapping the
    /// "N new since you opened" pill): folds them into the baseline so they
    /// stop counting and clears the pill.
    func acknowledgeNewItems() {
        baselineNewIDs = Set(newStoryIDs)
        newSinceOpened = 0
    }

    /// Loads a page of the New feed. Unlike the Top feed these rows don't need
    /// a social image or top-comment preview, so we fetch the bare story.
    private func loadNewPage(_ page: Int) async {
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, newStoryIDs.count)

        guard startIndex < newStoryIDs.count else {
            hasMoreNewStories = false
            return
        }

        let pageStoryIDs = Array(newStoryIDs[startIndex..<endIndex])

        var pageStories: [Story] = []
        for storyID in pageStoryIDs {
            if var story = try? await api.fetchStory(id: storyID) {
                story.isNew = !baselineNewIDs.contains(storyID)
                pageStories.append(story)
            }
        }

        newStories.append(contentsOf: pageStories)
        hasMoreNewStories = endIndex < newStoryIDs.count
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
            await cache.clearScrollPosition()
            await cache.clearCurrentPage()
            
            // Fetch fresh top story IDs
            topStoryIDs = try await api.fetchTopStoryIDs()
            
            // Load first page
            lastFetchedAt = Date()
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
        guard !isDownloadingOffline else { return }

        let articleURLs = stories.compactMap(\.url)
        let totalUnits = stories.count + articleURLs.count

        guard totalUnits > 0 else {
            downloadProgress = (0, 0)
            offlineMode = false
            return
        }

        isDownloadingOffline = true
        offlineMode = false
        downloadProgress = (0, totalUnits)
        errorMessage = nil

        try? await cache.saveStories(stories)

        var completedUnits = 0
        var successfulUnits = 0

        for story in stories {
            do {
                let comments = try await api.fetchComments(ids: story.kids ?? [], depth: 0)
                try await cache.saveStoryComments(storyId: story.id, comments: comments)
                successfulUnits += 1
            } catch {
                print("❌ Error caching comments for story \(story.id): \(error)")
            }

            completedUnits += 1
            downloadProgress = (completedUnits, totalUnits)
        }

        for url in articleURLs {
            let didPreload = await preloader.preloadForOffline(url: url)
            if didPreload {
                successfulUnits += 1
            } else {
                print("❌ Error preloading article for offline use: \(url)")
            }

            completedUnits += 1
            downloadProgress = (completedUnits, totalUnits)
        }

        isDownloadingOffline = false

        if successfulUnits == 0 {
            offlineMode = false
            errorMessage = "Failed to download for offline"
            return
        }

        offlineMode = true
        errorMessage = successfulUnits == totalUnits ? nil : "Some items could not be saved offline"
    }

    func dismissOfflineReadyState() {
        guard !isDownloadingOffline else { return }

        offlineMode = false
        downloadProgress = (0, 0)
    }
    
    /// Restores the app state from cache
    func restoreState() async {
        isLoading = true

        if await restoreStoriesFromCache() {
            isLoading = false
            return
        }

        isLoading = false
    }

    /// Saves the current page state to cache (called from background notification)
    func saveCurrentPageState() async {
        await cache.saveCurrentPage(currentPage)
        try? await cache.saveStories(stories)
    }
    
    // MARK: - Private Methods
    
    /// Loads a specific page of stories
    /// - Parameter page: The page number to load (0-indexed)
    private func loadPage(_ page: Int) async {
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, topStoryIDs.count)
        
        guard startIndex < topStoryIDs.count else { return }
        
        let pageStoryIDs = Array(topStoryIDs[startIndex..<endIndex])
        
        // Fetch story metadata in parallel (limit 20 concurrent requests).
        // Failed fetches (deleted/dead items, decode errors, transient network
        // failures on a single ID) are dropped so they don't appear as broken
        // placeholder cards in the feed.
        var pageStories: [Story] = []

        for storyID in pageStoryIDs {
            if let story = await fetchStoryMetadata(id: storyID) {
                pageStories.append(story)
            }
        }
        
        // Append to stories array
        stories.append(contentsOf: pageStories)
        hasMoreStories = endIndex < topStoryIDs.count

        try? await cache.saveStories(stories)
        await cache.saveCurrentPage(page)
    }

    private func restoreStoriesFromCache() async -> Bool {
        guard let cachedStories = await cache.getStories(), !cachedStories.isEmpty else {
            return false
        }

        stories = cachedStories
        currentPage = await cache.getCurrentPage() ?? max((cachedStories.count - 1) / pageSize, 0)
        lastFetchedAt = await cache.getStoriesTimestamp() ?? Date()
        return true
    }
    
    /// Fetches story metadata including top comment and social image.
    /// Returns nil when the item can't be loaded (deleted/dead, decode failure,
    /// or transient network error) so callers can omit it from the feed
    /// rather than rendering a broken placeholder.
    private func fetchStoryMetadata(id: Int) async -> Story? {
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
            return nil
        }
    }
}

