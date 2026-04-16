//
//  HackerNewsAPI.swift
//  HNReader
//
//  Service for fetching data from the Hacker News Firebase API
//

import Foundation

actor HackerNewsAPI {
    // MARK: - Singleton
    static let shared = HackerNewsAPI()
    
    // MARK: - Configuration
    private let baseURL = "https://hacker-news.firebaseio.com/v0"
    private let maxParallelRequests = 10
    private let maxCommentDepth = 5
    
    // MARK: - URLSession
    private let session: URLSession
    
    // MARK: - Initialization
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = maxParallelRequests
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Public API Methods
    
    /// Fetches the list of top story IDs from Hacker News
    /// - Returns: Array of story IDs
    /// - Throws: HNError if the request fails
    func fetchTopStoryIDs() async throws -> [Int] {
        guard let url = URL(string: "\(baseURL)/topstories.json") else {
            throw HNError.urlInvalid
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HNError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw HNError.invalidResponse
            }
            
            // Decode JSON array of integers
            let storyIDs = try JSONDecoder().decode([Int].self, from: data)
            return storyIDs
            
        } catch is DecodingError {
            throw HNError.decodingFailed
        } catch is URLError {
            throw HNError.networkUnavailable
        } catch let hnError as HNError {
            throw hnError
        } catch {
            throw HNError.networkUnavailable
        }
    }
    
    /// Fetches a single story by ID
    /// - Parameter id: The story ID
    /// - Returns: Story object
    /// - Throws: HNError if the request fails
    func fetchStory(id: Int) async throws -> Story {
        guard let url = URL(string: "\(baseURL)/item/\(id).json") else {
            throw HNError.urlInvalid
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HNError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw HNError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let story = try decoder.decode(Story.self, from: data)
            return story
            
        } catch is DecodingError {
            throw HNError.decodingFailed
        } catch is URLError {
            throw HNError.networkUnavailable
        } catch let hnError as HNError {
            throw hnError
        } catch {
            throw HNError.networkUnavailable
        }
    }
    
    /// Fetches a single comment by ID
    /// - Parameter id: The comment ID
    /// - Returns: Comment object (only valid comments, filters deleted/dead)
    /// - Throws: HNError if the request fails or comment is invalid
    func fetchComment(id: Int) async throws -> Comment {
        guard let url = URL(string: "\(baseURL)/item/\(id).json") else {
            throw HNError.urlInvalid
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HNError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw HNError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let comment = try decoder.decode(Comment.self, from: data)
            
            // Filter out deleted and dead comments (Requirement 5.8)
            guard comment.isValid else {
                throw HNError.invalidComment
            }
            
            return comment
            
        } catch is DecodingError {
            throw HNError.decodingFailed
        } catch is URLError {
            throw HNError.networkUnavailable
        } catch let hnError as HNError {
            throw hnError
        } catch {
            throw HNError.networkUnavailable
        }
    }
    
    /// Fetches multiple comments in parallel with depth limiting and recursive nested comment fetching
    /// - Parameters:
    ///   - ids: Array of comment IDs to fetch
    ///   - depth: Current recursion depth (default: 0)
    /// - Returns: Flattened array of all comments including nested replies
    /// - Throws: HNError if the request fails
    func fetchComments(ids: [Int], depth: Int = 0) async throws -> [Comment] {
        // Stop recursion if we've reached max depth (Requirement 17.3)
        guard depth < maxCommentDepth else {
            return []
        }
        
        // Fetch comments in batches to respect parallel request limit (Requirement 17.1)
        var allComments: [Comment] = []
        
        for batch in ids.chunked(into: maxParallelRequests) {
            let comments = try await withThrowingTaskGroup(of: Comment?.self) { group in
                for id in batch {
                    group.addTask {
                        try? await self.fetchComment(id: id)
                    }
                }
                
                var results: [Comment] = []
                for try await comment in group {
                    if let comment = comment {
                        results.append(comment)
                    }
                }
                return results
            }
            
            allComments.append(contentsOf: comments)
        }
        
        // Recursively fetch nested comments (kids) up to maxCommentDepth
        var nestedComments: [Comment] = []
        
        for comment in allComments {
            if let kids = comment.kids, !kids.isEmpty {
                let childComments = try await fetchComments(ids: kids, depth: depth + 1)
                nestedComments.append(contentsOf: childComments)
            }
        }
        
        // Return flattened array of all comments
        return allComments + nestedComments
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    /// Splits the array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Error Types
enum HNError: Error, LocalizedError {
    case networkUnavailable
    case invalidResponse
    case decodingFailed
    case cacheReadFailed
    case cacheWriteFailed
    case urlInvalid
    case invalidComment
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed:
            return "Failed to parse data"
        case .cacheReadFailed:
            return "Failed to read cached data"
        case .cacheWriteFailed:
            return "Failed to save data to cache"
        case .urlInvalid:
            return "Invalid URL"
        case .invalidComment:
            return "Comment is deleted or dead"
        }
    }
}

