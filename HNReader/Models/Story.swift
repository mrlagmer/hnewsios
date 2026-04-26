//
//  Story.swift
//  HNReader
//
//  Model representing a Hacker News story
//

import Foundation

struct Story: Codable, Identifiable {
    let id: Int
    let title: String
    let score: Int
    let descendants: Int  // Comment count
    let url: String?
    let by: String?
    let time: Int
    let kids: [Int]?      // Top-level comment IDs
    
    // Computed/transient properties (not from API)
    var topComment: Comment?
    var socialImageURL: URL?
    var allComments: [Comment]?
    
    // Validation
    var isValid: Bool {
        !title.isEmpty && id > 0
    }
}

