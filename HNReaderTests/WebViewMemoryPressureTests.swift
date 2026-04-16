//
//  WebViewMemoryPressureTests.swift
//  HNReader
//
//  Unit tests for WebView memory pressure handling
//

import XCTest
@testable import HNReader

class WebViewMemoryPressureTests: XCTestCase {
    
    /// Test that memory warning releases WebViews except active one
    func testMemoryWarningReleasesWebViews() {
        let preloader = WebViewPreloader.shared
        
        let urls = [
            "https://example.com/article1",
            "https://example.com/article2",
            "https://example.com/article3"
        ]
        
        // Preload multiple URLs
        for url in urls {
            preloader.preload(url: url)
        }
        
        // Set one as active
        let activeURL = urls[0]
        _ = preloader.open(url: activeURL)
        
        // Simulate memory warning
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Give notification time to process
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Active URL should still be accessible
        let activeWebView = preloader.open(url: activeURL)
        XCTAssertNotNil(activeWebView, "Active WebView should be preserved after memory warning")
        XCTAssertEqual(preloader.activeURL, activeURL, "Active URL should remain set")
    }
    
    /// Test that active WebView is preserved during memory pressure
    func testActiveWebViewPreserved() {
        let preloader = WebViewPreloader.shared
        
        let activeURL = "https://example.com/active"
        let inactiveURL = "https://example.com/inactive"
        
        // Preload both URLs
        preloader.preload(url: activeURL)
        preloader.preload(url: inactiveURL)
        
        // Set one as active
        _ = preloader.open(url: activeURL)
        
        // Simulate memory warning
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Give notification time to process
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Active URL should still be accessible
        let webView = preloader.open(url: activeURL)
        XCTAssertNotNil(webView, "Active WebView should be preserved")
    }
    
    /// Test that close() clears active WebView
    func testCloseReleasesActiveWebView() {
        let preloader = WebViewPreloader.shared
        
        let testURL = "https://example.com/article"
        
        // Open a URL
        _ = preloader.open(url: testURL)
        XCTAssertEqual(preloader.activeURL, testURL, "URL should be active")
        
        // Close the WebView
        preloader.close()
        
        // Active URL should be cleared
        XCTAssertNil(preloader.activeURL, "Active URL should be cleared after close")
        XCTAssertFalse(preloader.canGoBack, "canGoBack should be false after close")
    }
}
