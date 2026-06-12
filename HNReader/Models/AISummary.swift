//
//  AISummary.swift
//  HNReader
//

import Foundation
import FoundationModels

@Generable
struct AISummary: Equatable {
    @Guide(description: "A plain-English summary of what the article is about, 2–4 sentences. Neutral and factual — describe the content, do not editorialise.")
    let tldr: String

    @Guide(description: "The 3–5 most important points, findings, or takeaways from the article. Each is one concise sentence, no leading bullet character or numbering.", .count(3...5))
    let keyPoints: [String]
}
