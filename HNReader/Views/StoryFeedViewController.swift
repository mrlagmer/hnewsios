import UIKit
import Combine

@MainActor
final class StoryFeedViewController: UIViewController {

    private enum UI {
        static let topBarHeight: CGFloat = 64
        static let topBarHorizontalInset: CGFloat = 16
        static let topBarVerticalInset: CGFloat = 0
        static let offlineButtonHeight: CGFloat = 36
        static let refreshActivationDistance: CGFloat = 140
        static let headerVisibilityThreshold: CGFloat = 24
        static let bottomContentInset: CGFloat = 32
    }

    private let viewModel = StoryFeedViewModel()
    private var collectionView: UICollectionView!
    private var storyIDs: [Int] = []
    private var storiesById: [Int: Story] = [:]
    private var cancellables = Set<AnyCancellable>()

    private let feedContainerView = UIView()
    private let feedScrimView = UIView()
    private let commentsContainerView = UIView()
    private let refreshControl = UIRefreshControl()
    private let topBarView = UIView()
    private let topBarTextStack = UIStackView()
    private let topBarTitleLabel = UILabel()
    private let topBarUpdatedLabel = UILabel()
    private let offlineButton = OfflineButton()
    private let loadingContainerView = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private var activeCommentsViewController: CommentsViewController?
    private var lastUpdatedAt = Date()
    private var commentsOpen = false
    
    private var shouldRestoreScrollPosition = false
    private var savedScrollPosition: CGFloat = 0
    private var lastScrollOffset: CGFloat = 0
    private var maximumObservedPullDistance: CGFloat = 0
    private var isTopBarHidden = false
    private var hasAppliedInitialSnapshot = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Colors.background
        
        title = nil
        navigationItem.title = nil
        navigationController?.navigationBar.prefersLargeTitles = false

        setupLayeredContainers()
        setupCollectionView()
        setupLoadingView()
        setupBindings()
        setupTopBar()
        setupBackgroundStateNotifications()
        setupForegroundRefreshNotifications()
        setTopBarHidden(false, animated: false)

        Task {
            let savedScroll = await CacheManager.shared.getScrollPosition()

            if let savedScroll, savedScroll > 0 {
                self.shouldRestoreScrollPosition = true
                self.savedScrollPosition = savedScroll
            }

            await viewModel.loadInitialStories()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup
    private func setupLayeredContainers() {
        feedContainerView.translatesAutoresizingMaskIntoConstraints = false
        feedContainerView.backgroundColor = .clear
        view.addSubview(feedContainerView)

        feedScrimView.translatesAutoresizingMaskIntoConstraints = false
        feedScrimView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
        feedScrimView.alpha = 0
        feedScrimView.isHidden = true
        feedScrimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeCommentsOverlay)))
        view.addSubview(feedScrimView)

        commentsContainerView.translatesAutoresizingMaskIntoConstraints = false
        commentsContainerView.backgroundColor = AppTheme.Colors.background
        commentsContainerView.isHidden = true
        commentsContainerView.layer.shadowColor = UIColor.black.cgColor
        commentsContainerView.layer.shadowOpacity = 0.08
        commentsContainerView.layer.shadowRadius = 24
        commentsContainerView.layer.shadowOffset = CGSize(width: -8, height: 0)
        view.addSubview(commentsContainerView)

        NSLayoutConstraint.activate([
            feedContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            feedContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            feedContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            feedContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            feedScrimView.topAnchor.constraint(equalTo: view.topAnchor),
            feedScrimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            feedScrimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            feedScrimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            commentsContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            commentsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commentsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commentsContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout(for: traitCollection))
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = AppTheme.Colors.background
        collectionView.register(StoryCell.self, forCellWithReuseIdentifier: StoryCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true

        let topInset = UI.topBarHeight + UI.topBarVerticalInset
        collectionView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: UI.bottomContentInset, right: 0)
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: UI.bottomContentInset, right: 0)

        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        refreshControl.accessibilityLabel = "Refresh stories"
        refreshControl.tintColor = AppTheme.Colors.tint
        collectionView.refreshControl = refreshControl

        feedContainerView.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: feedContainerView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: feedContainerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: feedContainerView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: feedContainerView.bottomAnchor)
        ])
    }

    private func createLayout(for traits: UITraitCollection) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, environment) -> NSCollectionLayoutSection? in
            let isWide = environment.traitCollection.horizontalSizeClass == .regular && environment.container.effectiveContentSize.width > 700

            let columns = isWide ? 2 : 1
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(260))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupWidth = NSCollectionLayoutDimension.fractionalWidth(1.0)
            let groupSize = NSCollectionLayoutSize(widthDimension: groupWidth, heightDimension: .estimated(260))
            let group: NSCollectionLayoutGroup
            if columns == 1 {
                group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
            } else {
                group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: columns)
                group.interItemSpacing = .fixed(AppTheme.Metrics.large)
            }

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(
                top: AppTheme.Metrics.medium,
                leading: AppTheme.Metrics.large,
                bottom: AppTheme.Metrics.medium,
                trailing: AppTheme.Metrics.large
            )
            section.interGroupSpacing = AppTheme.Metrics.large
            return section
        }

        return layout
    }

    private func setupLoadingView() {
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.backgroundColor = AppTheme.Colors.background.withAlphaComponent(0.96)
        loadingContainerView.isHidden = false

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = AppTheme.Colors.tint
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.accessibilityLabel = "Loading stories"

        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "Loading stories…"
        loadingLabel.font = AppTheme.Typography.metadata
        loadingLabel.adjustsFontForContentSizeCategory = true
        loadingLabel.textColor = AppTheme.Colors.secondaryText
        loadingLabel.textAlignment = .center

        let loadingStack = UIStackView(arrangedSubviews: [loadingIndicator, loadingLabel])
        loadingStack.translatesAutoresizingMaskIntoConstraints = false
        loadingStack.axis = .vertical
        loadingStack.alignment = .center
        loadingStack.spacing = AppTheme.Metrics.medium

        loadingContainerView.addSubview(loadingStack)
        feedContainerView.addSubview(loadingContainerView)

        NSLayoutConstraint.activate([
            loadingContainerView.topAnchor.constraint(equalTo: feedContainerView.topAnchor),
            loadingContainerView.leadingAnchor.constraint(equalTo: feedContainerView.leadingAnchor),
            loadingContainerView.trailingAnchor.constraint(equalTo: feedContainerView.trailingAnchor),
            loadingContainerView.bottomAnchor.constraint(equalTo: feedContainerView.bottomAnchor),

            loadingStack.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            loadingStack.centerYAnchor.constraint(equalTo: feedContainerView.safeAreaLayoutGuide.centerYAnchor)
        ])

        loadingIndicator.startAnimating()
    }

    private func setupBindings() {
        // Update snapshot when stories change
        viewModel.$stories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stories in
                guard let self = self else { return }
                self.storyIDs = stories.map { $0.id }
                self.storiesById = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
                self.applyStoriesSnapshot(stories, animated: self.hasAppliedInitialSnapshot)
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                guard let self = self else { return }
                self.updateLoadingState(isLoading: isLoading, hasStories: !self.viewModel.stories.isEmpty)
            }
            .store(in: &cancellables)

        viewModel.$isRefreshing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] refreshing in
                if !refreshing { self?.refreshControl.endRefreshing() }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            viewModel.$downloadProgress,
            viewModel.$isDownloadingOffline,
            viewModel.$offlineMode
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] progress, isDownloading, offlineMode in
            self?.updateOfflineButton(progress: progress, isDownloading: isDownloading, offlineMode: offlineMode)
        }
        .store(in: &cancellables)
    }

    private func updateLoadingState(isLoading: Bool, hasStories: Bool) {
        let shouldShowLoading = isLoading && !hasStories
        loadingContainerView.isHidden = !shouldShowLoading
        collectionView.isUserInteractionEnabled = !shouldShowLoading

        if shouldShowLoading {
            loadingIndicator.startAnimating()
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    private func setupTopBar() {
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        topBarView.backgroundColor = AppTheme.Colors.background.withAlphaComponent(0.96)
        topBarView.isUserInteractionEnabled = true

        topBarTextStack.translatesAutoresizingMaskIntoConstraints = false
        topBarTextStack.axis = .vertical
        topBarTextStack.alignment = .leading
        topBarTextStack.spacing = 0

        topBarTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBarTitleLabel.font = AppTheme.Typography.feedHeader
        topBarTitleLabel.adjustsFontForContentSizeCategory = true
        topBarTitleLabel.textColor = AppTheme.Colors.primaryText
        topBarTitleLabel.text = "Top"

        topBarUpdatedLabel.translatesAutoresizingMaskIntoConstraints = false
        topBarUpdatedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        topBarUpdatedLabel.adjustsFontForContentSizeCategory = true
        topBarUpdatedLabel.textColor = AppTheme.Colors.secondaryText
        topBarUpdatedLabel.textAlignment = .left
        topBarUpdatedLabel.text = "Updated now"

        offlineButton.translatesAutoresizingMaskIntoConstraints = false
        offlineButton.addTarget(self, action: #selector(didTapOffline), for: .touchUpInside)
        offlineButton.apply(state: .idle, progress: 0, animated: false)

        topBarTextStack.addArrangedSubview(topBarTitleLabel)
        topBarTextStack.addArrangedSubview(topBarUpdatedLabel)

        topBarView.addSubview(topBarTextStack)
        topBarView.addSubview(offlineButton)
        feedContainerView.addSubview(topBarView)

        NSLayoutConstraint.activate([
            topBarView.topAnchor.constraint(equalTo: feedContainerView.topAnchor, constant: AppTheme.Metrics.screenTopInset),
            topBarView.leadingAnchor.constraint(equalTo: feedContainerView.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: feedContainerView.trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: UI.topBarHeight),

            topBarTextStack.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor, constant: UI.topBarHorizontalInset),
            topBarTextStack.topAnchor.constraint(equalTo: topBarView.topAnchor, constant: 4),
            topBarTextStack.bottomAnchor.constraint(lessThanOrEqualTo: topBarView.bottomAnchor, constant: -12),
            topBarTextStack.trailingAnchor.constraint(lessThanOrEqualTo: offlineButton.leadingAnchor, constant: -12),

            offlineButton.trailingAnchor.constraint(equalTo: topBarView.trailingAnchor, constant: -12),
            offlineButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            offlineButton.widthAnchor.constraint(equalToConstant: UI.offlineButtonHeight),
            offlineButton.heightAnchor.constraint(equalToConstant: UI.offlineButtonHeight)
        ])
    }

    private func setTopBarHidden(_ hidden: Bool, animated: Bool) {
        guard hidden != isTopBarHidden else { return }

        isTopBarHidden = hidden

        let topInset = UI.topBarHeight + UI.topBarVerticalInset
        let visibleIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: UI.bottomContentInset, right: 0)
        let hiddenIndicatorInsets = UIEdgeInsets(top: AppTheme.Metrics.medium, left: 0, bottom: UI.bottomContentInset, right: 0)
        let targetTransform = hidden
            ? CGAffineTransform(translationX: 0, y: -(UI.topBarHeight + UI.topBarVerticalInset))
            : .identity

        let changes = {
            self.topBarView.transform = targetTransform
            self.topBarView.alpha = hidden ? 0 : 1
            self.collectionView.scrollIndicatorInsets = hidden ? hiddenIndicatorInsets : visibleIndicatorInsets
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                changes()
            }
        } else {
            changes()
        }
    }

    private func normalizedScrollOffset(for scrollView: UIScrollView) -> CGFloat {
        scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    }

    private func updateTopBarVisibility(for scrollView: UIScrollView) {
        let currentOffset = normalizedScrollOffset(for: scrollView)

        if currentOffset <= 0 {
            setTopBarHidden(false, animated: true)
            return
        }

        let delta = currentOffset - lastScrollOffset

        if currentOffset > UI.headerVisibilityThreshold && delta > 1 {
            setTopBarHidden(true, animated: true)
        } else if delta < -1 {
            setTopBarHidden(false, animated: true)
        }
    }

    // MARK: - Background State Persistence

    private func setupBackgroundStateNotifications() {
        // Register for background notification to save current page
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveStateOnBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    private func setupForegroundRefreshNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshFeedOnForeground),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func saveStateOnBackground() {
        // Save current page number when app goes to background
        Task {
            await viewModel.saveCurrentPageState()
        }
    }

    @objc private func refreshFeedOnForeground() {
        guard isViewLoaded, !viewModel.stories.isEmpty else { return }
        applyStoriesSnapshot(viewModel.stories, animated: false)
    }

    private func applyStoriesSnapshot(_ stories: [Story], animated _: Bool) {
        collectionView.reloadData()
        lastUpdatedAt = Date()
        updateTopBarTimestamp()

        if self.shouldRestoreScrollPosition && self.savedScrollPosition > 0 {
            DispatchQueue.main.async {
                self.collectionView.setContentOffset(CGPoint(x: 0, y: self.savedScrollPosition), animated: false)
                self.shouldRestoreScrollPosition = false
            }
        }

        self.updateLoadingState(isLoading: self.viewModel.isLoading, hasStories: !stories.isEmpty)
        self.hasAppliedInitialSnapshot = true
    }

    // MARK: - Actions
    @objc private func didPullToRefresh() {
        guard maximumObservedPullDistance >= UI.refreshActivationDistance else {
            refreshControl.endRefreshing()
            maximumObservedPullDistance = 0
            return
        }

        maximumObservedPullDistance = 0
        Task { await viewModel.refresh() }
    }

    @objc private func didTapOffline() {
        guard !viewModel.isDownloadingOffline else { return }

        if viewModel.offlineMode {
            viewModel.dismissOfflineReadyState()
            return
        }

        Task { await viewModel.downloadForOffline() }
    }

    @objc private func closeCommentsOverlay() {
        setCommentsOpen(false, animated: true)
    }

    private func updateTopBarTimestamp() {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        topBarUpdatedLabel.text = "Updated \(formatter.localizedString(for: lastUpdatedAt, relativeTo: Date()))"
    }

    private func updateOfflineButton(
        progress: (completed: Int, total: Int),
        isDownloading: Bool,
        offlineMode: Bool
    ) {
        let percentage: CGFloat
        if progress.total > 0 {
            percentage = (CGFloat(progress.completed) / CGFloat(progress.total)) * 100
        } else {
            percentage = 0
        }

        let state: OfflineButton.DisplayState
        if isDownloading {
            state = .loading
        } else if offlineMode {
            state = .done
        } else {
            state = .idle
        }

        offlineButton.apply(state: state, progress: percentage, animated: true)
    }

    private func openComments(for story: Story) {
        activeCommentsViewController?.willMove(toParent: nil)
        activeCommentsViewController?.view.removeFromSuperview()
        activeCommentsViewController?.removeFromParent()

        let commentsViewModel = CommentsViewModel(
            storyId: story.id,
            totalComments: story.descendants,
            preloadedComments: nil
        )
        let commentsViewController = CommentsViewController()
        commentsViewController.viewModel = commentsViewModel
        commentsViewController.story = story
        commentsViewController.onClose = { [weak self] in
            self?.setCommentsOpen(false, animated: true)
        }

        addChild(commentsViewController)
        commentsViewController.view.translatesAutoresizingMaskIntoConstraints = false
        commentsContainerView.addSubview(commentsViewController.view)
        NSLayoutConstraint.activate([
            commentsViewController.view.topAnchor.constraint(equalTo: commentsContainerView.topAnchor),
            commentsViewController.view.leadingAnchor.constraint(equalTo: commentsContainerView.leadingAnchor),
            commentsViewController.view.trailingAnchor.constraint(equalTo: commentsContainerView.trailingAnchor),
            commentsViewController.view.bottomAnchor.constraint(equalTo: commentsContainerView.bottomAnchor)
        ])
        commentsViewController.didMove(toParent: self)
        activeCommentsViewController = commentsViewController
        commentsViewController.scrollToTop()

        setCommentsOpen(true, animated: true)
    }

    private func setCommentsOpen(_ open: Bool, animated: Bool) {
        guard commentsOpen != open || (open && commentsContainerView.isHidden) else { return }

        commentsOpen = open
        let width = max(view.bounds.width, UIScreen.main.bounds.width)
        let animationBlock = {
            self.feedContainerView.transform = open
                ? CGAffineTransform(translationX: -(width * 0.22), y: 0)
                : .identity
            self.commentsContainerView.transform = open
                ? .identity
                : CGAffineTransform(translationX: width, y: 0)
            self.feedScrimView.alpha = open ? 1 : 0
        }

        if open {
            commentsContainerView.isHidden = false
            feedScrimView.isHidden = false
            commentsContainerView.transform = CGAffineTransform(translationX: width, y: 0)
            view.layoutIfNeeded()
        }

        let completion: (Bool) -> Void = { _ in
            guard !open else { return }
            self.feedScrimView.isHidden = true
            self.commentsContainerView.isHidden = true
            self.activeCommentsViewController?.willMove(toParent: nil)
            self.activeCommentsViewController?.view.removeFromSuperview()
            self.activeCommentsViewController?.removeFromParent()
            self.activeCommentsViewController = nil
        }

        if animated {
            UIView.animate(withDuration: 0.34, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                animationBlock()
            } completion: { finished in
                completion(finished)
            }
        } else {
            animationBlock()
            completion(true)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension StoryFeedViewController: UIScrollViewDelegate, UICollectionViewDelegate, UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        storyIDs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoryCell.reuseIdentifier, for: indexPath) as! StoryCell
        let storyId = storyIDs[indexPath.item]
        guard let story = storiesById[storyId] else {
            return cell
        }

        cell.configure(with: story, onCommentsTap: { [weak self] in
            self?.openComments(for: story)
        })

        return cell
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastScrollOffset = normalizedScrollOffset(for: scrollView)
        maximumObservedPullDistance = 0
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let normalizedOffset = normalizedScrollOffset(for: scrollView)

        if scrollView.isDragging {
            maximumObservedPullDistance = max(maximumObservedPullDistance, max(0, -normalizedOffset))
        }

        updateTopBarVisibility(for: scrollView)

        // Save scroll position
        Task { await CacheManager.shared.saveScrollPosition(scrollView.contentOffset.y) }

        // Trigger load next page when near bottom
        let threshold: CGFloat = 300
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.bounds.size.height
        if offsetY + height + threshold > contentHeight {
            Task { await viewModel.loadNextPage() }
        }

        lastScrollOffset = normalizedOffset
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let storyId = storyIDs[indexPath.item]
        guard let story = storiesById[storyId], let url = story.url else { return }
        let webVC = WebViewModalViewController(url: url)
        present(webVC, animated: true)
    }
}

