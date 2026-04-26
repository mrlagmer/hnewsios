//
//  WebViewPreloader.swift
//  HNReader
//
//  Service for preloading and managing WKWebView instances
//

import Foundation
import WebKit
import UIKit
import Combine

@MainActor
class WebViewPreloader: ObservableObject {
    // MARK: - Singleton
    static let shared = WebViewPreloader()
    
    // MARK: - Configuration
    private let maxCachedWebViews = 5
    
    // MARK: - State
    private var preloadedWebViews: [String: WKWebView] = [:]
    private var webViewLoadOrder: [String] = []  // Track order for LRU eviction
    private var activeWebView: WKWebView?
    private var navigationObservers: [String: NavigationObserver] = [:]
    
    @Published var activeURL: String?
    @Published var canGoBack: Bool = false

    private final class NavigationObserver: NSObject, WKNavigationDelegate {
        private var completion: ((Bool) -> Void)?

        init(completion: @escaping (Bool) -> Void) {
            self.completion = completion
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            complete(success: true)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            complete(success: false)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            complete(success: false)
        }

        private func complete(success: Bool) {
            guard let completion else { return }
            self.completion = nil
            completion(success)
        }
    }
    
    // MARK: - Initialization
    private init() {
        registerForMemoryWarnings()
    }
    
    // MARK: - Public Methods
    
    /// Preloads a single URL in a WKWebView
    /// - Parameter url: The URL string to preload
    func preload(url: String) {
        // Don't preload if already cached
        if preloadedWebViews[url] != nil {
            touch(url: url)
            return
        }
        
        // Release oldest if at capacity
        if preloadedWebViews.count >= maxCachedWebViews {
            releaseOldestWebView()
        }
        
        let webView = createWebView()
        guard let urlObj = URL(string: url) else { return }
        
        let request = makeRequest(for: urlObj)
        webView.load(request)
        
        cache(webView: webView, for: url)
    }
    
    /// Preloads multiple URLs in batch
    /// - Parameter urls: Array of URL strings to preload
    func preloadMany(urls: [String]) {
        for url in urls {
            preload(url: url)
        }
    }

    func preloadForOffline(url: String) async -> Bool {
        if preloadedWebViews[url] != nil {
            touch(url: url)
            return true
        }

        guard let urlObj = URL(string: url) else { return false }

        if preloadedWebViews.count >= maxCachedWebViews {
            releaseOldestWebView()
        }

        let webView = createWebView()
        let request = makeRequest(for: urlObj)
        cache(webView: webView, for: url)

        return await withCheckedContinuation { continuation in
            let observer = NavigationObserver { [weak self, weak webView] success in
                guard let self else {
                    continuation.resume(returning: success)
                    return
                }

                self.navigationObservers.removeValue(forKey: url)
                webView?.navigationDelegate = nil
                continuation.resume(returning: success)
            }

            navigationObservers[url] = observer
            webView.navigationDelegate = observer
            webView.load(request)
        }
    }
    
    /// Opens a URL, using preloaded WebView if available or creating new one
    /// - Parameter url: The URL string to open
    /// - Returns: WKWebView instance for the URL
    func open(url: String) -> WKWebView {
        activeURL = url
        
        // Return preloaded WebView if available
        if let webView = preloadedWebViews[url] {
            touch(url: url)
            activeWebView = webView
            updateCanGoBack()
            return webView
        }
        
        // Create new WebView if not preloaded
        let webView = createWebView()
        guard let urlObj = URL(string: url) else { return webView }
        
        let request = makeRequest(for: urlObj)
        webView.load(request)
        cache(webView: webView, for: url)
        
        activeWebView = webView
        updateCanGoBack()
        return webView
    }
    
    /// Closes the active WebView
    func close() {
        activeWebView = nil
        activeURL = nil
        canGoBack = false
    }
    
    /// Navigates back in the active WebView if possible
    func goBack() {
        guard let webView = activeWebView, webView.canGoBack else { return }
        webView.goBack()
        updateCanGoBack()
    }
    
    /// Presents share sheet for a URL
    /// - Parameters:
    ///   - url: The URL string to share
    ///   - viewController: The view controller to present from
    func share(url: String, from viewController: UIViewController) {
        guard let urlObj = URL(string: url) else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [urlObj],
            applicationActivities: nil
        )
        
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
        }
        
        viewController.present(activityViewController, animated: true)
    }
    
    /// Opens a URL in Safari
    /// - Parameter url: The URL string to open
    func openInSafari(url: String) {
        guard let urlObj = URL(string: url) else { return }
        UIApplication.shared.open(urlObj, options: [:], completionHandler: nil)
    }
    
    // MARK: - Private Methods
    
    /// Creates and configures a new WKWebView
    /// - Returns: Configured WKWebView instance
    private func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        
        return webView
    }

    private func makeRequest(for url: URL) -> URLRequest {
        URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
    }

    private func cache(webView: WKWebView, for url: String) {
        preloadedWebViews[url] = webView
        touch(url: url)

        if preloadedWebViews.count > maxCachedWebViews {
            releaseOldestWebView()
        }
    }

    private func touch(url: String) {
        webViewLoadOrder.removeAll { $0 == url }
        webViewLoadOrder.append(url)
    }
    
    /// Releases the oldest cached WebView to maintain cache size limit
    private func releaseOldestWebView() {
        guard !webViewLoadOrder.isEmpty else { return }
        
        let oldestURL = webViewLoadOrder.removeFirst()
        
        // Don't release the active WebView
        if oldestURL != activeURL {
            preloadedWebViews.removeValue(forKey: oldestURL)
        } else {
            // If we tried to remove the active one, remove the next oldest
            if !webViewLoadOrder.isEmpty {
                let nextOldest = webViewLoadOrder.removeFirst()
                preloadedWebViews.removeValue(forKey: nextOldest)
            }
        }
    }
    
    /// Handles memory warnings by releasing cached WebViews
    func handleMemoryWarning() {
        // Keep only the active WebView
        let activeURL = self.activeURL
        preloadedWebViews = preloadedWebViews.filter { $0.key == activeURL }
        webViewLoadOrder = activeURL.map { [$0] } ?? []
    }
    
    /// Registers for memory warning notifications
    private func registerForMemoryWarnings() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    /// Called when memory warning is received
    @objc private func didReceiveMemoryWarning() {
        handleMemoryWarning()
    }
    
    /// Updates the canGoBack published property
    private func updateCanGoBack() {
        canGoBack = activeWebView?.canGoBack ?? false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
