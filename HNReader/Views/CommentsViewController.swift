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
    var viewModel: CommentsViewModel?
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let closeButton = UIBarButtonItem()
    private let loadMoreButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    private var cancellables = Set<AnyCancellable>()
    private var visibleCommentNodes: [FlattenedCommentNode] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Colors.background
        
        // Set navigation title
        title = "Comments"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        setupTableView()
        setupBindings()
        Task {
            await viewModel?.loadInitialComments()
        }
    }
    
    private func setupTableView() {
        // Configure view
        view.backgroundColor = AppTheme.Colors.background
        
        // Configure table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseIdentifier)
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = AppTheme.Colors.background
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: AppTheme.Metrics.small, left: 0, bottom: 12, right: 0)
        tableView.verticalScrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 12, right: 0)
        tableView.accessibilityLabel = "Comments"
        view.addSubview(tableView)
        
        // Configure close button
        closeButton.image = UIImage(systemName: "xmark")
        closeButton.style = .plain
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        closeButton.accessibilityLabel = "Close comments"
        navigationItem.rightBarButtonItem = closeButton
        
        // Configure load more button
        loadMoreButton.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.tinted()
        config.title = "Load more comments"
        config.image = UIImage(systemName: "arrow.down.circle")
        config.imagePadding = AppTheme.Metrics.small
        config.baseBackgroundColor = AppTheme.Colors.tint
        config.baseForegroundColor = AppTheme.Colors.tint
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        loadMoreButton.configuration = config
        loadMoreButton.addTarget(self, action: #selector(loadMorePressed), for: .touchUpInside)
        loadMoreButton.isHidden = true
        loadMoreButton.accessibilityLabel = "Load more comments"
        loadMoreButton.accessibilityTraits = .button
        view.addSubview(loadMoreButton)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = AppTheme.Colors.tint
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            loadMoreButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            loadMoreButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            loadMoreButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            loadMoreButton.heightAnchor.constraint(equalToConstant: 44),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
    }
    
    private func setupBindings() {
        guard let viewModel = viewModel else { return }
        
        viewModel.$commentTree
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tree in
                self?.visibleCommentNodes = CommentTreeFlattener.flatten(tree)
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.showLoadingIndicator()
                } else {
                    self?.hideLoadingIndicator()
                }
            }
            .store(in: &cancellables)
        
        viewModel.$hasLoadedAll
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasLoadedAll in
                self?.loadMoreButton.isHidden = hasLoadedAll
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
    
    @objc private func closePressed() {
        dismiss(animated: true)
    }
    
    @objc private func loadMorePressed() {
        Task {
            await viewModel?.loadMoreComments()
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
}

extension CommentsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleCommentNodes.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < visibleCommentNodes.count else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: CommentCell.reuseIdentifier, for: indexPath) as! CommentCell

        let entry = visibleCommentNodes[indexPath.row]
        let node = entry.node
        
        cell.configure(with: node, depth: entry.depth) { [weak self] in
            self?.viewModel?.toggleCollapse(nodeId: node.id)
        }
        
        return cell
    }
}

extension CommentsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
