import UIKit
import WebKit

@MainActor
final class WebViewModalViewController: UIViewController {
    private let urlString: String
    private let preloader = WebViewPreloader.shared

    private var webView: WKWebView!

    // UI
    private let topBar = UIView()
    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let safariButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    // Optional preloaded web view passed in
    private let preloadedWebView: WKWebView?

    init(url: String, preloadedWebView: WKWebView? = nil) {
        self.urlString = url
        self.preloadedWebView = preloadedWebView
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Colors.background

        setupTopBar()
        setupWebView()
        setupSwipeBackGesture()
    }

    // MARK: - Setup
    private func setupTopBar() {
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = AppTheme.Colors.elevatedSurface
        view.addSubview(topBar)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 56)
        ])

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = AppTheme.Typography.metadata
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.textColor = AppTheme.Colors.secondaryText
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.text = URL(string: urlString)?.host ?? "Reader"

        configureToolbarButton(backButton, symbolName: "chevron.left", accessibilityLabel: "Go back")
        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)

        configureToolbarButton(shareButton, symbolName: "square.and.arrow.up", accessibilityLabel: "Share this page")
        shareButton.addTarget(self, action: #selector(didTapShare), for: .touchUpInside)

        configureToolbarButton(safariButton, symbolName: "safari", accessibilityLabel: "Open in Safari")
        safariButton.addTarget(self, action: #selector(didTapSafari), for: .touchUpInside)

        configureToolbarButton(closeButton, symbolName: "xmark", accessibilityLabel: "Close web view")
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        let leadingStack = UIStackView(arrangedSubviews: [backButton])
        leadingStack.translatesAutoresizingMaskIntoConstraints = false
        leadingStack.axis = .horizontal
        leadingStack.alignment = .center
        leadingStack.spacing = AppTheme.Metrics.small

        let trailingStack = UIStackView(arrangedSubviews: [shareButton, safariButton, closeButton])
        trailingStack.translatesAutoresizingMaskIntoConstraints = false
        trailingStack.axis = .horizontal
        trailingStack.alignment = .center
        trailingStack.spacing = AppTheme.Metrics.small

        topBar.addSubview(titleLabel)
        topBar.addSubview(leadingStack)
        topBar.addSubview(trailingStack)
        NSLayoutConstraint.activate([
            leadingStack.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: AppTheme.Metrics.medium),
            leadingStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            trailingStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -AppTheme.Metrics.medium),
            trailingStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingStack.trailingAnchor, constant: AppTheme.Metrics.medium),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingStack.leadingAnchor, constant: -AppTheme.Metrics.medium)
        ])
    }

    private func configureToolbarButton(_ button: UIButton, symbolName: String, accessibilityLabel: String) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbolName)
        configuration.baseForegroundColor = AppTheme.Colors.secondaryText
        configuration.background.backgroundColor = AppTheme.Colors.surface
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        button.configuration = configuration
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityTraits = .button
    }

    private func setupWebView() {
        if let preloaded = preloadedWebView {
            webView = preloaded
        } else {
            webView = preloader.open(url: urlString)
        }

        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.accessibilityLabel = "Article content"
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateBackButtonState()
    }

    private func setupSwipeBackGesture() {
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleSwipeBack(_:)))
        edge.edges = .left
        view.addGestureRecognizer(edge)
    }

    // MARK: - Actions
    @objc private func didTapBack() {
        guard webView.canGoBack else { return }
        webView.goBack()
    }

    @objc private func didTapShare() {
        preloader.share(url: urlString, from: self)
    }

    @objc private func didTapSafari() {
        preloader.openInSafari(url: urlString)
    }

    @objc private func didTapClose() {
        preloader.close()
        dismiss(animated: true)
    }

    @objc private func handleSwipeBack(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .ended {
            if webView.canGoBack {
                webView.goBack()
            }
        }
    }

    private func updateBackButtonState() {
        backButton.isEnabled = webView.canGoBack
        backButton.alpha = webView.canGoBack ? 1 : 0.45
    }
}

// MARK: - WKNavigationDelegate
extension WebViewModalViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateBackButtonState()
    }
}
