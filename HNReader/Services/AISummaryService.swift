//
//  AISummaryService.swift
//  HNReader
//

import Foundation
import FoundationModels

enum AISummaryError: LocalizedError {
    case modelUnavailable(String)
    case noContent
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return reason
        case .noContent:
            return "There’s no readable article to summarise for this story."
        case .generationFailed(let reason):
            return reason
        }
    }
}

actor AISummaryService {
    static let shared = AISummaryService()

    private let api = HackerNewsAPI.shared
    private let articleFetcher = ArticleTextFetcher.shared

    /// Minimum amount of extracted text worth summarising. Below this a page is
    /// almost certainly a paywall stub, a redirect, or a non-article.
    private let minContentLength = 240

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

        let source = try await sourceText(for: story)
        guard source.count >= minContentLength else {
            throw AISummaryError.noContent
        }

        let prompt = """
        Summarise the following article.

        Title: \(story.title)

        Article text:
        \(source)
        """

        // First attempt.
        do {
            return try await generateSummary(prompt: prompt)
        } catch {
            logGenerationFailure("attempt 1", error)
            // The on-device model catalog frequently fails to mount on a cold
            // session (com.apple.modelcatalog asset error), especially on the
            // Simulator. It almost always succeeds on a second try once the asset
            // daemon has warmed up, so retry once with a fresh session.
            if isColdStartAssetError(error) {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                do {
                    return try await generateSummary(prompt: prompt)
                } catch {
                    logGenerationFailure("attempt 2", error)
                    throw AISummaryError.generationFailed(friendlyMessage(for: error))
                }
            }
            throw AISummaryError.generationFailed(friendlyMessage(for: error))
        }
    }

    /// Runs one full generation attempt on a fresh session: prewarm, try the
    /// typed/guided path, and fall back to plain text if guided generation chokes.
    private func generateSummary(prompt: String) async throws -> AISummary {
        let session = LanguageModelSession(
            instructions: """
            You summarise web articles for a mobile reader. Work only from the \
            text you are given — never invent facts, figures, or claims that \
            aren't in it. Be concise, factual, and neutral. Write for a busy \
            reader who wants the gist in a few seconds. Ignore navigation, ads, \
            cookie notices, and boilerplate.
            """
        )
        // Triggers the model catalog to load before we ask it to generate.
        session.prewarm()

        do {
            return try await structuredSummary(session: session, prompt: prompt)
        } catch {
            // Guided generation can fail opaquely on some content; plain-text
            // generation is more tolerant. Only fall back when the model itself
            // is reachable — a cold-start asset error would fail identically.
            if isColdStartAssetError(error) { throw error }
            logGenerationFailure("structured", error)
            print("↪️ AISummaryService falling back to plain-text generation")
            let summary = try await plainTextSummary(session: session, prompt: prompt)
            print("✅ AISummaryService plain-text fallback succeeded")
            return summary
        }
    }

    /// Preferred path: ask the model for the typed `AISummary` directly.
    private func structuredSummary(session: LanguageModelSession, prompt: String) async throws -> AISummary {
        let response = try await session.respond(to: prompt, generating: AISummary.self)
        return normalise(response.content)
    }

    /// True only for the `com.apple.modelcatalog` / UnifiedAssetFramework failure
    /// that happens when the on-device model assets aren't mounted yet. Kept
    /// narrow on purpose: a generic `ModelManagerError` (e.g. code 1026) is a
    /// generation-time failure, not a cold start, and must fall through to the
    /// plain-text fallback rather than trigger a pointless asset retry.
    private func isColdStartAssetError(_ error: Error) -> Bool {
        let text = "\(error)".lowercased()
        return text.contains("modelcatalog")
            || text.contains("unifiedassetframework")
            || text.contains("no underlying assets")
    }

    /// Fallback path: plain-text generation, then parse it into `AISummary`.
    /// No schema constraints, so it tolerates content guided generation chokes on.
    private func plainTextSummary(session: LanguageModelSession, prompt: String) async throws -> AISummary {
        let plainPrompt = prompt + """


        Reply in exactly this format and nothing else:
        TLDR: <2–4 sentence summary>
        - <key point>
        - <key point>
        - <key point>
        """
        let response = try await session.respond(to: plainPrompt)
        let parsed = Self.parsePlainSummary(response.content)
        guard !parsed.tldr.isEmpty, !parsed.keyPoints.isEmpty else {
            throw AISummaryError.generationFailed("The model returned an empty summary. Try again.")
        }
        return parsed
    }

    private func logGenerationFailure(_ stage: String, _ error: Error) {
        let nsError = error as NSError
        print("❌ AISummaryService \(stage) generation failed: \(error)")
        print("   domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
    }

    /// Parses the plain-text fallback format into an `AISummary`.
    static func parsePlainSummary(_ text: String) -> AISummary {
        var tldrLines: [String] = []
        var points: [String] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let range = line.range(of: "^(?i)tl;?dr\\s*[:\\-]?\\s*", options: .regularExpression) {
                let rest = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { tldrLines.append(rest) }
            } else if line.range(of: "^[\\-•\\*]\\s+", options: .regularExpression) != nil
                        || line.range(of: "^\\d+[.\\)]\\s+", options: .regularExpression) != nil {
                let cleaned = line.replacingOccurrences(of: "^[\\-•\\*\\d.\\)\\s]+", with: "", options: .regularExpression)
                if !cleaned.isEmpty { points.append(cleaned) }
            } else if points.isEmpty {
                // Prose before the first bullet is part of the TL;DR.
                tldrLines.append(line)
            }
        }
        return AISummary(
            tldr: tldrLines.joined(separator: " ").trimmingCharacters(in: .whitespaces),
            keyPoints: Array(points.prefix(5))
        )
    }

    // MARK: - Source text

    /// Resolves the best text to summarise: the linked article when the story
    /// links out, otherwise the author's own post body for Ask/Show/text posts.
    private func sourceText(for story: Story) async throws -> String {
        if let urlString = story.url, !urlString.isEmpty {
            return try await articleFetcher.fetchReadableText(from: urlString)
        }

        // Self-post: use the body the author wrote. The feed copy of the story
        // may predate the `text` field, so refetch if it's missing.
        if let bodyHTML = story.text, !bodyHTML.isEmpty {
            return HTMLTextExtractor.plainText(from: bodyHTML)
        }
        if let refreshed = try? await api.fetchStory(id: story.id),
           let bodyHTML = refreshed.text, !bodyHTML.isEmpty {
            return HTMLTextExtractor.plainText(from: bodyHTML)
        }

        throw AISummaryError.noContent
    }

    private func friendlyMessage(for error: Error) -> String {
        if let fetchError = error as? ArticleTextFetcher.FetchError {
            return fetchError.localizedDescription
        }
        if isColdStartAssetError(error) {
            return "Apple Intelligence’s model is still warming up on this device. Give it a moment and try again."
        }
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .exceededContextWindowSize:
                return "This article is too long to summarise on-device."
            case .assetsUnavailable:
                return "Apple Intelligence assets aren’t downloaded yet. Open Settings → Apple Intelligence to finish setup."
            case .guardrailViolation:
                return "Apple Intelligence’s safety filter blocked this article. This is an Apple AI limitation, not a problem with the app."
            case .unsupportedGuide, .unsupportedLanguageOrLocale:
                return "Your language isn’t supported by the on-device model yet."
            case .decodingFailure:
                return "The model returned a malformed response. Try again."
            case .rateLimited:
                return "Too many summaries at once — wait a moment and try again."
            default:
                return "Apple Intelligence couldn’t summarise this article. This sometimes happens on-device — try again, or open the story to read it."
            }
        }
        let desc = error.localizedDescription
        if desc.localizedCaseInsensitiveContains("unsafe") || desc.localizedCaseInsensitiveContains("guardrail") {
            return "Apple Intelligence’s safety filter blocked this article. This is an Apple AI limitation, not a problem with the app."
        }
        return desc
    }

    private func normalise(_ summary: AISummary) -> AISummary {
        let tldr = summary.tldr.trimmingCharacters(in: .whitespacesAndNewlines)
        let points = summary.keyPoints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            // Strip any leading bullet/number the model added despite instructions.
            .map { $0.replacingOccurrences(of: "^[\\-•\\*\\d.\\)\\s]+", with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
        return AISummary(tldr: tldr, keyPoints: points)
    }
}
