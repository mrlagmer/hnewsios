//
//  Comment.swift
//  HNReader
//
//  Model representing a Hacker News comment
//

import Foundation

struct Comment: Codable, Identifiable {
    let id: Int
    let text: String?
    let by: String?
    let time: Int?
    let kids: [Int]?
    let parent: Int
    let deleted: Bool?
    let dead: Bool?
    
    // Validation
    var isValid: Bool {
        !(deleted ?? false) && !(dead ?? false) && text != nil
    }
}

