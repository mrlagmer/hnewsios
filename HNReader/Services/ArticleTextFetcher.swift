//
//  ArticleTextFetcher.swift
//  HNReader
//
//  Fetches an article URL and extracts its readable body text for
//  on-device summarisation. Deliberately lightweight: strips scripts,
//  styles, and markup rather than running a full readability algorithm.
//

import Foundation

actor ArticleTextFetcher {
    static let shared = ArticleTextFetcher()

    private let session: URLSession

    /// Upper bound on characters fed to the model. The on-device model has a
    /// small (~4k token) context window shared with the instructions and the
    /// generated output, so we keep the article slice well under it and trim to
    /// the most important leading portion rather than risk a generation failure.
    private let maxCharacters = 3500

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        // Some sites serve a stripped page to non-browser agents.
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        ]
        self.session = URLSession(configuration: config)
    }

    enum FetchError: LocalizedError {
        case invalidURL
        case notHTML
        case empty

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "This story doesn’t have a readable link."
            case .notHTML: return "The linked page isn’t an article we can read (it may be a PDF, image, or video)."
            case .empty: return "Couldn’t pull any readable text from the page."
            }
        }
    }

    /// Fetches `urlString` and returns cleaned, trimmed article text.
    func fetchReadableText(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { throw FetchError.invalidURL }

        let (data, response) = try await session.data(from: url)

        if let mime = response.mimeType, !mime.contains("html") {
            throw FetchError.notHTML
        }

        guard let html = decodeHTML(data, response: response) else {
            throw FetchError.notHTML
        }

        let text = Self.readableText(fromHTML: html)
        guard !text.isEmpty else { throw FetchError.empty }

        return trim(text)
    }

    /// Cleans, collapses, and truncates already-extracted text to the budget.
    func trim(_ text: String) -> String {
        if text.count <= maxCharacters { return text }
        let cut = String(text.prefix(maxCharacters))
        // Avoid slicing mid-sentence: back up to the last sentence break.
        if let lastStop = cut.range(of: ".", options: .backwards), cut.distance(from: cut.startIndex, to: lastStop.lowerBound) > maxCharacters / 2 {
            return String(cut[..<lastStop.upperBound]) + " …"
        }
        return cut + " …"
    }

    // MARK: - HTML → text

    private func decodeHTML(_ data: Data, response: URLResponse) -> String? {
        if let html = String(data: data, encoding: .utf8) { return html }
        if let html = String(data: data, encoding: .isoLatin1) { return html }
        return nil
    }

    /// Strips non-content regions (head, scripts, styles, nav, etc.), prefers the
    /// `<article>`/`<main>` region when present, then reuses `HTMLTextExtractor`.
    static func readableText(fromHTML html: String) -> String {
        var working = html

        // Remove whole regions that never contain article prose.
        let dropRegions = ["script", "style", "noscript", "head", "header", "footer", "nav", "aside", "form", "svg"]
        for tag in dropRegions {
            working = working.replacingOccurrences(
                of: "(?is)<\(tag)\\b[^>]*>.*?</\(tag)>",
                with: " ",
                options: .regularExpression
            )
        }
        // HTML comments.
        working = working.replacingOccurrences(of: "(?s)<!--.*?-->", with: " ", options: .regularExpression)

        // Prefer the main article body if the page marks one up.
        let region = firstRegion(in: working, tag: "article")
            ?? firstRegion(in: working, tag: "main")
            ?? working

        return HTMLTextExtractor.plainText(from: region)
    }

    /// Returns the inner HTML of the first `<tag>…</tag>` block, if any.
    private static func firstRegion(in html: String, tag: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "(?is)<\(tag)\\b[^>]*>(.*?)</\(tag)>"
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let inner = Range(match.range(at: 1), in: html) else { return nil }
        let candidate = String(html[inner])
        // Ignore tiny regions (e.g. a stray <main> wrapper around a widget).
        return candidate.count > 200 ? candidate : nil
    }
}
