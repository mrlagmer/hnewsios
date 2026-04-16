//
//  PreloadedWebViewReusePropertyTests.swift
//  HNReader
//
//  Property-based tests for preloaded WebView reuse
//

import XCTest
@testable import HNReader

class PreloadedWebViewReusePropertyTests: XCTestCase {
    
    /// Property 26: Preloaded WebView Reuse
    /// **Validates: Requirements 8.3**
    ///
    /// For any preloaded story tap, the WebView controller SHALL display the preloaded WKWebView content immediately.
    func testPreloadedWebViewReuse() {
        let preloader = WebViewPreloader.shared
        
        let testURL = "https://example.com/article"
        
        // Preload the URL
        preloader.preload(url: testURL)
        
        // Open the preloaded URL
        let webView = preloader.open(url: testURL)
        
        // Verify that the WebView is available and active
        XCTAssertNotNil(webView, "Preloaded WebView should be available")
        XCTAssertEqual(preloader.activeURL, testURL, "Active URL should match the opened URL")
    }
    
    /// Test that opening a preloaded URL returns the same WebView instance
    func testPreloadedWebViewInstance() {
        let preloader = WebViewPreloader.shared
        
        let testURL = "https://example.com/article"
        
        // Preload the URL
        preloader.preload(url: testURL)
        
        // Open the preloaded URL twice
        let webView1 = preloader.open(url: testURL)
        let webView2 = preloader.open(url: testURL)
        
        // Both should be the same instance
        XCTAssertTrue(webView1 === webView2, "Opening same preloaded URL should return same WebView instance")
    }
    
    /// Test that opening a non-preloaded URL creates a new WebView
    func testNonPreloadedWebViewCreation() {
        let preloader = WebViewPreloader.shared
        
        let testURL = "https://example.com/article"
        
        // Open without preloading
        let webView = preloader.open(url: testURL)
        
        // Verify that a WebView was created
        XCTAssertNotNil(webView, "WebView should be created for non-preloaded URL")
        XCTAssertEqual(preloader.activeURL, testURL, "Active URL should be set")
    }
    
    /// Test that multiple preloaded URLs can be accessed
    func testMultiplePreloadedWebViews() {
        let preloader = WebViewPreloader.shared
        
        let urls = [
            "https://example.com/article1",
            "https://example.com/article2",
            "https://example.com/article3"
        ]
        
        // Preload all URLs
        for url in urls {
            preloader.preload(url: url)
        }
        
        // Open each URL and verify it's available
        for url in urls {
            let webView = preloader.open(url: url)
            XCTAssertNotNil(webView, "Preloaded WebView should be available for: \(url)")
            XCTAssertEqual(preloader.activeURL, url, "Active URL should match: \(url)")
        }
    }
}
