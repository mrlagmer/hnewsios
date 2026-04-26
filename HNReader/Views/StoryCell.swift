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
    private let metadataRow = UIStackView()
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
        scoreButton.accessibilityTraits = .button
        scoreButton.applyMetaPillStyle()

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

        metadataRow.translatesAutoresizingMaskIntoConstraints = false
        metadataRow.axis = .horizontal
        metadataRow.alignment = .center
        metadataRow.spacing = AppTheme.Metrics.small

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

        let metadataSpacer = UIView()
        metadataSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let commentsSpacer = UIView()
        commentsSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        metaHeaderRow.addArrangedSubview(domainLabel)
        metaHeaderRow.addArrangedSubview(dotLabel)
        metaHeaderRow.addArrangedSubview(ageLabel)
        metaHeaderRow.addArrangedSubview(metaSpacer)

        metadataRow.addArrangedSubview(scoreButton)
        metadataRow.addArrangedSubview(metadataSpacer)

        commentsRow.addArrangedSubview(commentsButton)
        commentsRow.addArrangedSubview(commentsSpacer)

        socialImageContainer.addSubview(socialImageView)
        socialImageContainer.addSubview(loadingIndicator)

        contentStack.addArrangedSubview(metaHeaderRow)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(socialImageContainer)
        contentStack.addArrangedSubview(topCommentLabel)
        contentStack.addArrangedSubview(metadataRow)
        contentStack.setCustomSpacing(4, after: metadataRow)
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
        scoreButton.setTitle("\(story.score) ▲", for: .normal)
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
            socialImageContainer.isHidden = false
            loadSocialImage(from: url)
        } else {
            socialImageContainer.isHidden = true
            socialImageView.isHidden = true
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
        socialImageView.isHidden = false
        loadingIndicator.startAnimating()

        imageLoadTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = UIImage(data: data) else {
                    await MainActor.run {
                        self?.loadingIndicator.stopAnimating()
                        self?.socialImageView.isHidden = true
                    }
                    return
                }

                await MainActor.run {
                    self?.loadingIndicator.stopAnimating()
                    self?.socialImageView.image = image
                    self?.socialImageView.isHidden = false
                }
            } catch {
                await MainActor.run {
                    self?.loadingIndicator.stopAnimating()
                    self?.socialImageView.isHidden = true
                }
            }
        }
    }
}
