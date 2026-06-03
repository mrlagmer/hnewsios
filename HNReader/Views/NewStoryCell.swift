//
//  NewStoryCell.swift
//  HNReader
//
//  List-style row for the "New" feed (`/newest`). Recency-emphasised: a time
//  rail on the left, points de-emphasised, comments shown as a count or a
//  "discuss" prompt when the thread is empty.
//

import UIKit

final class NewStoryCell: UICollectionViewCell {
    static let reuseIdentifier = "NewStoryCell"

    private enum UI {
        static let railWidth: CGFloat = 48
        static let railSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 4
        static let verticalPadding: CGFloat = 12
    }

    var onCommentsTap: (() -> Void)?

    // Time rail
    private let railStack = UIStackView()
    private let ageLabel = UILabel()
    private let newBadgeLabel = UILabel()

    // Body
    private let bodyStack = UIStackView()
    private let titleLabel = UILabel()
    private let metaRow = UIStackView()
    private let metaTextLabel = UILabel()
    private let commentsButton = UIButton(type: .system)

    private let separator = UIView()

    private static let titleFont = UIFontMetrics.default.scaledFont(
        for: .systemFont(ofSize: 15.5, weight: .semibold)
    )
    private static let ageFont = UIFontMetrics.default.scaledFont(
        for: .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
    )
    private static let metaFont = UIFontMetrics.default.scaledFont(
        for: .systemFont(ofSize: 12, weight: .regular)
    )
    private static let commentsFont = UIFontMetrics.default.scaledFont(
        for: .systemFont(ofSize: 12.5, weight: .semibold)
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let targetWidth = layoutAttributes.frame.width

        if abs(bounds.width - targetWidth) > 0.5 {
            bounds.size.width = targetWidth
        }
        if abs(contentView.bounds.width - targetWidth) > 0.5 {
            contentView.bounds.size.width = targetWidth
        }

        let bodyWidth = max(
            0,
            targetWidth - (UI.horizontalPadding * 2) - UI.railWidth - UI.railSpacing
        )
        if abs(titleLabel.preferredMaxLayoutWidth - bodyWidth) > 0.5 {
            titleLabel.preferredMaxLayoutWidth = bodyWidth
        }

        setNeedsLayout()
        layoutIfNeeded()

        let targetSize = CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height)
        let preferredSize = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        layoutAttributes.frame.size = CGSize(width: targetWidth, height: ceil(preferredSize.height))
        return layoutAttributes
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.attributedText = nil
        titleLabel.text = nil
        ageLabel.text = nil
        metaTextLabel.attributedText = nil
        newBadgeLabel.isHidden = true
        commentsButton.removeTarget(nil, action: nil, for: .allEvents)
        onCommentsTap = nil
    }

    private func setupViews() {
        contentView.backgroundColor = .clear

        // Time rail ------------------------------------------------------
        railStack.translatesAutoresizingMaskIntoConstraints = false
        railStack.axis = .vertical
        railStack.alignment = .trailing
        railStack.spacing = 3

        ageLabel.font = Self.ageFont
        ageLabel.adjustsFontForContentSizeCategory = true
        ageLabel.textColor = AppTheme.Colors.primaryText
        ageLabel.textAlignment = .right

        newBadgeLabel.attributedText = NSAttributedString(
            string: "NEW",
            attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: AppTheme.Colors.tint,
                .kern: 0.7
            ]
        )
        newBadgeLabel.isHidden = true

        railStack.addArrangedSubview(ageLabel)
        railStack.addArrangedSubview(newBadgeLabel)

        // Body -----------------------------------------------------------
        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.axis = .vertical
        bodyStack.alignment = .fill
        bodyStack.spacing = 5

        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.font = Self.titleFont
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.Colors.primaryText

        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 6

        metaTextLabel.font = Self.metaFont
        metaTextLabel.adjustsFontForContentSizeCategory = true
        metaTextLabel.textColor = AppTheme.Colors.secondaryText
        metaTextLabel.numberOfLines = 1
        metaTextLabel.lineBreakMode = .byTruncatingTail
        metaTextLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var commentsConfig = UIButton.Configuration.plain()
        commentsConfig.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
        commentsConfig.image = UIImage(
            systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        )
        commentsConfig.imagePlacement = .trailing
        commentsConfig.imagePadding = 3
        commentsConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = Self.commentsFont
            return outgoing
        }
        commentsButton.configuration = commentsConfig
        commentsButton.setContentHuggingPriority(.required, for: .horizontal)
        commentsButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        commentsButton.configurationUpdateHandler = { button in
            button.alpha = button.isHighlighted ? 0.7 : 1.0
        }

        let metaSpacer = UIView()
        metaSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        metaRow.addArrangedSubview(metaTextLabel)
        metaRow.addArrangedSubview(metaSpacer)
        metaRow.addArrangedSubview(commentsButton)

        bodyStack.addArrangedSubview(titleLabel)
        bodyStack.addArrangedSubview(metaRow)

        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = AppTheme.Colors.border

        contentView.addSubview(railStack)
        contentView.addSubview(bodyStack)
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            railStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UI.verticalPadding + 1),
            railStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UI.horizontalPadding),
            railStack.widthAnchor.constraint(equalToConstant: UI.railWidth),

            bodyStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UI.verticalPadding),
            bodyStack.leadingAnchor.constraint(equalTo: railStack.trailingAnchor, constant: UI.railSpacing),
            bodyStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UI.horizontalPadding),
            bodyStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UI.verticalPadding),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UI.horizontalPadding),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UI.horizontalPadding),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / max(UIScreen.main.scale, 1))
        ])
    }

    func configure(with story: Story, showsSeparator: Bool = true, onCommentsTap: (() -> Void)? = nil) {
        self.onCommentsTap = onCommentsTap
        separator.isHidden = !showsSeparator

        // Rail
        ageLabel.text = formatTime(timestamp: story.time)
        ageLabel.textColor = story.isNew ? AppTheme.Colors.tint : AppTheme.Colors.primaryText
        newBadgeLabel.isHidden = !story.isNew

        // Title (with an ASK tag for Ask HN posts)
        titleLabel.attributedText = makeTitle(for: story)

        // Meta: domain · ▲points · user
        metaTextLabel.attributedText = makeMeta(for: story)

        // Comments / discuss link
        let hasDiscussion = story.descendants > 0
        let linkColor = hasDiscussion ? AppTheme.Colors.tint : AppTheme.Colors.tertiaryText
        commentsButton.configuration?.title = hasDiscussion ? "\(story.descendants)" : "discuss"
        commentsButton.configuration?.baseForegroundColor = linkColor
        commentsButton.accessibilityLabel = "Comments"
        commentsButton.accessibilityValue = hasDiscussion ? "\(story.descendants) comments" : "No comments yet"
        commentsButton.removeTarget(nil, action: nil, for: .allEvents)
        commentsButton.addAction(UIAction { [weak self] _ in self?.onCommentsTap?() }, for: .touchUpInside)
    }

    // MARK: - Content builders

    private func makeTitle(for story: Story) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if story.title.lowercased().hasPrefix("ask hn") {
            result.append(NSAttributedString(
                string: "ASK ",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: AppTheme.Colors.tint
                ]
            ))
        }
        result.append(NSAttributedString(
            string: story.title,
            attributes: [
                .font: Self.titleFont,
                .foregroundColor: AppTheme.Colors.primaryText
            ]
        ))
        return result
    }

    private func makeMeta(for story: Story) -> NSAttributedString {
        let dotColor = AppTheme.Colors.tertiaryText
        let result = NSMutableAttributedString()

        func appendSeparator() {
            result.append(NSAttributedString(
                string: "  ·  ",
                attributes: [.font: Self.metaFont, .foregroundColor: dotColor]
            ))
        }

        if let domain = formattedDomain(from: story.url) {
            result.append(NSAttributedString(
                string: domain,
                attributes: [.font: Self.metaFont, .foregroundColor: AppTheme.Colors.tertiaryText]
            ))
            appendSeparator()
        }

        // ▲ points
        if let triangle = triangleAttachmentString() {
            result.append(triangle)
            result.append(NSAttributedString(
                string: " \(story.score)",
                attributes: [
                    .font: Self.metaFont,
                    .foregroundColor: AppTheme.Colors.secondaryText
                ]
            ))
        }

        if let user = story.by, !user.isEmpty {
            appendSeparator()
            result.append(NSAttributedString(
                string: user,
                attributes: [.font: Self.metaFont, .foregroundColor: AppTheme.Colors.secondaryText]
            ))
        }

        return result
    }

    private func triangleAttachmentString() -> NSAttributedString? {
        let config = UIImage.SymbolConfiguration(pointSize: 9, weight: .regular)
        guard let image = UIImage(systemName: "arrowtriangle.up", withConfiguration: config)?
            .withTintColor(AppTheme.Colors.secondaryText, renderingMode: .alwaysOriginal) else {
            return nil
        }
        let attachment = NSTextAttachment(image: image)
        let size = image.size
        // Nudge the glyph onto the text baseline.
        attachment.bounds = CGRect(x: 0, y: -1, width: size.width, height: size.height)
        return NSAttributedString(attachment: attachment)
    }

    private func formattedDomain(from urlString: String?) -> String? {
        // Ask HN / text posts have no URL — the design hides the domain entirely.
        guard let urlString,
              let host = URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: "") else {
            return nil
        }
        return host
    }

    /// Compact, single-token age (`now`, `12m`, `2h`, `3d`) so it always fits
    /// the narrow time rail — unlike `RelativeDateTimeFormatter`'s "12 min".
    private func formatTime(timestamp: Int) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince1970) - timestamp)
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 7 { return "\(days)d" }
        let weeks = days / 7
        if weeks < 52 { return "\(weeks)w" }
        return "\(days / 365)y"
    }
}
