//
//  CommentsViewController.swift
//  HNReader
//

import UIKit
import Combine

struct FlattenedCommentNode {
    let node: CommentNode
    let depth: Int
}

enum CommentTreeFlattener {
    static func flatten(_ nodes: [CommentNode]) -> [FlattenedCommentNode] {
        var result: [FlattenedCommentNode] = []
        var stack = nodes.reversed().map { FlattenedCommentNode(node: $0, depth: 0) }

        while let entry = stack.popLast() {
            result.append(entry)

            guard !entry.node.isCollapsed, !entry.node.children.isEmpty else {
                continue
            }

            for child in entry.node.children.reversed() {
                stack.append(FlattenedCommentNode(node: child, depth: entry.depth + 1))
            }
        }

        return result
    }
}

final class CommentsViewController: UIViewController {
    enum SortOption: String, CaseIterable {
        case top
        case newest
        case oldest

        var title: String {
            switch self {
            case .top:
                return "Top"
            case .newest:
                return "Newest first"
            case .oldest:
                return "Oldest first"
            }
        }
    }

    var viewModel: CommentsViewModel?
    var story: Story?
    var onClose: (() -> Void)?

    private let chromeHeaderView = UIView()
    private let chromeDividerView = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let sortButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let summaryHeaderView = UIView()
    private let summaryContentView = UIView()
    private let summaryDividerView = UIView()
    private let metaRow = UIStackView()
    private let pointsPillView = UIView()
    private let pointsPillImageView = UIImageView()
    private let pointsPillLabel = UILabel()
    private let domainLabel = UILabel()
    private let ageLabel = UILabel()
    private let storyTitleLabel = UILabel()
    private let storyBodyLabel = UILabel()
    private let storyFadeView = UIView()
    private let storyToggleButton = UIButton(type: .system)
    private let footerContainerView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 76))
    private let loadMoreButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var cancellables = Set<AnyCancellable>()
    private var visibleCommentNodes: [FlattenedCommentNode] = []
    private var sort: SortOption = .top
    private var summaryExpanded = false
    private var needsHeaderLayoutRefresh = true
    private var lastHeaderCollapsed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Colors.background

        setupHeaderChrome()
        setupTableView()
        setupSummaryHeader()
        updateSortMenu()
        applyStorySummary()
        setupBindings()

        Task {
            await viewModel?.loadInitialComments()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSummaryHeaderLayoutIfNeeded(force: false)
    }

    func scrollToTop() {
        tableView.setContentOffset(.zero, animated: false)
        updateHeaderChrome(for: 0)
    }

    private func setupHeaderChrome() {
        chromeHeaderView.translatesAutoresizingMaskIntoConstraints = false
        chromeHeaderView.backgroundColor = AppTheme.Colors.background
        view.addSubview(chromeHeaderView)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = AppTheme.Colors.tint
        backButton.setTitle("Story", for: .normal)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.semanticContentAttribute = .forceLeftToRight
        backButton.contentHorizontalAlignment = .leading
        backButton.titleLabel?.font = AppTheme.Typography.compactButton
        backButton.setTitleColor(AppTheme.Colors.tint, for: .normal)
        backButton.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        chromeHeaderView.addSubview(backButton)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = AppTheme.Typography.compactButton
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.Colors.primaryText
        titleLabel.textAlignment = .center
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 4)
        chromeHeaderView.addSubview(titleLabel)

        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.tintColor = AppTheme.Colors.primaryText
        sortButton.setImage(UIImage(systemName: "line.3.horizontal.decrease"), for: .normal)
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.accessibilityLabel = "Sort comments"
        chromeHeaderView.addSubview(sortButton)

        chromeDividerView.translatesAutoresizingMaskIntoConstraints = false
        chromeDividerView.backgroundColor = AppTheme.Colors.border
        chromeDividerView.alpha = 0
        chromeHeaderView.addSubview(chromeDividerView)

        NSLayoutConstraint.activate([
            chromeHeaderView.topAnchor.constraint(equalTo: view.topAnchor, constant: AppTheme.Metrics.screenTopInset),
            chromeHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chromeHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeHeaderView.heightAnchor.constraint(equalToConstant: 44),

            backButton.leadingAnchor.constraint(equalTo: chromeHeaderView.leadingAnchor, constant: 12),
            backButton.centerYAnchor.constraint(equalTo: chromeHeaderView.centerYAnchor),

            sortButton.trailingAnchor.constraint(equalTo: chromeHeaderView.trailingAnchor, constant: -16),
            sortButton.centerYAnchor.constraint(equalTo: chromeHeaderView.centerYAnchor),
            sortButton.widthAnchor.constraint(equalToConstant: 28),
            sortButton.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.centerXAnchor.constraint(equalTo: chromeHeaderView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: chromeHeaderView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: sortButton.leadingAnchor, constant: -12),

            chromeDividerView.leadingAnchor.constraint(equalTo: chromeHeaderView.leadingAnchor),
            chromeDividerView.trailingAnchor.constraint(equalTo: chromeHeaderView.trailingAnchor),
            chromeDividerView.bottomAnchor.constraint(equalTo: chromeHeaderView.bottomAnchor),
            chromeDividerView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseIdentifier)
        tableView.estimatedRowHeight = 160
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = AppTheme.Colors.background
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 18, right: 0)
        tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 18, right: 0)
        tableView.accessibilityLabel = "Comments"
        view.addSubview(tableView)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = AppTheme.Colors.tint
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)

        footerContainerView.backgroundColor = .clear

        loadMoreButton.translatesAutoresizingMaskIntoConstraints = false
        loadMoreButton.setTitle("Load more comments", for: .normal)
        loadMoreButton.titleLabel?.font = AppTheme.Typography.compactButton
        loadMoreButton.backgroundColor = AppTheme.Colors.accentSoft
        loadMoreButton.tintColor = AppTheme.Colors.tint
        loadMoreButton.setTitleColor(AppTheme.Colors.tint, for: .normal)
        loadMoreButton.layer.cornerRadius = 12
        loadMoreButton.layer.cornerCurve = .continuous
        loadMoreButton.addTarget(self, action: #selector(loadMorePressed), for: .touchUpInside)
        footerContainerView.addSubview(loadMoreButton)
        tableView.tableFooterView = footerContainerView

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: chromeHeaderView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            loadMoreButton.leadingAnchor.constraint(equalTo: footerContainerView.leadingAnchor, constant: 16),
            loadMoreButton.trailingAnchor.constraint(equalTo: footerContainerView.trailingAnchor, constant: -16),
            loadMoreButton.topAnchor.constraint(equalTo: footerContainerView.topAnchor, constant: 8),
            loadMoreButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupSummaryHeader() {
        summaryHeaderView.backgroundColor = .clear
        summaryContentView.translatesAutoresizingMaskIntoConstraints = false
        summaryContentView.backgroundColor = AppTheme.Colors.background
        summaryHeaderView.addSubview(summaryContentView)

        metaRow.translatesAutoresizingMaskIntoConstraints = false
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = AppTheme.Metrics.small

        pointsPillView.translatesAutoresizingMaskIntoConstraints = false
        pointsPillView.backgroundColor = AppTheme.Colors.accentSoft
        pointsPillView.layer.cornerRadius = 12
        pointsPillView.layer.cornerCurve = .continuous

        pointsPillImageView.translatesAutoresizingMaskIntoConstraints = false
        pointsPillImageView.image = UIImage(systemName: "arrowtriangle.up")
        pointsPillImageView.tintColor = AppTheme.Colors.tint
        pointsPillImageView.contentMode = .scaleAspectFit
        pointsPillView.addSubview(pointsPillImageView)

        pointsPillLabel.translatesAutoresizingMaskIntoConstraints = false
        pointsPillLabel.font = AppTheme.Typography.compactMeta
        pointsPillLabel.adjustsFontForContentSizeCategory = true
        pointsPillLabel.textColor = AppTheme.Colors.tint
        pointsPillView.addSubview(pointsPillLabel)

        domainLabel.translatesAutoresizingMaskIntoConstraints = false
        domainLabel.font = AppTheme.Typography.compactMeta
        domainLabel.adjustsFontForContentSizeCategory = true
        domainLabel.textColor = AppTheme.Colors.secondaryText

        ageLabel.translatesAutoresizingMaskIntoConstraints = false
        ageLabel.font = AppTheme.Typography.compactMeta
        ageLabel.adjustsFontForContentSizeCategory = true
        ageLabel.textColor = AppTheme.Colors.secondaryText

        storyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        storyTitleLabel.font = AppTheme.Typography.storyHeadline
        storyTitleLabel.adjustsFontForContentSizeCategory = true
        storyTitleLabel.textColor = AppTheme.Colors.primaryText
        storyTitleLabel.numberOfLines = 0

        storyBodyLabel.translatesAutoresizingMaskIntoConstraints = false
        storyBodyLabel.font = AppTheme.Typography.storySummaryBody
        storyBodyLabel.adjustsFontForContentSizeCategory = true
        storyBodyLabel.textColor = AppTheme.Colors.secondaryText
        storyBodyLabel.numberOfLines = 3

        storyFadeView.translatesAutoresizingMaskIntoConstraints = false
        storyFadeView.isUserInteractionEnabled = false
        storyFadeView.backgroundColor = UIColor(patternImage: gradientImage(size: CGSize(width: 8, height: 66)))

        storyToggleButton.translatesAutoresizingMaskIntoConstraints = false
        storyToggleButton.titleLabel?.font = AppTheme.Typography.compactButton
        storyToggleButton.setTitleColor(AppTheme.Colors.tint, for: .normal)
        storyToggleButton.contentHorizontalAlignment = .leading
        storyToggleButton.addTarget(self, action: #selector(toggleStorySummary), for: .touchUpInside)

        summaryDividerView.translatesAutoresizingMaskIntoConstraints = false
        summaryDividerView.backgroundColor = AppTheme.Colors.border

        let dotLabel = UILabel()
        dotLabel.translatesAutoresizingMaskIntoConstraints = false
        dotLabel.text = "·"
        dotLabel.font = AppTheme.Typography.compactMeta
        dotLabel.textColor = AppTheme.Colors.tertiaryText

        let metaSpacer = UIView()
        metaSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        metaRow.addArrangedSubview(pointsPillView)
        metaRow.addArrangedSubview(domainLabel)
        metaRow.addArrangedSubview(dotLabel)
        metaRow.addArrangedSubview(ageLabel)
        metaRow.addArrangedSubview(metaSpacer)

        summaryContentView.addSubview(metaRow)
        summaryContentView.addSubview(storyTitleLabel)
        summaryContentView.addSubview(storyBodyLabel)
        summaryContentView.addSubview(storyFadeView)
        summaryContentView.addSubview(storyToggleButton)
        summaryContentView.addSubview(summaryDividerView)

        NSLayoutConstraint.activate([
            summaryContentView.topAnchor.constraint(equalTo: summaryHeaderView.topAnchor),
            summaryContentView.leadingAnchor.constraint(equalTo: summaryHeaderView.leadingAnchor),
            summaryContentView.trailingAnchor.constraint(equalTo: summaryHeaderView.trailingAnchor),
            summaryContentView.bottomAnchor.constraint(equalTo: summaryHeaderView.bottomAnchor),
            summaryContentView.widthAnchor.constraint(equalTo: summaryHeaderView.widthAnchor),

            metaRow.topAnchor.constraint(equalTo: summaryContentView.topAnchor, constant: 4),
            metaRow.leadingAnchor.constraint(equalTo: summaryContentView.leadingAnchor, constant: 16),
            metaRow.trailingAnchor.constraint(equalTo: summaryContentView.trailingAnchor, constant: -16),

            pointsPillImageView.leadingAnchor.constraint(equalTo: pointsPillView.leadingAnchor, constant: 8),
            pointsPillImageView.centerYAnchor.constraint(equalTo: pointsPillView.centerYAnchor),
            pointsPillImageView.widthAnchor.constraint(equalToConstant: 10),
            pointsPillImageView.heightAnchor.constraint(equalToConstant: 10),

            pointsPillLabel.leadingAnchor.constraint(equalTo: pointsPillImageView.trailingAnchor, constant: 6),
            pointsPillLabel.trailingAnchor.constraint(equalTo: pointsPillView.trailingAnchor, constant: -8),
            pointsPillLabel.topAnchor.constraint(equalTo: pointsPillView.topAnchor, constant: 5),
            pointsPillLabel.bottomAnchor.constraint(equalTo: pointsPillView.bottomAnchor, constant: -5),

            storyTitleLabel.topAnchor.constraint(equalTo: metaRow.bottomAnchor, constant: 12),
            storyTitleLabel.leadingAnchor.constraint(equalTo: summaryContentView.leadingAnchor, constant: 16),
            storyTitleLabel.trailingAnchor.constraint(equalTo: summaryContentView.trailingAnchor, constant: -16),

            storyBodyLabel.topAnchor.constraint(equalTo: storyTitleLabel.bottomAnchor, constant: 10),
            storyBodyLabel.leadingAnchor.constraint(equalTo: summaryContentView.leadingAnchor, constant: 16),
            storyBodyLabel.trailingAnchor.constraint(equalTo: summaryContentView.trailingAnchor, constant: -16),

            storyFadeView.leadingAnchor.constraint(equalTo: storyBodyLabel.leadingAnchor),
            storyFadeView.trailingAnchor.constraint(equalTo: storyBodyLabel.trailingAnchor),
            storyFadeView.bottomAnchor.constraint(equalTo: storyBodyLabel.bottomAnchor),
            storyFadeView.heightAnchor.constraint(equalToConstant: 28),

            storyToggleButton.topAnchor.constraint(equalTo: storyBodyLabel.bottomAnchor, constant: 6),
            storyToggleButton.leadingAnchor.constraint(equalTo: summaryContentView.leadingAnchor, constant: 16),
            storyToggleButton.trailingAnchor.constraint(lessThanOrEqualTo: summaryContentView.trailingAnchor, constant: -16),

            summaryDividerView.topAnchor.constraint(equalTo: storyToggleButton.bottomAnchor, constant: 12),
            summaryDividerView.leadingAnchor.constraint(equalTo: summaryContentView.leadingAnchor),
            summaryDividerView.trailingAnchor.constraint(equalTo: summaryContentView.trailingAnchor),
            summaryDividerView.bottomAnchor.constraint(equalTo: summaryContentView.bottomAnchor),
            summaryDividerView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupBindings() {
        guard let viewModel else { return }

        viewModel.$commentTree
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tree in
                self?.applyCommentTree(tree)
            }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                isLoading ? self?.showLoadingIndicator() : self?.hideLoadingIndicator()
            }
            .store(in: &cancellables)

        viewModel.$hasLoadedAll
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasLoadedAll in
                self?.loadMoreButton.isHidden = hasLoadedAll
                self?.footerContainerView.frame.size.height = hasLoadedAll ? 1 : 76
                self?.tableView.tableFooterView = self?.footerContainerView
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showAlert(title: "Error", message: error)
            }
            .store(in: &cancellables)
    }

    private func applyStorySummary() {
        guard let story else { return }

        pointsPillLabel.text = "+\(story.score) pts"
        domainLabel.text = formattedDomain(from: story.url)
        ageLabel.text = formatTime(timestamp: story.time)
        storyTitleLabel.text = story.title
        storyBodyLabel.text = summaryText(for: story)
        updateStorySummaryControls()
        needsHeaderLayoutRefresh = true
        titleLabel.text = "\(story.descendants) comments"
    }

    private func updateStorySummaryControls() {
        let hasLongSummary = (storyBodyLabel.text ?? "").count > 140
        storyBodyLabel.numberOfLines = summaryExpanded ? 0 : 3
        storyFadeView.isHidden = summaryExpanded || !hasLongSummary
        storyToggleButton.isHidden = !hasLongSummary
        storyToggleButton.setTitle(summaryExpanded ? "Show less" : "Read more", for: .normal)
        needsHeaderLayoutRefresh = true
        updateSummaryHeaderLayoutIfNeeded(force: true)
    }

    private func applyCommentTree(_ tree: [CommentNode]) {
        let roots = sortedRoots(from: tree)
        visibleCommentNodes = CommentTreeFlattener.flatten(roots)
        let totalComments = countComments(in: tree)
        titleLabel.text = "\(totalComments) comments"
        tableView.reloadData()
    }

    private func sortedRoots(from tree: [CommentNode]) -> [CommentNode] {
        switch sort {
        case .top:
            return tree
        case .newest:
            return tree.sorted { ($0.comment.time ?? 0) > ($1.comment.time ?? 0) }
        case .oldest:
            return tree.sorted { ($0.comment.time ?? 0) < ($1.comment.time ?? 0) }
        }
    }

    private func countComments(in nodes: [CommentNode]) -> Int {
        nodes.reduce(0) { partialResult, node in
            partialResult + 1 + countComments(in: node.children)
        }
    }

    private func formattedDomain(from urlString: String?) -> String {
        guard let urlString,
              let host = URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: "") else {
            return "news.ycombinator.com"
        }

        return host
    }

    private func summaryText(for story: Story) -> String {
        if let html = story.topComment?.text {
            let text = strippedHTMLText(from: html)
            if !text.isEmpty {
                return text
            }
        }

        if let url = story.url {
            return "Open the linked story at \(formattedDomain(from: url)) and browse the discussion below."
        }

        return "Browse the discussion below."
    }

    private func strippedHTMLText(from html: String) -> String {
        HTMLTextExtractor.plainText(from: html)
    }

    private func formatTime(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func updateSortMenu() {
        sortButton.menu = UIMenu(children: SortOption.allCases.map { option in
            UIAction(
                title: option.title,
                image: option == sort ? UIImage(systemName: "checkmark") : nil,
                state: option == sort ? .on : .off
            ) { [weak self] _ in
                self?.sort = option
                self?.updateSortMenu()
                self?.applyCommentTree(self?.viewModel?.commentTree ?? [])
            }
        })
    }

    private func updateSummaryHeaderLayoutIfNeeded(force: Bool) {
        guard force || needsHeaderLayoutRefresh || summaryHeaderView.bounds.width != tableView.bounds.width else {
            return
        }

        let targetSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let fittingSize = summaryHeaderView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        if summaryHeaderView.frame.width != tableView.bounds.width || summaryHeaderView.frame.height != fittingSize.height {
            summaryHeaderView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: fittingSize.height)
            tableView.tableHeaderView = summaryHeaderView
        }

        needsHeaderLayoutRefresh = false
    }

    private func updateHeaderChrome(for offsetY: CGFloat) {
        let isCollapsed = offsetY > 40
        let dividerAlpha = max(0, min(1, offsetY / 16))
        chromeDividerView.alpha = dividerAlpha

        guard isCollapsed != lastHeaderCollapsed else { return }
        lastHeaderCollapsed = isCollapsed

        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.titleLabel.alpha = isCollapsed ? 1 : 0
            self.titleLabel.transform = isCollapsed ? .identity : CGAffineTransform(translationX: 0, y: 4)
        }
    }

    private func showLoadingIndicator() {
        loadingIndicator.startAnimating()
    }

    private func hideLoadingIndicator() {
        loadingIndicator.stopAnimating()
    }

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }

    @objc private func closePressed() {
        if let onClose {
            onClose()
            return
        }

        dismiss(animated: true)
    }

    @objc private func loadMorePressed() {
        Task {
            await viewModel?.loadMoreComments()
        }
    }

    @objc private func toggleStorySummary() {
        summaryExpanded.toggle()
        updateStorySummaryControls()
    }

    private func gradientImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors = [
                AppTheme.Colors.background.withAlphaComponent(0).cgColor,
                AppTheme.Colors.background.cgColor
            ] as CFArray

            let locations: [CGFloat] = [0, 1]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) else {
                return
            }

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }
}

extension CommentsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visibleCommentNodes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < visibleCommentNodes.count,
              let cell = tableView.dequeueReusableCell(withIdentifier: CommentCell.reuseIdentifier, for: indexPath) as? CommentCell else {
            return UITableViewCell()
        }

        let entry = visibleCommentNodes[indexPath.row]
        let node = entry.node
        cell.configure(with: node, depth: entry.depth, storyAuthor: story?.by) { [weak self] in
            self?.viewModel?.toggleCollapse(nodeId: node.id)
        }
        return cell
    }
}

extension CommentsViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateHeaderChrome(for: scrollView.contentOffset.y)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
