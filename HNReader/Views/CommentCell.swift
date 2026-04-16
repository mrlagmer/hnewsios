//
//  CommentCell.swift
//  HNReader
//

import UIKit

class CommentCell: UITableViewCell {
    static let reuseIdentifier = "CommentCell"

    private let containerView = UIView()
    private let indentView = UIView()
    private let authorLabel = UILabel()
    private let timeLabel = UILabel()
    private let commentTextLabel = UILabel()
    private let collapseIndicator = UIButton(type: .system)
    private let collapsedLabel = UILabel()
    private var indentWidthConstraint: NSLayoutConstraint?
    
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
        collapsedLabel.text = nil
        collapsedLabel.isHidden = true
        collapseIndicator.isHidden = true
        onToggle = nil
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = AppTheme.Colors.elevatedSurface
        containerView.layer.cornerRadius = 14
        containerView.layer.cornerCurve = .continuous
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = AppTheme.Colors.border.cgColor
        contentView.addSubview(containerView)

        // Indent view
        indentView.translatesAutoresizingMaskIntoConstraints = false
        indentView.backgroundColor = AppTheme.Colors.rail
        indentView.layer.cornerRadius = 2
        containerView.addSubview(indentView)

        // Author label
        authorLabel.translatesAutoresizingMaskIntoConstraints = false
        authorLabel.font = AppTheme.Typography.metadata
        authorLabel.adjustsFontForContentSizeCategory = true
        authorLabel.numberOfLines = 1
        containerView.addSubview(authorLabel)

        // Time label
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = AppTheme.Typography.detail
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textColor = AppTheme.Colors.tertiaryText
        timeLabel.numberOfLines = 1
        containerView.addSubview(timeLabel)

        // Collapse indicator button
        collapseIndicator.translatesAutoresizingMaskIntoConstraints = false
        collapseIndicator.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        collapseIndicator.tintColor = AppTheme.Colors.secondaryText
        collapseIndicator.backgroundColor = AppTheme.Colors.surface
        collapseIndicator.layer.cornerRadius = AppTheme.Metrics.controlCornerRadius
        collapseIndicator.layer.cornerCurve = .continuous
        collapseIndicator.isHidden = true
        collapseIndicator.accessibilityTraits = .button
        collapseIndicator.accessibilityLabel = "Toggle thread"
        containerView.addSubview(collapseIndicator)

        // Text label
        commentTextLabel.translatesAutoresizingMaskIntoConstraints = false
        commentTextLabel.numberOfLines = 0
        commentTextLabel.font = AppTheme.Typography.commentPreview
        commentTextLabel.adjustsFontForContentSizeCategory = true
        containerView.addSubview(commentTextLabel)

        // Collapsed label
        collapsedLabel.translatesAutoresizingMaskIntoConstraints = false
        collapsedLabel.font = AppTheme.Typography.detail
        collapsedLabel.adjustsFontForContentSizeCategory = true
        collapsedLabel.textColor = AppTheme.Colors.secondaryText
        collapsedLabel.isHidden = true
        containerView.addSubview(collapsedLabel)

        indentWidthConstraint = indentView.widthAnchor.constraint(equalToConstant: AppTheme.Metrics.commentRailMinWidth)

        // Layout constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            // Indent view on the left
            indentView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            indentView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            indentView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14),

            // Author and time labels
            authorLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            authorLabel.leadingAnchor.constraint(equalTo: indentView.trailingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(lessThanOrEqualTo: collapseIndicator.leadingAnchor, constant: -8),

            timeLabel.topAnchor.constraint(equalTo: authorLabel.topAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: collapseIndicator.leadingAnchor, constant: -8),
            timeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: authorLabel.trailingAnchor, constant: 8),

            // Collapse indicator
            collapseIndicator.centerYAnchor.constraint(equalTo: authorLabel.centerYAnchor),
            collapseIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            collapseIndicator.widthAnchor.constraint(equalToConstant: 32),
            collapseIndicator.heightAnchor.constraint(equalToConstant: 32),

            // Text label
            commentTextLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4),
            commentTextLabel.leadingAnchor.constraint(equalTo: indentView.trailingAnchor, constant: 12),
            commentTextLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),

            // Collapsed label
            collapsedLabel.topAnchor.constraint(equalTo: commentTextLabel.topAnchor),
            collapsedLabel.leadingAnchor.constraint(equalTo: commentTextLabel.leadingAnchor),
            collapsedLabel.trailingAnchor.constraint(equalTo: commentTextLabel.trailingAnchor),
            collapsedLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14)
        ])

        indentWidthConstraint?.isActive = true

        // Add bottom padding constraint for text label
        let bottomConstraint = commentTextLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -14)
        bottomConstraint.priority = UILayoutPriority(999)
        bottomConstraint.isActive = true
    }

    func configure(with node: CommentNode, depth: Int, onToggle: (() -> Void)? = nil) {
        self.onToggle = onToggle

        // Set author
        let author: String
        if let authorName = node.comment.by {
            author = authorName
            authorLabel.text = author
        } else {
            author = "[deleted]"
            authorLabel.text = author
        }

        // Set time
        let timeFormatted: String
        if let time = node.comment.time {
            timeFormatted = formatTime(timestamp: time)
            timeLabel.text = timeFormatted
        } else {
            timeFormatted = ""
            timeLabel.text = ""
        }

        // Set accessibility labels for the cell
        let commentText = node.comment.text ?? "[deleted]"
        contentView.accessibilityLabel = "Comment by \(author)"
        contentView.accessibilityValue = "\(timeFormatted). \(commentText)"
        contentView.accessibilityTraits = .none

        // Set indent based on depth
        let indentWidth = max(
            AppTheme.Metrics.commentRailMinWidth,
            min(
                CGFloat(depth) * AppTheme.Metrics.commentIndentStep + AppTheme.Metrics.commentRailMinWidth,
                AppTheme.Metrics.commentIndentMaxWidth
            )
        )
        indentWidthConstraint?.constant = indentWidth

        // Configure text and collapse state
        if node.isCollapsed {
            // Show collapsed state
            commentTextLabel.isHidden = true
            collapsedLabel.isHidden = false
            let replyCount = node.children.count
            collapsedLabel.text = "[\(replyCount) more replies]"
            collapseIndicator.setImage(UIImage(systemName: "chevron.right"), for: .normal)
            collapseIndicator.accessibilityValue = "\(replyCount) replies"
        } else {
            // Show text
            commentTextLabel.isHidden = false
            collapsedLabel.isHidden = true
            if let html = node.comment.text {
                commentTextLabel.attributedText = renderHTMLText(html)
            } else {
                commentTextLabel.text = "[deleted]"
            }
            collapseIndicator.setImage(UIImage(systemName: "chevron.down"), for: .normal)
            collapseIndicator.accessibilityValue = "Collapse thread"
        }

        // Show/hide collapse indicator
        collapseIndicator.isHidden = node.children.isEmpty

        // Configure tap handler for collapse indicator
        collapseIndicator.removeTarget(nil, action: nil, for: .allEvents)
        if !node.children.isEmpty {
            collapseIndicator.addAction(UIAction { [weak self] _ in
                self?.onToggle?()
            }, for: .touchUpInside)
        }
    }

    func renderHTMLText(_ html: String) -> NSAttributedString? {
        let data = Data(html.utf8)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let attr = try? NSMutableAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        // Apply base font and paragraph style
        let fullRange = NSRange(location: 0, length: attr.length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = AppTheme.Metrics.xSmall
        paragraph.minimumLineHeight = 19

        attr.addAttributes([
            .font: AppTheme.Typography.commentPreview,
            .paragraphStyle: paragraph,
            .foregroundColor: UIColor.label
        ], range: fullRange)

        return attr
    }

    private func formatTime(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
