//
//  CacheManager.swift
//  HNReader
//
//  Service for caching comments and app state
//

import Foundation

actor CacheManager {
    // MARK: - Singleton
    static let shared = CacheManager()
    
    // MARK: - Storage
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // MARK: - Cache Keys
    private let commentPrefix = "hn_comment_"
    private let storyCommentsPrefix = "hn_story_comments_"
    private let storiesFileName = "hn_stories.json"
    private let scrollPositionKey = "scroll_position"
    private let currentPageKey = "current_page"
    
    // MARK: - Cache Configuration
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60  // 24 hours
    
    // MARK: - Initialization
    private init() {
        // Create cache directory at Documents/hn_cache/
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsURL.appendingPathComponent("hn_cache")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Comment Caching Methods
    
    /// Saves a single comment to cache
    func saveComment(_ comment: Comment) async throws {
        let fileName = "\(commentPrefix)\(comment.id).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        let cacheEntry = CacheEntry(comment: comment, timestamp: Date().timeIntervalSince1970 * 1000)
        let data = try await Task.detached(priority: .background) { () -> Data in
            let encoder = JSONEncoder()
            return try encoder.encode(cacheEntry)
        }.value

        try data.write(to: fileURL)
    }
    
    /// Saves multiple comments to cache in bulk
    func saveCommentsBatch(_ comments: [Comment]) async throws {
        for comment in comments {
            try await saveComment(comment)
        }
    }
    
    /// Retrieves a single comment from cache if not expired
    func getComment(id: Int) async -> Comment? {
        let fileName = "\(commentPrefix)\(id).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let cacheEntry = try await Task.detached(priority: .background) { () -> CacheEntry in
                let decoder = JSONDecoder()
                return try decoder.decode(CacheEntry.self, from: data)
            }.value
            
            // Check if cache is expired
            let currentTime = Date().timeIntervalSince1970 * 1000
            if currentTime - cacheEntry.timestamp > cacheExpirationInterval * 1000 {
                // Cache expired, delete it
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
            
            return cacheEntry.comment
        } catch {
            return nil
        }
    }
    
    /// Retrieves multiple comments from cache as a dictionary
    func getCommentsBatch(ids: [Int]) async -> [Int: Comment] {
        var result: [Int: Comment] = [:]
        
        for id in ids {
            if let comment = await getComment(id: id) {
                result[id] = comment
            }
        }
        
        return result
    }
    
    // MARK: - Story Comments Caching Methods
    
    /// Saves complete comment array for a story
    func saveStoryComments(storyId: Int, comments: [Comment]) async throws {
        let fileName = "\(storyCommentsPrefix)\(storyId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        let cacheEntry = StoryCacheEntry(comments: comments, timestamp: Date().timeIntervalSince1970 * 1000)
        let data = try await Task.detached(priority: .background) { () -> Data in
            let encoder = JSONEncoder()
            return try encoder.encode(cacheEntry)
        }.value

        try data.write(to: fileURL)
    }
    
    /// Retrieves complete comment array for a story if not expired
    func getStoryComments(storyId: Int) async -> [Comment]? {
        let fileName = "\(storyCommentsPrefix)\(storyId).json"
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let cacheEntry = try await Task.detached(priority: .background) { () -> StoryCacheEntry in
                let decoder = JSONDecoder()
                return try decoder.decode(StoryCacheEntry.self, from: data)
            }.value
            
            // Check if cache is expired
            let currentTime = Date().timeIntervalSince1970 * 1000
            if currentTime - cacheEntry.timestamp > cacheExpirationInterval * 1000 {
                // Cache expired, delete it
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
            
            return cacheEntry.comments
        } catch {
            return nil
        }
    }

    // MARK: - Story Feed Caching Methods

    /// Saves the current story feed snapshot
    func saveStories(_ stories: [Story]) async throws {
        let fileURL = cacheDirectory.appendingPathComponent(storiesFileName)

        let cacheEntry = StoriesCacheEntry(stories: stories, timestamp: Date().timeIntervalSince1970 * 1000)
        let data = try await Task.detached(priority: .background) { () -> Data in
            let encoder = JSONEncoder()
            return try encoder.encode(cacheEntry)
        }.value

        try data.write(to: fileURL)
    }

    /// Retrieves the current story feed snapshot if not expired
    func getStories() async -> [Story]? {
        let fileURL = cacheDirectory.appendingPathComponent(storiesFileName)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let cacheEntry = try await Task.detached(priority: .background) { () -> StoriesCacheEntry in
                let decoder = JSONDecoder()
                return try decoder.decode(StoriesCacheEntry.self, from: data)
            }.value

            let currentTime = Date().timeIntervalSince1970 * 1000
            if currentTime - cacheEntry.timestamp > cacheExpirationInterval * 1000 {
                try? fileManager.removeItem(at: fileURL)
                return nil
            }

            return cacheEntry.stories
        } catch {
            return nil
        }
    }

    /// Removes the persisted story feed snapshot
    func clearStories() async {
        let fileURL = cacheDirectory.appendingPathComponent(storiesFileName)
        try? fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - App State Persistence Methods
    
    /// Saves scroll position to UserDefaults
    func saveScrollPosition(_ position: CGFloat) async {
        userDefaults.set(Double(position), forKey: scrollPositionKey)
    }
    
    /// Retrieves scroll position from UserDefaults
    func getScrollPosition() async -> CGFloat? {
        guard userDefaults.object(forKey: scrollPositionKey) != nil else {
            return nil
        }

        let value = userDefaults.double(forKey: scrollPositionKey)
        return CGFloat(value)
    }

    /// Clears the saved scroll position
    func clearScrollPosition() async {
        userDefaults.removeObject(forKey: scrollPositionKey)
    }
    
    /// Saves current page number to UserDefaults
    func saveCurrentPage(_ page: Int) async {
        userDefaults.set(page, forKey: currentPageKey)
    }
    
    /// Retrieves current page number from UserDefaults
    func getCurrentPage() async -> Int? {
        guard userDefaults.object(forKey: currentPageKey) != nil else {
            return nil
        }

        return userDefaults.integer(forKey: currentPageKey)
    }

    /// Clears the saved current page
    func clearCurrentPage() async {
        userDefaults.removeObject(forKey: currentPageKey)
    }
    
    // MARK: - Cache Cleanup Methods
    
    /// Removes all cached entries older than 24 hours
    func cleanupExpiredCache() async {
        let currentTime = Date().timeIntervalSince1970 * 1000
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            for fileURL in files {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    if let modificationDate = attributes[.modificationDate] as? Date {
                        let fileTime = modificationDate.timeIntervalSince1970 * 1000
                        if currentTime - fileTime > cacheExpirationInterval * 1000 {
                            try fileManager.removeItem(at: fileURL)
                        }
                    }
                } catch {
                    // Continue with next file if deletion fails
                    continue
                }
            }
        } catch {
            // Silently fail if directory read fails
            return
        }
    }
}

// Cache entry models moved to a top-level file to avoid actor-isolated conformances
