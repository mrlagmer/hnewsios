import UIKit
import Combine

@MainActor
final class StoryFeedViewController: UIViewController {

    private let viewModel = StoryFeedViewModel()
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!
    private var storiesById: [Int: Story] = [:]
    private var cancellables = Set<AnyCancellable>()

    private let refreshControl = UIRefreshControl()
    private let offlineButton = UIButton(type: .system)
    
    private var shouldRestoreScrollPosition = false
    private var savedScrollPosition: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Colors.background
        
        // Set navigation title
        title = "Hacker News"
        navigationController?.navigationBar.prefersLargeTitles = true

        setupCollectionView()
        configureDataSource()
        setupBindings()
        setupOfflineButton()
        setupBackgroundStateNotifications()

        Task {
            // Try to restore saved state; if no saved state, load initial stories
            let savedPage = await CacheManager.shared.getCurrentPage()
            let savedScroll = await CacheManager.shared.getScrollPosition()
            
            if savedPage != nil && savedPage! > 0 {
                // Mark that we should restore scroll position after data loads
                self.shouldRestoreScrollPosition = true
                self.savedScrollPosition = savedScroll ?? 0
                await viewModel.restoreState()
            } else {
                await viewModel.loadInitialStories()
            }
        }
    }

    // MARK: - Setup
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout(for: traitCollection))
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = AppTheme.Colors.background
        collectionView.register(StoryCell.self, forCellWithReuseIdentifier: StoryCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: AppTheme.Metrics.small, left: 0, bottom: 88, right: 0)
        collectionView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 88, right: 0)

        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        refreshControl.accessibilityLabel = "Refresh stories"
        refreshControl.tintColor = AppTheme.Colors.tint
        collectionView.refreshControl = refreshControl

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
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

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: collectionView) { [weak self] (collectionView, indexPath, storyId) -> UICollectionViewCell? in
            guard let story = self?.storiesById[storyId] else { return nil }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StoryCell.reuseIdentifier, for: indexPath) as! StoryCell
            cell.configure(with: story, onCommentsTap: { [weak self] in
                // Present comments view
                let commentsViewModel = CommentsViewModel(
                    storyId: story.id,
                    totalComments: story.descendants,
                    preloadedComments: nil
                )
                let commentsVC = CommentsViewController()
                commentsVC.viewModel = commentsViewModel
                let navController = UINavigationController(rootViewController: commentsVC)
                navController.modalPresentationStyle = .pageSheet
                if #available(iOS 16.0, *) {
                    navController.sheetPresentationController?.detents = [.medium(), .large()]
                }
                self?.present(navController, animated: true)
            })
            return cell
        }
    }

    private func setupBindings() {
        // Update snapshot when stories change
        viewModel.$stories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stories in
                guard let self = self else { return }
                self.storiesById = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
                var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
                snapshot.appendSections([0])
                snapshot.appendItems(stories.map { $0.id }, toSection: 0)
                self.dataSource.apply(snapshot, animatingDifferences: true)
                
                // Restore scroll position if needed
                if self.shouldRestoreScrollPosition && self.savedScrollPosition > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.collectionView.setContentOffset(CGPoint(x: 0, y: self.savedScrollPosition), animated: false)
                        self.shouldRestoreScrollPosition = false
                    }
                }
            }
            .store(in: &cancellables)

        viewModel.$isRefreshing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] refreshing in
                if !refreshing { self?.refreshControl.endRefreshing() }
            }
            .store(in: &cancellables)
    }

    private func setupOfflineButton() {
        offlineButton.translatesAutoresizingMaskIntoConstraints = false
        offlineButton.addTarget(self, action: #selector(didTapOffline), for: .touchUpInside)
        offlineButton.accessibilityLabel = "Download for offline"
        offlineButton.accessibilityTraits = .button

        var config = UIButton.Configuration.filled()
        config.title = "Offline"
        config.image = UIImage(systemName: "arrow.down.circle")
        config.imagePadding = AppTheme.Metrics.small
        config.baseBackgroundColor = AppTheme.Colors.tint
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(
            top: AppTheme.Metrics.medium,
            leading: AppTheme.Metrics.large,
            bottom: AppTheme.Metrics.medium,
            trailing: AppTheme.Metrics.large
        )
        offlineButton.configuration = config

        view.addSubview(offlineButton)

        NSLayoutConstraint.activate([
            offlineButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            offlineButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            offlineButton.heightAnchor.constraint(equalToConstant: 48)
        ])
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

    @objc private func saveStateOnBackground() {
        // Save current page number when app goes to background
        Task {
            await viewModel.saveCurrentPageState()
        }
    }

    // MARK: - Actions
    @objc private func didPullToRefresh() {
        Task { await viewModel.refresh() }
    }

    @objc private func didTapOffline() {
        Task { await viewModel.downloadForOffline() }
    }
}

// MARK: - UIScrollViewDelegate
extension StoryFeedViewController: UIScrollViewDelegate, UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
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
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Simple show/hide animation for offline button based on vertical velocity
        let shouldHide = velocity.y > 0.2
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.6, options: []) {
            self.offlineButton.transform = shouldHide ? CGAffineTransform(translationX: 0, y: 120) : .identity
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = dataSource.itemIdentifier(for: indexPath)
        guard let storyId = item, let story = storiesById[storyId], let url = story.url else { return }
        let webVC = WebViewModalViewController(url: url)
        present(webVC, animated: true)
    }
}

