//
//  StoryCell.swift
//  HNReader
//

import UIKit

final class StoryCell: UICollectionViewCell {
    static let reuseIdentifier = "StoryCell"

    private let cardView = UIView()
    private let contentStack = UIStackView()
    private let socialImageContainer = UIView()
    private let metadataRow = UIStackView()
    let titleLabel = UILabel()
    let socialImageView = UIImageView()
    let topCommentLabel = UILabel()
    let scoreButton = UIButton(type: .system)
    let commentsButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    private var imageLoadTask: Task<Void, Never>?
    private var textRenderTask: Task<Void, Never>?

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
        topCommentLabel.attributedText = nil
        socialImageView.image = nil
        socialImageContainer.isHidden = true
        socialImageView.isHidden = false
        topCommentLabel.isHidden = true
        loadingIndicator.stopAnimating()
        imageLoadTask?.cancel()
        imageLoadTask = nil
        textRenderTask?.cancel()
        textRenderTask = nil
    }

    private func setupViews() {
        contentView.backgroundColor = .clear
        contentView.addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = AppTheme.Colors.elevatedSurface
        cardView.layer.cornerRadius = AppTheme.Metrics.cardCornerRadius
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = AppTheme.Colors.border.cgColor
        cardView.clipsToBounds = true
        cardView.isAccessibilityElement = true
        cardView.accessibilityTraits = .none

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = AppTheme.Metrics.medium

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 3
        titleLabel.font = AppTheme.Typography.cardTitle
        titleLabel.adjustsFontForContentSizeCategory = true

        socialImageContainer.translatesAutoresizingMaskIntoConstraints = false
        socialImageContainer.backgroundColor = AppTheme.Colors.surface
        socialImageContainer.layer.cornerRadius = AppTheme.Metrics.controlCornerRadius
        socialImageContainer.layer.cornerCurve = .continuous
        socialImageContainer.clipsToBounds = true
        socialImageContainer.isHidden = true

        socialImageView.translatesAutoresizingMaskIntoConstraints = false
        socialImageView.contentMode = .scaleAspectFill
        socialImageView.clipsToBounds = true
        socialImageView.accessibilityLabel = "Story preview image"

        topCommentLabel.translatesAutoresizingMaskIntoConstraints = false
        topCommentLabel.numberOfLines = 3
        topCommentLabel.font = AppTheme.Typography.commentPreview
        topCommentLabel.adjustsFontForContentSizeCategory = true
        topCommentLabel.textColor = AppTheme.Colors.secondaryText
        topCommentLabel.accessibilityLabel = "Top comment"
        topCommentLabel.isHidden = true

        scoreButton.translatesAutoresizingMaskIntoConstraints = false
        scoreButton.accessibilityTraits = .button
        scoreButton.applyMetaPillStyle()
        
        commentsButton.translatesAutoresizingMaskIntoConstraints = false
        commentsButton.accessibilityTraits = .button
        commentsButton.applyMetaPillStyle(emphasized: true)

        metadataRow.translatesAutoresizingMaskIntoConstraints = false
        metadataRow.axis = .horizontal
        metadataRow.alignment = .center
        metadataRow.spacing = AppTheme.Metrics.small

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.accessibilityLabel = "Loading preview image"
        loadingIndicator.color = AppTheme.Colors.tint

        let metadataSpacer = UIView()
        metadataSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        metadataRow.addArrangedSubview(scoreButton)
        metadataRow.addArrangedSubview(metadataSpacer)
        metadataRow.addArrangedSubview(commentsButton)

        socialImageContainer.addSubview(socialImageView)
        socialImageContainer.addSubview(loadingIndicator)

        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(socialImageContainer)
        contentStack.addArrangedSubview(topCommentLabel)
        contentStack.addArrangedSubview(metadataRow)

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
        scoreButton.setTitle("\(story.score) ▲", for: .normal)
        commentsButton.setTitle("\(story.descendants) comments", for: .normal)

        // Set accessibility labels for the card
        let scoreValue = "\(story.score) points"
        let commentsValue = "\(story.descendants) comments"
        cardView.accessibilityLabel = story.title
        cardView.accessibilityValue = "\(scoreValue), \(commentsValue)"
        cardView.accessibilityTraits = .none
        
        // Set accessibility properties for buttons
        scoreButton.accessibilityLabel = "Upvotes"
        scoreButton.accessibilityValue = scoreValue
        
        commentsButton.accessibilityLabel = "Comments"
        commentsButton.accessibilityValue = commentsValue

        commentsButton.removeTarget(nil, action: nil, for: .allEvents)
        if let onTap = onCommentsTap {
            commentsButton.addAction(UIAction { _ in onTap() }, for: .touchUpInside)
        }

        if let html = story.topComment?.text {
            topCommentLabel.attributedText = nil
            topCommentLabel.isHidden = false
            textRenderTask = Task { @MainActor [weak self] in
                guard !Task.isCancelled else { return }
                let attributed = self?.renderHTMLComment(html)
                guard !Task.isCancelled else { return }
                self?.topCommentLabel.attributedText = attributed
            }
        } else {
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
            .foregroundColor: AppTheme.Colors.secondaryText
        ], range: fullRange)

        // Ensure links are tappable via attributes (UIKit will handle link attributes in UITextView)
        return attr
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
