//
//  SocialImageExtractor.swift
//  HNReader
//
//  Service for extracting social images from URLs using meta tag parsing
//

import Foundation

actor SocialImageExtractor {
    // MARK: - Singleton
    static let shared = SocialImageExtractor()
    
    // MARK: - Configuration
    private let session: URLSession
    
    // MARK: - Initialization
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// Extracts a social image URL from a given URL using multiple fallback strategies
    /// - Parameter url: The URL string to extract social image from
    /// - Returns: URL of the social image, or nil if no image could be extracted
    func extractSocialImage(from url: String) async -> URL? {
        guard let urlObj = URL(string: url) else { return nil }
        
        do {
            let (data, _) = try await session.data(from: urlObj)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            return parseHTML(html, baseURL: url)
        } catch {
            // On network error, try favicon fallback
            return resolveFavicon(for: url)
        }
    }
    
    // MARK: - Private Methods
    
    /// Parses HTML to extract social image URL using multiple fallback strategies
    /// - Parameters:
    ///   - html: The HTML content to parse
    ///   - baseURL: The base URL for resolving relative URLs
    /// - Returns: URL of the social image, or nil if not found
    func parseHTML(_ html: String, baseURL: String) -> URL? {
        // Try og:image first
        if let ogImage = findMetaTag(in: html, property: "og:image") {
            return URL(string: ogImage)
        }
        
        // Fallback to twitter:image
        if let twitterImage = findMetaTag(in: html, property: "twitter:image") {
            return URL(string: twitterImage)
        }
        
        // Fallback to link rel="image_src"
        if let imageSrc = findLinkImageSrc(in: html) {
            return URL(string: imageSrc)
        }
        
        // Final fallback to favicon
        return resolveFavicon(for: baseURL)
    }
    
    /// Finds a meta tag with the specified property in HTML
    /// - Parameters:
    ///   - html: The HTML content to search
    ///   - property: The meta tag property to find (e.g., "og:image", "twitter:image")
    /// - Returns: The content attribute value, or nil if not found
    func findMetaTag(in html: String, property: String) -> String? {
        // Search for meta tag with property attribute
        let propertyPattern = "property=[\"']?\(NSRegularExpression.escapedPattern(for: property))[\"']?"
        let contentPattern = "content=[\"']([^\"']+)[\"']"
        
        // Try property-based meta tag first
        if let propertyRange = html.range(of: propertyPattern, options: .regularExpression) {
            let searchStart = propertyRange.lowerBound
            let searchEnd = html.index(searchStart, offsetBy: 200, limitedBy: html.endIndex) ?? html.endIndex
            let searchRange = searchStart..<searchEnd
            
            if let contentRange = html[searchRange].range(of: contentPattern, options: .regularExpression) {
                let contentMatch = html[contentRange]
                if let regex = try? NSRegularExpression(pattern: contentPattern) {
                    if let match = regex.firstMatch(in: String(contentMatch), range: NSRange(String(contentMatch).startIndex..., in: String(contentMatch))) {
                        if let range = Range(match.range(at: 1), in: String(contentMatch)) {
                            return String(String(contentMatch)[range])
                        }
                    }
                }
            }
        }
        
        // Try name-based meta tag (for twitter:image)
        let namePattern = "name=[\"']?\(NSRegularExpression.escapedPattern(for: property))[\"']?"
        if let nameRange = html.range(of: namePattern, options: .regularExpression) {
            let searchStart = nameRange.lowerBound
            let searchEnd = html.index(searchStart, offsetBy: 200, limitedBy: html.endIndex) ?? html.endIndex
            let searchRange = searchStart..<searchEnd
            
            if let contentRange = html[searchRange].range(of: contentPattern, options: .regularExpression) {
                let contentMatch = html[contentRange]
                if let regex = try? NSRegularExpression(pattern: contentPattern) {
                    if let match = regex.firstMatch(in: String(contentMatch), range: NSRange(String(contentMatch).startIndex..., in: String(contentMatch))) {
                        if let range = Range(match.range(at: 1), in: String(contentMatch)) {
                            return String(String(contentMatch)[range])
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Finds link rel="image_src" in HTML
    /// - Parameter html: The HTML content to search
    /// - Returns: The href attribute value, or nil if not found
    func findLinkImageSrc(in html: String) -> String? {
        let pattern = "link[^>]*rel=[\"']?image_src[\"']?[^>]*href=[\"']([^\"']+)[\"']"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(html.startIndex..., in: html)
            if let match = regex.firstMatch(in: html, range: range) {
                if let range = Range(match.range(at: 1), in: html) {
                    return String(html[range])
                }
            }
        }
        
        return nil
    }
    
    /// Resolves the favicon URL for a given URL
    /// - Parameter url: The URL string to resolve favicon for
    /// - Returns: URL of the favicon, or nil if unable to resolve
    func resolveFavicon(for url: String) -> URL? {
        guard let urlObj = URL(string: url),
              let host = urlObj.host else { return nil }
        
        // Try common favicon locations
        let faviconURLs = [
            "https://\(host)/favicon.ico",
            "https://\(host)/apple-touch-icon.png",
            "https://\(host)/apple-touch-icon-precomposed.png"
        ]
        
        for faviconURL in faviconURLs {
            if let url = URL(string: faviconURL) {
                return url
            }
        }
        
        return nil
    }
}
