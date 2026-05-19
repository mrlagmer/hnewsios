//
//  AISummary.swift
//  HNReader
//

import Foundation
import FoundationModels

@Generable
struct AISummary: Equatable {
    @Guide(description: "A single-paragraph plain-English summary of the overall discussion, 1–3 sentences.")
    let tldr: String

    @Guide(description: "Percentage of comments that are broadly supportive or positive about the story. 0–100 integer.")
    let supportivePercent: Int

    @Guide(description: "Percentage of comments that are neutral, informational, or off-topic. 0–100 integer.")
    let neutralPercent: Int

    @Guide(description: "Percentage of comments that are skeptical, critical, or negative. 0–100 integer.")
    let skepticalPercent: Int

    @Guide(description: "The 3–5 most prominent themes or sub-discussions in the comments. Order most-discussed first.", .count(3...5))
    let themes: [Theme]

    @Generable
    struct Theme: Equatable {
        @Guide(description: "A short label for the theme, 2–6 words, sentence case, no trailing punctuation.")
        let label: String

        @Guide(description: "1–2 sentences describing what commenters said about this theme.")
        let body: String

        @Guide(description: "Approximate number of comments that touched on this theme.")
        let replyCount: Int
    }
}
