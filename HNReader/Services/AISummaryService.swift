//
//  AISummaryService.swift
//  HNReader
//

import Foundation
import FoundationModels

enum AISummaryError: LocalizedError {
    case modelUnavailable(String)
    case noComments
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return reason
        case .noComments:
            return "Not enough comments yet to summarise."
        case .generationFailed(let reason):
            return reason
        }
    }
}

actor AISummaryService {
    static let shared = AISummaryService()

    private let api = HackerNewsAPI.shared
    private let cache = CacheManager.shared

    private let maxTopLevelComments: Int = 12
    private let maxRepliesPerTopLevel: Int = 3
    private let maxReplyDepth: Int = 2
    private let maxCharsPerComment: Int = 320
    private let totalCharBudget: Int = 5000

    func availabilityMessage() -> String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "Apple Intelligence isn’t available on this device."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to use AI summaries."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still preparing. Try again in a moment."
        case .unavailable(let other):
            return "Apple Intelligence is unavailable: \(other)"
        }
    }

    func summarise(story: Story) async throws -> AISummary {
        if let message = availabilityMessage() {
            throw AISummaryError.modelUnavailable(message)
        }

        let comments = try await fetchCommentsForSummary(storyId: story.id)
        let prepared = preparedComments(from: comments, storyId: story.id)
        guard !prepared.isEmpty else {
            throw AISummaryError.noComments
        }

        let session = LanguageModelSession(
            instructions: """
            You summarise Hacker News comment threads for a mobile reader. \
            Be concise, factual, and neutral. Reflect what commenters actually \
            said — do not editorialise or invent positions. Sentiment \
            percentages must sum to 100. Themes should capture the most \
            discussed sub-arguments, ordered by how much attention they got.
            """
        )

        let prompt = """
        Story title: \(story.title)
        Sample size: \(prepared.count) of \(story.descendants) comments \
        (top-level threads with a few top replies, indented).

        \(prepared.joined(separator: "\n"))
        """

        do {
            let response = try await session.respond(to: prompt, generating: AISummary.self)
            return normalise(response.content)
        } catch {
            print("❌ AISummaryService generation failed: \(error)")
            throw AISummaryError.generationFailed(friendlyMessage(for: error))
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .exceededContextWindowSize:
                return "The thread is too long to summarise on-device. Try after collapsing replies."
            case .assetsUnavailable:
                return "Apple Intelligence assets aren’t downloaded yet. Open Settings → Apple Intelligence to finish setup."
            case .guardrailViolation:
                return "The on-device model refused to summarise this thread."
            case .unsupportedGuide, .unsupportedLanguageOrLocale:
                return "Your language isn’t supported by the on-device model yet."
            case .decodingFailure:
                return "The model returned a malformed response. Try again."
            case .rateLimited:
                return "Too many summaries at once — wait a moment and try again."
            default:
                return generationError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private func fetchCommentsForSummary(storyId: Int) async throws -> [Comment] {
        if let cached = await cache.getStoryComments(storyId: storyId), !cached.isEmpty {
            return cached
        }

        let story = try await api.fetchStory(id: storyId)
        let topLevelIDs = Array((story.kids ?? []).prefix(20))
        var collected: [Comment] = []
        for id in topLevelIDs {
            let fetched = try await api.fetchComments(ids: [id])
            collected.append(contentsOf: fetched)
        }

        try? await cache.saveStoryComments(storyId: storyId, comments: collected)
        return collected
    }

    private func preparedComments(from comments: [Comment], storyId: Int) -> [String] {
        let valid = comments.filter { $0.isValid }
        var childrenByParent: [Int: [Comment]] = [:]
        for comment in valid {
            childrenByParent[comment.parent, default: []].append(comment)
        }

        let topLevel = (childrenByParent[storyId] ?? []).prefix(maxTopLevelComments)
        var lines: [String] = []
        var remainingBudget = totalCharBudget

        func add(_ comment: Comment, depth: Int) -> Bool {
            guard let html = comment.text else { return true }
            let plain = HTMLTextExtractor.plainText(from: html)
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !plain.isEmpty else { return true }
            let truncated = plain.count > maxCharsPerComment
                ? String(plain.prefix(maxCharsPerComment)) + "…"
                : plain
            let cost = truncated.count + 20
            guard remainingBudget - cost > 0 else { return false }
            remainingBudget -= cost
            let indent = String(repeating: "  ", count: depth)
            let prefix = depth == 0 ? "@" : "↳ @"
            let author = comment.by ?? "anon"
            lines.append("\(indent)\(prefix)\(author): \(truncated)")
            return true
        }

        func walk(_ comment: Comment, depth: Int) -> Bool {
            if !add(comment, depth: depth) { return false }
            if depth >= maxReplyDepth { return true }
            let replies = (childrenByParent[comment.id] ?? []).prefix(maxRepliesPerTopLevel)
            for reply in replies {
                if !walk(reply, depth: depth + 1) { return false }
            }
            return true
        }

        for comment in topLevel {
            if !walk(comment, depth: 0) { break }
        }
        return lines
    }

    private func normalise(_ summary: AISummary) -> AISummary {
        let total = max(1, summary.supportivePercent + summary.neutralPercent + summary.skepticalPercent)
        let supportive = Int((Double(summary.supportivePercent) / Double(total)) * 100)
        let skeptical = Int((Double(summary.skepticalPercent) / Double(total)) * 100)
        let neutral = max(0, 100 - supportive - skeptical)
        return AISummary(
            tldr: summary.tldr.trimmingCharacters(in: .whitespacesAndNewlines),
            supportivePercent: supportive,
            neutralPercent: neutral,
            skepticalPercent: skeptical,
            themes: summary.themes
        )
    }
}
