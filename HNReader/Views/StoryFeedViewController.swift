import UIKit
import Combine

@MainActor
final class StoryFeedViewController: UIViewController {

    private enum UI {
        static let topBarHeight: CGFloat = 76
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
    private var newStoriesList: [Story] = []
    private var currentTab: StoryFeedViewModel.FeedTab = .top
    private var cancellables = Set<AnyCancellable>()
    private weak var loadMoreFooter: LoadMoreFooterView?

    private let feedContainerView = UIView()
    private let feedScrimView = UIView()
    private let commentsContainerView = UIView()
    private let refreshControl = UIRefreshControl()
    private let topBarView = UIView()
    private let topBarTextStack = UIStackView()
    private let tabRow = UIStackView()
    private let topTabButton = UIButton(type: .system)
    private let newTabButton = UIButton(type: .system)
    private let topTabUnderline = UIView()
    private let newTabUnderline = UIView()
    private let metaContainer = UIView()
    private let topBarUpdatedLabel = UILabel()
    private let liveStack = UIStackView()
    private let liveDot = UIView()
    private let liveLabel = UILabel()
    private let newItemsPill = UIButton(type: .system)
    private let offlineButton = OfflineButton()
    private let topBarBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
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
    private var timestampTimer: Timer?

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
        collectionView.register(NewStoryCell.self, forCellWithReuseIdentifier: NewStoryCell.reuseIdentifier)
        collectionView.register(
            LoadMoreFooterView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
            withReuseIdentifier: LoadMoreFooterView.reuseIdentifier
        )
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
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(260))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: AppTheme.Metrics.medium,
            leading: AppTheme.Metrics.large,
            bottom: AppTheme.Metrics.medium,
            trailing: AppTheme.Metrics.large
        )
        section.interGroupSpacing = AppTheme.Metrics.large

        let footerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(72)
        )
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        section.boundarySupplementaryItems = [footer]

        return UICollectionViewCompositionalLayout(section: section)
    }

    /// List-style layout for the New feed: full-width rows with no inter-row
    /// spacing (each `NewStoryCell` draws its own hairline separator).
    private func createNewLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(80))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: AppTheme.Metrics.small,
            leading: AppTheme.Metrics.medium,
            bottom: AppTheme.Metrics.medium,
            trailing: AppTheme.Metrics.medium
        )
        section.interGroupSpacing = 0

        let footerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(72)
        )
        let footer = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: footerSize,
            elementKind: UICollectionView.elementKindSectionFooter,
            alignment: .bottom
        )
        section.boundarySupplementaryItems = [footer]

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func layout(for tab: StoryFeedViewModel.FeedTab) -> UICollectionViewLayout {
        tab == .top ? createLayout(for: traitCollection) : createNewLayout()
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
        // Top feed snapshot
        viewModel.$stories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stories in
                guard let self = self else { return }
                self.storyIDs = stories.map { $0.id }
                self.storiesById = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
                if self.currentTab == .top {
                    self.applyStoriesSnapshot(stories, animated: self.hasAppliedInitialSnapshot)
                }
            }
            .store(in: &cancellables)

        // New feed snapshot
        viewModel.$newStories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stories in
                guard let self = self else { return }
                self.newStoriesList = stories
                if self.currentTab == .new {
                    self.collectionView.reloadData()
                    self.updateLoadingStateForCurrentTab()
                    self.refreshFooterState()
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(viewModel.$isLoading, viewModel.$isLoadingNew)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.updateLoadingStateForCurrentTab()
            }
            .store(in: &cancellables)

        viewModel.$isRefreshing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] refreshing in
                if !refreshing { self?.refreshControl.endRefreshing() }
            }
            .store(in: &cancellables)

        viewModel.$newSinceOpened
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.updateNewItemsPill(count: count)
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

        Publishers.CombineLatest4(
            viewModel.$isLoadingMore,
            viewModel.$hasMoreStories,
            viewModel.$isLoadingMoreNew,
            viewModel.$hasMoreNewStories
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.refreshFooterState()
        }
        .store(in: &cancellables)
    }

    private func updateLoadingStateForCurrentTab() {
        switch currentTab {
        case .top:
            updateLoadingState(isLoading: viewModel.isLoading, hasStories: !storyIDs.isEmpty)
        case .new:
            updateLoadingState(isLoading: viewModel.isLoadingNew, hasStories: !newStoriesList.isEmpty)
        }
    }

    private func refreshFooterState() {
        switch currentTab {
        case .top:
            loadMoreFooter?.apply(isLoading: viewModel.isLoadingMore, hasMore: viewModel.hasMoreStories)
        case .new:
            loadMoreFooter?.apply(isLoading: viewModel.isLoadingMoreNew, hasMore: viewModel.hasMoreNewStories)
        }
    }

    // MARK: - Tab switching

    @objc private func didTapTopTab() { setActiveTab(.top) }
    @objc private func didTapNewTab() { setActiveTab(.new) }

    private func setActiveTab(_ tab: StoryFeedViewModel.FeedTab) {
        guard tab != currentTab else { return }
        currentTab = tab

        collectionView.setCollectionViewLayout(layout(for: tab), animated: false)
        collectionView.reloadData()
        collectionView.setContentOffset(
            CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
            animated: false
        )
        setTopBarHidden(false, animated: false)
        updateTabSelectionUI(animated: true)

        // Show the loading overlay immediately when entering an unpopulated New
        // feed so we don't flash an empty list before the fetch lands.
        if tab == .new && newStoriesList.isEmpty {
            updateLoadingState(isLoading: true, hasStories: false)
        } else {
            updateLoadingStateForCurrentTab()
        }

        refreshFooterState()
        updateNewItemsPill(count: viewModel.newSinceOpened)

        Task { await viewModel.selectTab(tab) }
    }

    private func updateTabSelectionUI(animated: Bool) {
        let isTop = currentTab == .top

        topTabButton.configuration?.baseForegroundColor = isTop ? AppTheme.Colors.primaryText : AppTheme.Colors.tertiaryText
        newTabButton.configuration?.baseForegroundColor = isTop ? AppTheme.Colors.tertiaryText : AppTheme.Colors.primaryText

        let changes = {
            self.topTabUnderline.alpha = isTop ? 1 : 0
            self.newTabUnderline.alpha = isTop ? 0 : 1
            self.topBarUpdatedLabel.alpha = isTop ? 1 : 0
            self.liveStack.alpha = isTop ? 0 : 1
        }

        liveStack.isHidden = false

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                changes()
            }
        } else {
            changes()
        }

        if isTop {
            stopLivePulse()
        } else {
            startLivePulse()
        }
    }

    private func startLivePulse() {
        guard liveDot.layer.animation(forKey: "live-pulse") == nil else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.85
        scale.toValue = 1.3
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 1.0
        opacity.toValue = 0.35
        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 0.9
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        liveDot.layer.add(group, forKey: "live-pulse")
    }

    private func stopLivePulse() {
        liveDot.layer.removeAnimation(forKey: "live-pulse")
    }

    private func updateNewItemsPill(count: Int) {
        let shouldShow = currentTab == .new && count > 0

        if shouldShow {
            let noun = count == 1 ? "item" : "items"
            newItemsPill.configuration?.title = "\(count) new \(noun) since you opened"
            newItemsPill.accessibilityLabel = "\(count) new \(noun) since you opened. Tap to view."
        }

        // Already in the desired visibility state — title update above is enough.
        let isVisible = !newItemsPill.isHidden
        guard shouldShow != isVisible else { return }

        if shouldShow {
            newItemsPill.isHidden = false
            newItemsPill.transform = CGAffineTransform(translationX: 0, y: -8)
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                self.newItemsPill.alpha = 1
                self.newItemsPill.transform = .identity
            }
        } else {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
                self.newItemsPill.alpha = 0
                self.newItemsPill.transform = CGAffineTransform(translationX: 0, y: -8)
            } completion: { _ in
                self.newItemsPill.isHidden = true
                self.newItemsPill.transform = .identity
            }
        }
    }

    @objc private func didTapNewItemsPill() {
        collectionView.setContentOffset(
            CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
            animated: true
        )
        setTopBarHidden(false, animated: true)
        viewModel.acknowledgeNewItems()
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
        topBarView.backgroundColor = .clear
        topBarView.isUserInteractionEnabled = true

        topBarBlurView.translatesAutoresizingMaskIntoConstraints = false

        topBarTextStack.translatesAutoresizingMaskIntoConstraints = false
        topBarTextStack.axis = .vertical
        topBarTextStack.alignment = .leading
        topBarTextStack.spacing = 4

        // Tab switcher (Top / New) — doubles as the large title.
        tabRow.translatesAutoresizingMaskIntoConstraints = false
        tabRow.axis = .horizontal
        tabRow.alignment = .lastBaseline
        tabRow.spacing = 16

        configureTabButton(topTabButton, title: "Top", underline: topTabUnderline, action: #selector(didTapTopTab))
        configureTabButton(newTabButton, title: "New", underline: newTabUnderline, action: #selector(didTapNewTab))

        tabRow.addArrangedSubview(topTabButton)
        tabRow.addArrangedSubview(newTabButton)

        // Meta line — "Updated …" for Top, a live pulse for New.
        metaContainer.translatesAutoresizingMaskIntoConstraints = false

        topBarUpdatedLabel.translatesAutoresizingMaskIntoConstraints = false
        topBarUpdatedLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        topBarUpdatedLabel.adjustsFontForContentSizeCategory = true
        topBarUpdatedLabel.textColor = AppTheme.Colors.secondaryText
        topBarUpdatedLabel.textAlignment = .left
        topBarUpdatedLabel.text = "Updated now"

        liveStack.translatesAutoresizingMaskIntoConstraints = false
        liveStack.axis = .horizontal
        liveStack.alignment = .center
        liveStack.spacing = 6
        liveStack.isHidden = true

        liveDot.translatesAutoresizingMaskIntoConstraints = false
        liveDot.backgroundColor = AppTheme.Colors.tint
        liveDot.layer.cornerRadius = 3.5

        liveLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        liveLabel.adjustsFontForContentSizeCategory = true
        liveLabel.textColor = AppTheme.Colors.secondaryText
        liveLabel.text = "Live · newest first"

        liveStack.addArrangedSubview(liveDot)
        liveStack.addArrangedSubview(liveLabel)

        metaContainer.addSubview(topBarUpdatedLabel)
        metaContainer.addSubview(liveStack)

        offlineButton.translatesAutoresizingMaskIntoConstraints = false
        offlineButton.addTarget(self, action: #selector(didTapOffline), for: .touchUpInside)
        offlineButton.apply(state: .idle, progress: 0, animated: false)

        topBarTextStack.addArrangedSubview(tabRow)
        topBarTextStack.addArrangedSubview(metaContainer)

        topBarView.addSubview(topBarTextStack)
        topBarView.addSubview(offlineButton)
        feedContainerView.addSubview(topBarView)

        setupNewItemsPill()

        // Blur spans from the very top of the screen through the bar bottom so
        // the status-bar region also gets the glass treatment.
        feedContainerView.insertSubview(topBarBlurView, belowSubview: topBarView)

        NSLayoutConstraint.activate([
            topBarBlurView.topAnchor.constraint(equalTo: feedContainerView.topAnchor),
            topBarBlurView.leadingAnchor.constraint(equalTo: feedContainerView.leadingAnchor),
            topBarBlurView.trailingAnchor.constraint(equalTo: feedContainerView.trailingAnchor),
            topBarBlurView.bottomAnchor.constraint(equalTo: topBarView.bottomAnchor),

            topBarView.topAnchor.constraint(equalTo: feedContainerView.topAnchor, constant: AppTheme.Metrics.screenTopInset),
            topBarView.leadingAnchor.constraint(equalTo: feedContainerView.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: feedContainerView.trailingAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: UI.topBarHeight),

            topBarTextStack.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor, constant: UI.topBarHorizontalInset),
            topBarTextStack.topAnchor.constraint(equalTo: topBarView.topAnchor, constant: 4),
            topBarTextStack.bottomAnchor.constraint(lessThanOrEqualTo: topBarView.bottomAnchor, constant: -6),
            topBarTextStack.trailingAnchor.constraint(lessThanOrEqualTo: offlineButton.leadingAnchor, constant: -12),

            liveDot.widthAnchor.constraint(equalToConstant: 7),
            liveDot.heightAnchor.constraint(equalToConstant: 7),

            topBarUpdatedLabel.leadingAnchor.constraint(equalTo: metaContainer.leadingAnchor),
            topBarUpdatedLabel.trailingAnchor.constraint(lessThanOrEqualTo: metaContainer.trailingAnchor),
            topBarUpdatedLabel.topAnchor.constraint(equalTo: metaContainer.topAnchor),
            topBarUpdatedLabel.bottomAnchor.constraint(equalTo: metaContainer.bottomAnchor),

            liveStack.leadingAnchor.constraint(equalTo: metaContainer.leadingAnchor),
            liveStack.trailingAnchor.constraint(lessThanOrEqualTo: metaContainer.trailingAnchor),
            liveStack.topAnchor.constraint(equalTo: metaContainer.topAnchor),
            liveStack.bottomAnchor.constraint(equalTo: metaContainer.bottomAnchor),

            offlineButton.trailingAnchor.constraint(equalTo: topBarView.trailingAnchor, constant: -12),
            offlineButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            offlineButton.widthAnchor.constraint(equalToConstant: UI.offlineButtonHeight),
            offlineButton.heightAnchor.constraint(equalToConstant: UI.offlineButtonHeight)
        ])

        updateTabSelectionUI(animated: false)
    }

    private func configureTabButton(_ button: UIButton, title: String, underline: UIView, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.plain()
        config.title = title
        // Bottom inset reserves room for the underline inside the button's frame
        // so it tucks under the title rather than spilling onto the meta line.
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)
        config.baseForegroundColor = AppTheme.Colors.primaryText
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Typography.feedHeader
            return outgoing
        }
        button.configuration = config
        button.addTarget(self, action: action, for: .touchUpInside)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        underline.translatesAutoresizingMaskIntoConstraints = false
        underline.backgroundColor = AppTheme.Colors.tint
        underline.layer.cornerRadius = 1.5
        underline.alpha = 0
        button.addSubview(underline)

        NSLayoutConstraint.activate([
            underline.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            underline.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            underline.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2),
            underline.heightAnchor.constraint(equalToConstant: 3)
        ])
    }

    private func setupNewItemsPill() {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(
            systemName: "arrow.up",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        )
        config.imagePlacement = .leading
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        config.baseForegroundColor = AppTheme.Colors.tint
        config.background.backgroundColor = AppTheme.Colors.accentSoft
        config.background.cornerRadius = 999
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
            return outgoing
        }
        newItemsPill.configuration = config
        newItemsPill.translatesAutoresizingMaskIntoConstraints = false
        newItemsPill.isHidden = true
        newItemsPill.alpha = 0
        newItemsPill.layer.shadowColor = UIColor.black.cgColor
        newItemsPill.layer.shadowOpacity = 0.10
        newItemsPill.layer.shadowRadius = 8
        newItemsPill.layer.shadowOffset = CGSize(width: 0, height: 2)
        newItemsPill.addTarget(self, action: #selector(didTapNewItemsPill), for: .touchUpInside)

        feedContainerView.addSubview(newItemsPill)

        NSLayoutConstraint.activate([
            newItemsPill.centerXAnchor.constraint(equalTo: feedContainerView.centerXAnchor),
            newItemsPill.topAnchor.constraint(equalTo: topBarView.bottomAnchor, constant: 8)
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
            self.topBarBlurView.transform = targetTransform
            self.topBarBlurView.alpha = hidden ? 0 : 1
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
        timestampTimer?.invalidate()
        timestampTimer = nil
        Task {
            await viewModel.saveCurrentPageState()
        }
    }

    @objc private func refreshFeedOnForeground() {
        guard isViewLoaded, !viewModel.stories.isEmpty else { return }
        collectionView.reloadData()
        updateTopBarTimestamp()
        startTimestampTimer()
    }

    private func applyStoriesSnapshot(_ stories: [Story], animated _: Bool) {
        // Cache loads can arrive before the first layout pass, leaving the
        // collection view with zero bounds. Force layout now so cells get a
        // real width when preferredLayoutAttributesFitting is called.
        if collectionView.bounds.width == 0 {
            view.layoutIfNeeded()
        }
        collectionView.reloadData()
        lastUpdatedAt = viewModel.lastFetchedAt
        updateTopBarTimestamp()
        startTimestampTimer()

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

        switch currentTab {
        case .top:
            Task { await viewModel.refresh() }
        case .new:
            // The New feed is ephemeral (not cached); end the spinner ourselves
            // once the fresh fetch lands rather than via the isRefreshing flag.
            Task {
                await viewModel.refreshNewStories()
                refreshControl.endRefreshing()
            }
        }
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

    private func startTimestampTimer() {
        timestampTimer?.invalidate()
        timestampTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateTopBarTimestamp()
        }
    }

    private func updateTopBarTimestamp() {
        // Under a minute reads as "just now" — the relative formatter would
        // otherwise render the present moment as "in 0 seconds".
        let elapsed = Date().timeIntervalSince(lastUpdatedAt)
        if elapsed < 60 {
            topBarUpdatedLabel.text = "Updated just now"
            return
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
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

    private func presentAISummary(for story: Story) {
        let sheet = AISummarySheetViewController(story: story)
        present(sheet, animated: false)
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
        currentTab == .top ? storyIDs.count : newStoriesList.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let footer = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: LoadMoreFooterView.reuseIdentifier,
            for: indexPath
        ) as! LoadMoreFooterView
        footer.onTap = { [weak self] in
            guard let self = self else { return }
            Task {
                switch self.currentTab {
                case .top: await self.viewModel.loadNextPage()
                case .new: await self.viewModel.loadNextNewPage()
                }
            }
        }
        loadMoreFooter = footer
        refreshFooterState()
        return footer
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if currentTab == .new {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NewStoryCell.reuseIdentifier, for: indexPath) as! NewStoryCell
            guard indexPath.item < newStoriesList.count else { return cell }
            let story = newStoriesList[indexPath.item]
            cell.configure(
                with: story,
                showsSeparator: indexPath.item < newStoriesList.count - 1,
                onCommentsTap: { [weak self] in
                    self?.openComments(for: story)
                }
            )
            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoryCell.reuseIdentifier, for: indexPath) as! StoryCell
        let storyId = storyIDs[indexPath.item]
        guard let story = storiesById[storyId] else {
            return cell
        }

        cell.configure(
            with: story,
            onCommentsTap: { [weak self] in
                self?.openComments(for: story)
            },
            onAISummaryTap: { [weak self] in
                self?.presentAISummary(for: story)
            },
            onStoryTap: { [weak self] in
                self?.openStory(story)
            }
        )

        // The cell reserves the image slot before the image loads; if the load
        // fails it collapses the slot and asks us to re-measure just that item
        // so the card shrinks instead of leaving a gap. We invalidate only the
        // one item (not the whole layout, and not via `performBatchUpdates`,
        // which drops the boundary supplementary footer). The failure is cached,
        // so this fires at most once per image URL — never a per-scroll storm.
        cell.onImageDidHide = { [weak self, weak cell] in
            guard let self, let cell,
                  let indexPath = self.collectionView.indexPath(for: cell) else { return }
            let context = UICollectionViewLayoutInvalidationContext()
            context.invalidateItems(at: [indexPath])
            self.collectionView.collectionViewLayout.invalidateLayout(with: context)
        }

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

        // Persist scroll position for the Top feed only — the New feed is
        // ephemeral and restored fresh each launch.
        if currentTab == .top {
            Task { await CacheManager.shared.saveScrollPosition(scrollView.contentOffset.y) }
        }

        lastScrollOffset = normalizedOffset
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // On the Top feed the URL only opens from taps on the story title or
        // preview image (wired per-cell via `onStoryTap`), so whole-cell
        // selection is a no-op there. The New feed has no such regions, so a
        // row tap opens the story directly.
        guard currentTab == .new,
              indexPath.item < newStoriesList.count else { return }
        openStory(newStoriesList[indexPath.item])
    }

    private func openStory(_ story: Story) {
        guard let url = story.url else { return }
        let webVC = WebViewModalViewController(url: url)
        present(webVC, animated: true)
    }
}

