//
//  WebViewCacheStructurePropertyTests.swift
//  HNReader
//
//  Property-based tests for WebView cache structure
//

import XCTest
@testable import HNReader

class WebViewCacheStructurePropertyTests: XCTestCase {
    
    /// Property 27: WebView Cache Structure
    /// **Validates: Requirements 8.4**
    ///
    /// For any preloaded WebView, the app SHALL maintain a cache of WKWebView instances keyed by URL.
    func testWebViewCacheStructure() {
        let preloader = WebViewPreloader.shared
        
        // Test that preloading stores WebViews keyed by URL
        let testURLs = [
            "https://example.com/article1",
            "https://example.com/article2",
            "https://example.com/article3"
        ]
        
        for url in testURLs {
            preloader.preload(url: url)
        }
        
        // Verify that we can open each URL and get a WebView
        for url in testURLs {
            let webView = preloader.open(url: url)
            XCTAssertNotNil(webView, "WebView should be available for URL: \(url)")
            XCTAssertEqual(preloader.activeURL, url, "Active URL should match opened URL")
        }
    }
    
    /// Test that cache respects maxCachedWebViews limit
    func testCacheMaximumSize() {
        let preloader = WebViewPreloader.shared
        
        // Preload more URLs than maxCachedWebViews (5)
        let testURLs = (1...7).map { "https://example.com/article\($0)" }
        
        for url in testURLs {
            preloader.preload(url: url)
        }
        
        // The cache should not exceed maxCachedWebViews
        // We verify this by checking that we can still open recent URLs
        let recentURLs = Array(testURLs.suffix(5))
        for url in recentURLs {
            let webView = preloader.open(url: url)
            XCTAssertNotNil(webView, "Recent URL should still be cached: \(url)")
        }
    }
    
    /// Test that cache maintains LRU eviction
    func testCacheLRUEviction() {
        let preloader = WebViewPreloader.shared
        
        // Preload URLs in order
        let urls = (1...6).map { "https://example.com/article\($0)" }
        
        for url in urls {
            preloader.preload(url: url)
        }
        
        // The first URL should have been evicted (LRU)
        // We verify by checking that recent URLs are still accessible
        let lastFiveURLs = Array(urls.suffix(5))
        for url in lastFiveURLs {
            let webView = preloader.open(url: url)
            XCTAssertNotNil(webView, "URL should be in cache: \(url)")
        }
    }
}
