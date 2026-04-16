//
//  CommentNode.swift
//  HNReader
//
//  Model representing a comment node in the tree structure
//

import Foundation

struct CommentNode: Identifiable {
    let comment: Comment
    var children: [CommentNode]
    var isCollapsed: Bool = false
    
    var id: Int { comment.id }
}
