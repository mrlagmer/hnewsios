//
//  StoryCell.swift
//  HNReader
//

import UIKit

enum HTMLTextExtractor {
    static func plainText(from html: String) -> String {
        let previewText = html
            .replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "(?i)</(p|div|li|blockquote)>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        return decodeHTMLEntities(in: previewText)
            .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func decodeHTMLEntities(in text: String) -> String {
        let decodedNumericEntities = decodeNumericHTMLEntities(in: text)
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " ")
        ]

        return entities.reduce(decodedNumericEntities) { partialResult, entity in
            partialResult.replacingOccurrences(of: entity.0, with: entity.1)
        }
    }

    private static func decodeNumericHTMLEntities(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "&#(x[0-9A-Fa-f]+|[0-9]+);") else {
            return text
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard !matches.isEmpty else {
            return text
        }

        var decoded = text
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let fullRange = Range(match.range(at: 0), in: decoded),
                  let valueRange = Range(match.range(at: 1), in: decoded) else {
                continue
            }

            let entityValue = String(decoded[valueRange])
            let scalarValue: UInt32?
            if entityValue.hasPrefix("x") || entityValue.hasPrefix("X") {
                scalarValue = UInt32(entityValue.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(entityValue, radix: 10)
            }

            guard let scalarValue, let scalar = UnicodeScalar(scalarValue) else {
                continue
            }

            decoded.replaceSubrange(fullRange, with: String(Character(scalar)))
        }

        return decoded
    }
}

final class StoryCell: UICollectionViewCell {
    static let reuseIdentifier = "StoryCell"

    private let cardView = UIView()
    private let contentStack = UIStackView()
    private let metaHeaderRow = UIStackView()
    private let commentsRow = UIStackView()
    private let socialImageContainer = UIView()
    private let domainLabel = UILabel()
    private let ageLabel = UILabel()
    let titleLabel = UILabel()
    let socialImageView = UIImageView()
    let topCommentLabel = UILabel()
    let scoreButton = UIButton(type: .system)
    let commentsButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var imageLoadTask: Task<Void, Never>?

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

        // Force the cell + contentView to the target width *before* measuring,
        // and set preferredMaxLayoutWidth on every multi-line UILabel. Without
        // this, the cell can be measured against a stale (often narrower) width,
        // labels collapse to ~zero intrinsic height, the stack view compresses
        // them out of view, and only the buttons render text.
        if abs(bounds.width - targetWidth) > 0.5 {
            bounds.size.width = targetWidth
        }
        if abs(contentView.bounds.width - targetWidth) > 0.5 {
            contentView.bounds.size.width = targetWidth
        }

        let cardInset = AppTheme.Metrics.xSmall * 2
        let stackInset = AppTheme.Metrics.large * 2
        let labelWrapWidth = max(0, targetWidth - cardInset - stackInset)
        if abs(titleLabel.preferredMaxLayoutWidth - labelWrapWidth) > 0.5 {
            titleLabel.preferredMaxLayoutWidth = labelWrapWidth
            topCommentLabel.preferredMaxLayoutWidth = labelWrapWidth
        }

        setNeedsLayout()
        layoutIfNeeded()

        let targetSize = CGSize(
            width: targetWidth,
            height: UIView.layoutFittingCompressedSize.height
        )
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
        titleLabel.text = nil
        domainLabel.text = nil
        ageLabel.text = nil
        topCommentLabel.attributedText = nil
        socialImageView.image = nil
        socialImageContainer.isHidden = true
        socialImageView.isHidden = false
        topCommentLabel.isHidden = true
        loadingIndicator.stopAnimating()
        imageLoadTask?.cancel()
        imageLoadTask = nil
    }

    private func setupViews() {
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = AppTheme.Colors.surface
        cardView.layer.cornerRadius = 14
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = AppTheme.Colors.border.cgColor
        cardView.clipsToBounds = true
        cardView.isAccessibilityElement = true
        cardView.accessibilityTraits = .none
        contentView.addSubview(cardView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = AppTheme.Metrics.medium

        metaHeaderRow.translatesAutoresizingMaskIntoConstraints = false
        metaHeaderRow.axis = .horizontal
        metaHeaderRow.alignment = .center
        metaHeaderRow.spacing = AppTheme.Metrics.small

        domainLabel.translatesAutoresizingMaskIntoConstraints = false
        domainLabel.font = AppTheme.Typography.compactMeta
        domainLabel.adjustsFontForContentSizeCategory = true
        domainLabel.textColor = AppTheme.Colors.secondaryText

        ageLabel.translatesAutoresizingMaskIntoConstraints = false
        ageLabel.font = AppTheme.Typography.compactMeta
        ageLabel.adjustsFontForContentSizeCategory = true
        ageLabel.textColor = AppTheme.Colors.tertiaryText

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 3
        titleLabel.font = AppTheme.Typography.storyHeadline
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.Colors.primaryText

        socialImageContainer.translatesAutoresizingMaskIntoConstraints = false
        socialImageContainer.backgroundColor = AppTheme.Colors.surfaceAlt
        socialImageContainer.layer.cornerRadius = 12
        socialImageContainer.layer.cornerCurve = .continuous
        socialImageContainer.clipsToBounds = true
        socialImageContainer.isHidden = true

        socialImageView.translatesAutoresizingMaskIntoConstraints = false
        socialImageView.contentMode = .scaleAspectFill
        socialImageView.clipsToBounds = true
        socialImageView.accessibilityLabel = "Story preview image"

        topCommentLabel.translatesAutoresizingMaskIntoConstraints = false
        topCommentLabel.numberOfLines = 0
        topCommentLabel.lineBreakMode = .byWordWrapping
        topCommentLabel.font = AppTheme.Typography.storySummaryBody
        topCommentLabel.adjustsFontForContentSizeCategory = true
        topCommentLabel.textColor = AppTheme.Colors.secondaryText
        topCommentLabel.accessibilityLabel = "Top comment"
        topCommentLabel.isHidden = true

        scoreButton.translatesAutoresizingMaskIntoConstraints = false
        scoreButton.accessibilityTraits = .staticText
        scoreButton.isUserInteractionEnabled = false
        var scoreConfig = UIButton.Configuration.plain()
        scoreConfig.baseForegroundColor = AppTheme.Colors.tint
        scoreConfig.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)
        scoreConfig.image = UIImage(
            systemName: "arrowtriangle.up",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .regular)
        )
        scoreConfig.imagePlacement = .leading
        scoreConfig.imagePadding = 4
        scoreConfig.background.backgroundColor = AppTheme.Colors.accentSoft
        scoreConfig.background.cornerRadius = 10
        scoreConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Typography.compactMeta
            return outgoing
        }
        scoreButton.configuration = scoreConfig

        commentsButton.translatesAutoresizingMaskIntoConstraints = false
        commentsButton.accessibilityTraits = .button
        var commentsConfiguration = UIButton.Configuration.plain()
        commentsConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        commentsConfiguration.image = UIImage(
            systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        commentsConfiguration.imagePlacement = .trailing
        commentsConfiguration.imagePadding = 4
        commentsConfiguration.baseForegroundColor = AppTheme.Colors.tint
        commentsConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.Typography.commentMeta
            return outgoing
        }
        commentsButton.configuration = commentsConfiguration
        commentsButton.contentHorizontalAlignment = .leading
        commentsButton.contentVerticalAlignment = .center
        commentsButton.configurationUpdateHandler = { button in
            button.alpha = button.isHighlighted ? 0.7 : 1.0
        }

        commentsRow.translatesAutoresizingMaskIntoConstraints = false
        commentsRow.axis = .horizontal
        commentsRow.alignment = .center
        commentsRow.spacing = 0

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.accessibilityLabel = "Loading preview image"
        loadingIndicator.color = AppTheme.Colors.tint

        let dotLabel = UILabel()
        dotLabel.font = AppTheme.Typography.compactMeta
        dotLabel.textColor = AppTheme.Colors.tertiaryText
        dotLabel.text = "·"

        let metaSpacer = UIView()
        metaSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let commentsSpacer = UIView()
        commentsSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        metaHeaderRow.addArrangedSubview(scoreButton)
        metaHeaderRow.addArrangedSubview(domainLabel)
        metaHeaderRow.addArrangedSubview(dotLabel)
        metaHeaderRow.addArrangedSubview(ageLabel)
        metaHeaderRow.addArrangedSubview(metaSpacer)

        commentsRow.addArrangedSubview(commentsButton)
        commentsRow.addArrangedSubview(commentsSpacer)

        socialImageContainer.addSubview(socialImageView)
        socialImageContainer.addSubview(loadingIndicator)

        contentStack.addArrangedSubview(metaHeaderRow)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(socialImageContainer)
        contentStack.addArrangedSubview(topCommentLabel)
        contentStack.addArrangedSubview(commentsRow)
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.Metrics.xSmall),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Metrics.xSmall),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Metrics.xSmall),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppTheme.Metrics.xSmall),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: AppTheme.Metrics.large),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: AppTheme.Metrics.large),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -AppTheme.Metrics.large),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -AppTheme.Metrics.large),

            socialImageView.topAnchor.constraint(equalTo: socialImageContainer.topAnchor),
            socialImageView.leadingAnchor.constraint(equalTo: socialImageContainer.leadingAnchor),
            socialImageView.trailingAnchor.constraint(equalTo: socialImageContainer.trailingAnchor),
            socialImageView.bottomAnchor.constraint(equalTo: socialImageContainer.bottomAnchor),
            socialImageView.heightAnchor.constraint(equalToConstant: AppTheme.Metrics.storyImageHeight),

            loadingIndicator.centerXAnchor.constraint(equalTo: socialImageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: socialImageView.centerYAnchor)
        ])
    }

    func configure(with story: Story, onCommentsTap: (() -> Void)? = nil) {
        titleLabel.text = story.title
        domainLabel.text = formattedDomain(from: story.url)
        ageLabel.text = formatTime(timestamp: story.time)
        scoreButton.configuration?.title = "\(story.score)"
        commentsButton.configuration?.title = "\(story.descendants) comments"

        let scoreValue = "\(story.score) points"
        let commentsValue = "\(story.descendants) comments"
        cardView.accessibilityLabel = story.title
        cardView.accessibilityValue = "\(scoreValue), \(commentsValue)"
        cardView.accessibilityTraits = .none

        scoreButton.accessibilityLabel = "Upvotes"
        scoreButton.accessibilityValue = scoreValue

        commentsButton.accessibilityLabel = "Comments"
        commentsButton.accessibilityValue = commentsValue

        commentsButton.removeTarget(nil, action: nil, for: .allEvents)
        if let onTap = onCommentsTap {
            commentsButton.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
        }

        if let html = story.topComment?.text {
            topCommentLabel.attributedText = renderHTMLComment(html)
            topCommentLabel.isHidden = false
        } else {
            topCommentLabel.attributedText = nil
            topCommentLabel.text = nil
            topCommentLabel.isHidden = true
        }

        if let url = story.socialImageURL {
            // Reserve the image's slot up front so the cell measures with the
            // 168pt image height baked in. If we wait for the image to load and
            // unhide later, the image's required-priority height constraint
            // compresses the multi-line labels to zero on the next layout pass.
            socialImageContainer.isHidden = false
            socialImageView.isHidden = false
            loadingIndicator.startAnimating()
            loadSocialImage(from: url)
        } else {
            socialImageContainer.isHidden = true
            socialImageView.isHidden = true
            loadingIndicator.stopAnimating()
        }
    }

    func renderHTMLComment(_ html: String) -> NSAttributedString? {
        let decodedText = HTMLTextExtractor.plainText(from: html)

        guard !decodedText.isEmpty else {
            return nil
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = AppTheme.Metrics.small
        paragraph.paragraphSpacing = AppTheme.Metrics.medium
        paragraph.minimumLineHeight = ceil(AppTheme.Typography.storySummaryBody.lineHeight)

        return NSAttributedString(string: decodedText, attributes: [
            .font: AppTheme.Typography.storySummaryBody,
            .paragraphStyle: paragraph,
            .foregroundColor: AppTheme.Colors.secondaryText
        ])
    }

    private func formattedDomain(from urlString: String?) -> String {
        guard let urlString,
              let host = URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: "") else {
            return "news.ycombinator.com"
        }

        return host
    }

    private func formatTime(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func loadSocialImage(from url: URL) {
        imageLoadTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else { return }
                await MainActor.run {
                    self?.socialImageView.image = image
                    self?.loadingIndicator.stopAnimating()
                }
            } catch {
                await MainActor.run {
                    self?.loadingIndicator.stopAnimating()
                }
            }
        }
    }
}
