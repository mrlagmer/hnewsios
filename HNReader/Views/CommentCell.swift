//
//  CommentCell.swift
//  HNReader
//

import UIKit

final class CommentCell: UITableViewCell {
    static let reuseIdentifier = "CommentCell"

    private let nodeContainerView = UIView()
    private let topBorderView = UIView()
    private let railButton = UIButton(type: .system)
    private let railView = UIView()
    private let verticalStack = UIStackView()
    private let headerRow = UIStackView()
    private let metaRow = UIStackView()
    private let authorLabel = UILabel()
    private let opBadgeLabel = UILabel()
    private let metaDotLabel = UILabel()
    private let timeLabel = UILabel()
    private let collapseButton = UIButton(type: .system)
    private let commentTextLabel = UILabel()
    private let actionRow = UIStackView()
    private let upvoteButton = UIButton(type: .system)
    private let replyButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private let headerTapButton = UIButton(type: .custom)

    private var containerLeadingConstraint: NSLayoutConstraint?
    private var onToggle: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        authorLabel.text = nil
        timeLabel.text = nil
        commentTextLabel.attributedText = nil
        opBadgeLabel.isHidden = true
        collapseButton.isHidden = true
        headerTapButton.isHidden = true
        railButton.isHidden = true
        onToggle = nil
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false

        nodeContainerView.translatesAutoresizingMaskIntoConstraints = false
        nodeContainerView.layer.cornerRadius = 16
        nodeContainerView.layer.cornerCurve = .continuous
        nodeContainerView.clipsToBounds = true
        contentView.addSubview(nodeContainerView)

        topBorderView.translatesAutoresizingMaskIntoConstraints = false
        topBorderView.backgroundColor = AppTheme.Colors.border
        nodeContainerView.addSubview(topBorderView)

        railButton.translatesAutoresizingMaskIntoConstraints = false
        railButton.tintColor = .clear
        railButton.addTarget(self, action: #selector(toggleThread), for: .touchUpInside)
        contentView.addSubview(railButton)

        railView.translatesAutoresizingMaskIntoConstraints = false
        railView.layer.cornerRadius = 1
        railButton.addSubview(railView)

        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        verticalStack.axis = .vertical
        verticalStack.spacing = 10
        nodeContainerView.addSubview(verticalStack)

        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 8

        metaRow.translatesAutoresizingMaskIntoConstraints = false
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 6

        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = AppTheme.Typography.commentMeta
        authorLabel.adjustsFontForContentSizeCategory = true
        authorLabel.textColor = AppTheme.Colors.primaryText

        opBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        opBadgeLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        opBadgeLabel.text = "OP"
        opBadgeLabel.textColor = AppTheme.Colors.tint
        opBadgeLabel.backgroundColor = AppTheme.Colors.accentSoft
        opBadgeLabel.layer.cornerRadius = 4
        opBadgeLabel.layer.cornerCurve = .continuous
        opBadgeLabel.textAlignment = .center
        opBadgeLabel.isHidden = true

        metaDotLabel.translatesAutoresizingMaskIntoConstraints = false
        metaDotLabel.font = AppTheme.Typography.commentMetaDetail
        metaDotLabel.text = "·"
        metaDotLabel.textColor = AppTheme.Colors.tertiaryText

        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = AppTheme.Typography.commentMetaDetail
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textColor = AppTheme.Colors.secondaryText

        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        collapseButton.titleLabel?.font = AppTheme.Typography.commentMetaDetail
        collapseButton.setTitleColor(AppTheme.Colors.tint, for: .normal)
        collapseButton.tintColor = AppTheme.Colors.tint
        collapseButton.addTarget(self, action: #selector(toggleThread), for: .touchUpInside)
        collapseButton.isHidden = true

        commentTextLabel.translatesAutoresizingMaskIntoConstraints = false
        commentTextLabel.numberOfLines = 0
        commentTextLabel.font = AppTheme.Typography.commentBody
        commentTextLabel.adjustsFontForContentSizeCategory = true
        commentTextLabel.textColor = AppTheme.Colors.primaryText

        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.axis = .horizontal
        actionRow.alignment = .center
        actionRow.spacing = 4

        configureActionButton(upvoteButton, title: "Upvote", imageName: "arrowtriangle.up")
        configureActionButton(replyButton, title: "Reply", imageName: "arrowshape.turn.up.left")
        configureActionButton(moreButton, title: nil, imageName: "ellipsis")

        let actionSpacer = UIView()
        actionSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        metaRow.addArrangedSubview(authorLabel)
        metaRow.addArrangedSubview(opBadgeLabel)
        metaRow.addArrangedSubview(metaDotLabel)
        metaRow.addArrangedSubview(timeLabel)

        headerRow.addArrangedSubview(metaRow)
        headerRow.addArrangedSubview(UIView())
        headerRow.addArrangedSubview(collapseButton)

        actionRow.addArrangedSubview(upvoteButton)
        actionRow.addArrangedSubview(replyButton)
        actionRow.addArrangedSubview(actionSpacer)
        actionRow.addArrangedSubview(moreButton)

        verticalStack.addArrangedSubview(headerRow)
        verticalStack.addArrangedSubview(commentTextLabel)
        verticalStack.addArrangedSubview(actionRow)

        headerTapButton.translatesAutoresizingMaskIntoConstraints = false
        headerTapButton.backgroundColor = .clear
        headerTapButton.addTarget(self, action: #selector(toggleThread), for: .touchUpInside)
        headerTapButton.isHidden = true
        nodeContainerView.addSubview(headerTapButton)

        containerLeadingConstraint = nodeContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)

        NSLayoutConstraint.activate([
            nodeContainerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerLeadingConstraint!,
            nodeContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nodeContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            topBorderView.topAnchor.constraint(equalTo: nodeContainerView.topAnchor),
            topBorderView.leadingAnchor.constraint(equalTo: nodeContainerView.leadingAnchor),
            topBorderView.trailingAnchor.constraint(equalTo: nodeContainerView.trailingAnchor),
            topBorderView.heightAnchor.constraint(equalToConstant: 1),

            railButton.leadingAnchor.constraint(equalTo: nodeContainerView.leadingAnchor, constant: -7),
            railButton.topAnchor.constraint(equalTo: nodeContainerView.topAnchor),
            railButton.bottomAnchor.constraint(equalTo: nodeContainerView.bottomAnchor),
            railButton.widthAnchor.constraint(equalToConstant: 14),

            railView.centerXAnchor.constraint(equalTo: railButton.centerXAnchor),
            railView.topAnchor.constraint(equalTo: railButton.topAnchor),
            railView.bottomAnchor.constraint(equalTo: railButton.bottomAnchor),
            railView.widthAnchor.constraint(equalToConstant: 2),

            verticalStack.topAnchor.constraint(equalTo: nodeContainerView.topAnchor, constant: 12),
            verticalStack.leadingAnchor.constraint(equalTo: nodeContainerView.leadingAnchor, constant: 16),
            verticalStack.trailingAnchor.constraint(equalTo: nodeContainerView.trailingAnchor, constant: -16),
            verticalStack.bottomAnchor.constraint(equalTo: nodeContainerView.bottomAnchor, constant: -14),

            opBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),

            headerTapButton.topAnchor.constraint(equalTo: nodeContainerView.topAnchor),
            headerTapButton.leadingAnchor.constraint(equalTo: nodeContainerView.leadingAnchor),
            headerTapButton.trailingAnchor.constraint(equalTo: nodeContainerView.trailingAnchor),
            headerTapButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    func configure(with node: CommentNode, depth: Int, storyAuthor: String?, onToggle: (() -> Void)? = nil) {
        self.onToggle = onToggle

        let displayedDepth = min(depth, Int(AppTheme.Metrics.commentMaxDepth))
        containerLeadingConstraint?.constant = 16 + CGFloat(displayedDepth) * AppTheme.Metrics.commentIndentStep
        nodeContainerView.backgroundColor = AppTheme.Colors.commentTint(for: displayedDepth)
        topBorderView.isHidden = depth != 0

        let author = node.comment.by ?? "[deleted]"
        authorLabel.text = author
        authorLabel.textColor = author == storyAuthor ? AppTheme.Colors.tint : AppTheme.Colors.primaryText

        let isOP = storyAuthor != nil && author == storyAuthor
        opBadgeLabel.isHidden = !isOP

        let timeFormatted = node.comment.time.map(formatTime(timestamp:)) ?? ""
        timeLabel.text = timeFormatted
        metaDotLabel.isHidden = timeFormatted.isEmpty

        contentView.accessibilityLabel = "Comment by \(author)"
        contentView.accessibilityValue = "\(timeFormatted). \(strippedHTMLText(from: node.comment.text ?? "[deleted]"))"
        contentView.accessibilityTraits = .none

        let hasReplies = !node.children.isEmpty
        railButton.isHidden = !hasReplies || depth == 0
        headerTapButton.isHidden = !hasReplies
        collapseButton.isHidden = !hasReplies
        railView.backgroundColor = node.isCollapsed ? AppTheme.Colors.tint : AppTheme.Colors.rail

        if node.isCollapsed {
            commentTextLabel.isHidden = true
            actionRow.isHidden = true
            collapseButton.backgroundColor = AppTheme.Colors.accentSoft
            collapseButton.layer.cornerRadius = 999
            collapseButton.layer.cornerCurve = .continuous
            collapseButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            let replyCount = descendantCount(in: node.children)
            collapseButton.setTitle("+\(replyCount)", for: .normal)
            collapseButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
            collapseButton.semanticContentAttribute = .forceRightToLeft
            collapseButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        } else {
            commentTextLabel.isHidden = false
            actionRow.isHidden = false
            commentTextLabel.attributedText = renderHTMLText(node.comment.text ?? "[deleted]")
            collapseButton.backgroundColor = .clear
            collapseButton.layer.cornerRadius = 0
            collapseButton.contentEdgeInsets = .zero
            collapseButton.setTitle(nil, for: .normal)
            collapseButton.setImage(UIImage(systemName: "chevron.up"), for: .normal)
            collapseButton.semanticContentAttribute = .unspecified
            collapseButton.imageEdgeInsets = .zero
        }
    }

    func renderHTMLText(_ html: String) -> NSAttributedString? {
        let text = HTMLTextExtractor.plainText(from: html)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        paragraph.paragraphSpacing = 12

        return NSAttributedString(string: text, attributes: [
            .font: AppTheme.Typography.commentBody,
            .paragraphStyle: paragraph,
            .foregroundColor: AppTheme.Colors.primaryText
        ])
    }

    private func configureActionButton(_ button: UIButton, title: String?, imageName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = AppTheme.Colors.secondaryText
        button.setTitleColor(AppTheme.Colors.secondaryText, for: .normal)
        button.titleLabel?.font = AppTheme.Typography.commentMetaDetail
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.setTitle(title, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 8, bottom: 6, right: 10)
        button.layer.cornerRadius = 8
        button.layer.cornerCurve = .continuous
        button.imageView?.contentMode = .scaleAspectFit

        if title != nil {
            button.semanticContentAttribute = .forceLeftToRight
            button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        }
    }

    private func descendantCount(in nodes: [CommentNode]) -> Int {
        nodes.reduce(0) { partialResult, node in
            partialResult + 1 + descendantCount(in: node.children)
        }
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

    @objc private func toggleThread() {
        onToggle?()
    }
}
