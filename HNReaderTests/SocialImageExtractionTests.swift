//
//  SocialImageExtractionTests.swift
//  HNReader
//
//  Unit tests for social image extraction fallbacks
//

import XCTest

class SocialImageExtractionTests: XCTestCase {
    
    let extractor = SocialImageExtractor.shared
    
    // MARK: - og:image Extraction Tests
    
    /// Test og:image extraction with standard format
    func testOgImageExtraction() async {
        let html = """
        <html>
        <head>
            <meta property="og:image" content="https://example.com/og-image.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/og-image.jpg")
    }
    
    /// Test og:image extraction with single quotes
    func testOgImageExtractionWithSingleQuotes() async {
        let html = """
        <html>
        <head>
            <meta property='og:image' content='https://example.com/og-image.jpg'>
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/og-image.jpg")
    }
    
    /// Test og:image extraction with no quotes
    func testOgImageExtractionWithNoQuotes() async {
        let html = """
        <html>
        <head>
            <meta property=og:image content=https://example.com/og-image.jpg>
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/og-image.jpg")
    }
    
    // MARK: - twitter:image Fallback Tests
    
    /// Test twitter:image fallback when og:image is not present
    func testTwitterImageFallback() async {
        let html = """
        <html>
        <head>
            <meta name="twitter:image" content="https://example.com/twitter-image.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/twitter-image.jpg")
    }
    
    /// Test twitter:image is skipped when og:image is present
    func testTwitterImageSkippedWhenOgImagePresent() async {
        let html = """
        <html>
        <head>
            <meta property="og:image" content="https://example.com/og-image.jpg">
            <meta name="twitter:image" content="https://example.com/twitter-image.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/og-image.jpg")
    }
    
    /// Test twitter:image extraction with single quotes
    func testTwitterImageExtractionWithSingleQuotes() async {
        let html = """
        <html>
        <head>
            <meta name='twitter:image' content='https://example.com/twitter-image.jpg'>
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/twitter-image.jpg")
    }
    
    // MARK: - link rel="image_src" Fallback Tests
    
    /// Test link rel="image_src" fallback
    func testImageSrcFallback() async {
        let html = """
        <html>
        <head>
            <link rel="image_src" href="https://example.com/image-src.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/image-src.jpg")
    }
    
    /// Test link rel="image_src" is skipped when og:image is present
    func testImageSrcSkippedWhenOgImagePresent() async {
        let html = """
        <html>
        <head>
            <meta property="og:image" content="https://example.com/og-image.jpg">
            <link rel="image_src" href="https://example.com/image-src.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/og-image.jpg")
    }
    
    /// Test link rel="image_src" is skipped when twitter:image is present
    func testImageSrcSkippedWhenTwitterImagePresent() async {
        let html = """
        <html>
        <head>
            <meta name="twitter:image" content="https://example.com/twitter-image.jpg">
            <link rel="image_src" href="https://example.com/image-src.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        XCTAssertEqual(result?.absoluteString, "https://example.com/twitter-image.jpg")
    }
    
    // MARK: - Favicon Fallback Tests
    
    /// Test favicon fallback when all other methods fail
    func testFaviconFallback() async {
        let html = """
        <html>
        <head>
            <title>No Images</title>
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        // Should return favicon URL
        XCTAssertEqual(result?.absoluteString, "https://example.com/favicon.ico")
    }
    
    /// Test favicon fallback with different domain
    func testFaviconFallbackWithDifferentDomain() async {
        let html = """
        <html>
        <head>
            <title>No Images</title>
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://news.ycombinator.com")
        XCTAssertEqual(result?.absoluteString, "https://news.ycombinator.com/favicon.ico")
    }
    
    // MARK: - Nil Return Tests
    
    /// Test nil return when URL is invalid
    func testNilReturnForInvalidURL() async {
        let html = """
        <html>
        <head>
            <title>No Images</title>
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "not a valid url")
        XCTAssertNil(result)
    }
    
    /// Test nil return when all extraction methods fail and favicon cannot be resolved
    func testNilReturnWhenAllMethodsFail() async {
        let html = """
        <html>
        <head>
            <title>No Images</title>
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "")
        XCTAssertNil(result)
    }
    
    // MARK: - Edge Cases
    
    /// Test extraction with empty meta tag content
    func testExtractionWithEmptyMetaTagContent() async {
        let html = """
        <html>
        <head>
            <meta property="og:image" content="">
            <meta name="twitter:image" content="https://example.com/twitter-image.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        // Should skip empty og:image and use twitter:image
        XCTAssertEqual(result?.absoluteString, "https://example.com/twitter-image.jpg")
    }
    
    /// Test extraction with malformed image URL
    func testExtractionWithMalformedImageURL() async {
        let html = """
        <html>
        <head>
            <meta property="og:image" content="not a valid url">
            <meta name="twitter:image" content="https://example.com/twitter-image.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        // Should skip malformed og:image and use twitter:image
        XCTAssertEqual(result?.absoluteString, "https://example.com/twitter-image.jpg")
    }
    
    /// Test extraction with multiple meta tags of same type
    func testExtractionWithMultipleMetaTags() async {
        let html = """
        <html>
        <head>
            <meta property="og:image" content="https://example.com/og-image-1.jpg">
            <meta property="og:image" content="https://example.com/og-image-2.jpg">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        // Should return the first og:image found
        XCTAssertEqual(result?.absoluteString, "https://example.com/og-image-1.jpg")
    }
    
    /// Test extraction with whitespace in URLs
    func testExtractionWithWhitespaceInURLs() async {
        let html = """
        <html>
        <head>
            <meta property="og:image" content="https://example.com/og-image.jpg ">
        </head>
        </html>
        """
        
        let result = await extractor.parseHTML(html, baseURL: "https://example.com")
        // Should handle trailing whitespace
        XCTAssertNotNil(result)
    }
}
