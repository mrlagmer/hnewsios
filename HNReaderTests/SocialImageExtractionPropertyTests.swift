//
//  SocialImageExtractionPropertyTests.swift
//  HNReader
//
//  Property-based tests for social image extraction
//

import XCTest

class SocialImageExtractionPropertyTests: XCTestCase {
    
    /// Property 33: Social Image Extraction Chain
    /// For any URL with HTML content, the SocialImageExtractor SHALL attempt extraction
    /// in the following order: og:image, twitter:image, link rel="image_src", favicon.
    /// The extractor SHALL return the first non-nil result or nil if all methods fail.
    /// Validates: Requirements 10.1, 10.2, 10.3, 10.4
    func testSocialImageExtractionChain() async {
        let extractor = SocialImageExtractor.shared
        
        // Test 1: og:image extraction
        let htmlWithOgImage = """
        <html>
        <head>
            <meta property="og:image" content="https://example.com/og-image.jpg">
            <meta name="twitter:image" content="https://example.com/twitter-image.jpg">
        </head>
        </html>
        """
        
        let ogImageResult = await extractor.parseHTML(htmlWithOgImage, baseURL: "https://example.com")
        XCTAssertEqual(ogImageResult?.absoluteString, "https://example.com/og-image.jpg")
        
        // Test 2: twitter:image fallback (no og:image)
        let htmlWithTwitterImage = """
        <html>
        <head>
            <meta name="twitter:image" content="https://example.com/twitter-image.jpg">
            <link rel="image_src" href="https://example.com/image-src.jpg">
        </head>
        </html>
        """
        
        let twitterImageResult = await extractor.parseHTML(htmlWithTwitterImage, baseURL: "https://example.com")
        XCTAssertEqual(twitterImageResult?.absoluteString, "https://example.com/twitter-image.jpg")
        
        // Test 3: link rel="image_src" fallback
        let htmlWithImageSrc = """
        <html>
        <head>
            <link rel="image_src" href="https://example.com/image-src.jpg">
        </head>
        </html>
        """
        
        let imageSrcResult = await extractor.parseHTML(htmlWithImageSrc, baseURL: "https://example.com")
        XCTAssertEqual(imageSrcResult?.absoluteString, "https://example.com/image-src.jpg")
        
        // Test 4: nil when all methods fail
        let htmlWithoutImages = """
        <html>
        <head>
            <title>No Images</title>
        </head>
        </html>
        """
        
        let noImageResult = await extractor.parseHTML(htmlWithoutImages, baseURL: "https://example.com")
        XCTAssertNil(noImageResult)
    }
    
    /// Test extraction with various og:image formats
    func testOgImageExtractionVariants() async {
        let extractor = SocialImageExtractor.shared
        
        let testCases = [
            ("https://example.com/image1.jpg", "https://example.com/image1.jpg"),
            ("https://cdn.example.com/images/og.png", "https://cdn.example.com/images/og.png"),
            ("https://example.com/image.gif", "https://example.com/image.gif"),
        ]
        
        for (imageUrl, expected) in testCases {
            let html = """
            <html>
            <head>
                <meta property="og:image" content="\(imageUrl)">
            </head>
            </html>
            """
            
            let result = await extractor.parseHTML(html, baseURL: "https://example.com")
            XCTAssertEqual(result?.absoluteString, expected)
        }
    }
    
    /// Test extraction with various twitter:image formats
    func testTwitterImageExtractionVariants() async {
        let extractor = SocialImageExtractor.shared
        
        let testCases = [
            ("https://example.com/twitter1.jpg", "https://example.com/twitter1.jpg"),
            ("https://cdn.example.com/twitter.png", "https://cdn.example.com/twitter.png"),
        ]
        
        for (imageUrl, expected) in testCases {
            let html = """
            <html>
            <head>
                <meta name="twitter:image" content="\(imageUrl)">
            </head>
            </html>
            """
            
            let result = await extractor.parseHTML(html, baseURL: "https://example.com")
            XCTAssertEqual(result?.absoluteString, expected)
        }
    }
    
    /// Test extraction priority: og:image takes precedence over twitter:image
    func testExtractionPriority() async {
        let extractor = SocialImageExtractor.shared
        
        let html = """
        <html>
        <head>
            <meta property="og:image" content="https://example.com/og.jpg">
            <meta name="twitter:image" content="https://example.com/twitter.jpg">
            <link rel="image_src" href="https://example.com/image-src.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        // Should return og:image, not twitter:image or image_src
        XCTAssertEqual(result?.absoluteString, "https://example.com/og.jpg")
    }
    
    /// Test extraction with malformed URLs
    func testExtractionWithMalformedURLs() async {
        let extractor = SocialImageExtractor.shared
        
        let html = """
        <html>
        <head>
            <meta property="og:image" content="not a valid url">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        // Should return nil for invalid URL
        XCTAssertNil(result)
    }
    
    /// Test extraction with empty content attributes
    func testExtractionWithEmptyContent() async {
        let extractor = SocialImageExtractor.shared
        
        let html = """
        <html>
        <head>
            <meta property="og:image" content="">
            <meta name="twitter:image" content="https://example.com/twitter.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        // Should skip empty og:image and try twitter:image
        XCTAssertEqual(result?.absoluteString, "https://example.com/twitter.jpg")
    }
}

// MARK: - Test Helper Extension

extension SocialImageExtractor {
    /// Helper method to access private findMetaTag for testing
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
}
