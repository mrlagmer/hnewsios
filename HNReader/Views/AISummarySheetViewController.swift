//
//  AISummarySheetViewController.swift
//  HNReader
//

import UIKit

@MainActor
final class AISummarySheetViewController: UIViewController {

    private enum DisplayState {
        case loading
        case ready(AISummary)
        case error(String)
    }

    private let story: Story
    private var displayState: DisplayState = .loading
    private var loadTask: Task<Void, Never>?

    private let backdropView = UIView()
    private let sheetView = UIView()
    private let dragHandleView = UIView()
    private let headerStack = UIStackView()
    private let sparkleBadgeView = UIView()
    private let sparkleImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let bodyScrollView = UIScrollView()
    private let bodyStack = UIStackView()
    private let skeletonView = AISummarySkeletonView()

    private var sheetBottomConstraint: NSLayoutConstraint!

    init(story: Story) {
        self.story = story
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        setupBackdrop()
        setupSheet()
        applyDisplayState(animated: false)

        loadTask = Task { @MainActor [weak self] in
            await self?.runGeneration()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateSheetIn()
    }

    private func setupBackdrop() {
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.backgroundColor = UIColor.black.withAlphaComponent(0)
        backdropView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissTapped)))
        view.addSubview(backdropView)

        NSLayoutConstraint.activate([
            backdropView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupSheet() {
        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.backgroundColor = AppTheme.Colors.surface
        sheetView.layer.cornerRadius = 20
        sheetView.layer.cornerCurve = .continuous
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetView.clipsToBounds = true
        sheetView.layer.shadowColor = UIColor.black.cgColor
        sheetView.layer.shadowOpacity = 0.18
        sheetView.layer.shadowRadius = 40
        sheetView.layer.shadowOffset = CGSize(width: 0, height: -12)
        sheetView.layer.masksToBounds = false
        view.addSubview(sheetView)

        dragHandleView.translatesAutoresizingMaskIntoConstraints = false
        dragHandleView.backgroundColor = AppTheme.Colors.border
        dragHandleView.layer.cornerRadius = 2
        sheetView.addSubview(dragHandleView)

        let headerSeparator = UIView()
        headerSeparator.translatesAutoresizingMaskIntoConstraints = false
        headerSeparator.backgroundColor = AppTheme.Colors.border

        sparkleBadgeView.translatesAutoresizingMaskIntoConstraints = false
        sparkleBadgeView.backgroundColor = AppTheme.Colors.accentSoft
        sparkleBadgeView.layer.cornerRadius = 8
        sparkleBadgeView.layer.cornerCurve = .continuous

        sparkleImageView.translatesAutoresizingMaskIntoConstraints = false
        sparkleImageView.image = UIImage(
            systemName: "sparkles",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        )
        sparkleImageView.tintColor = AppTheme.Colors.tint
        sparkleImageView.contentMode = .scaleAspectFit
        sparkleBadgeView.addSubview(sparkleImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "AI summary"
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = AppTheme.Colors.primaryText

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
        subtitleLabel.textColor = AppTheme.Colors.secondaryText

        let titleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .vertical
        titleStack.spacing = 1

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        var closeConfig = UIButton.Configuration.plain()
        closeConfig.image = UIImage(
            systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        )
        closeConfig.background.backgroundColor = AppTheme.Colors.surfaceAlt
        closeConfig.background.cornerRadius = 15
        closeConfig.baseForegroundColor = AppTheme.Colors.secondaryText
        closeConfig.contentInsets = .zero
        closeButton.configuration = closeConfig
        closeButton.accessibilityLabel = "Close"
        closeButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        let headerSpacer = UIView()
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 10
        headerStack.addArrangedSubview(sparkleBadgeView)
        headerStack.addArrangedSubview(titleStack)
        headerStack.addArrangedSubview(headerSpacer)
        headerStack.addArrangedSubview(closeButton)
        sheetView.addSubview(headerStack)
        sheetView.addSubview(headerSeparator)

        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false
        bodyScrollView.alwaysBounceVertical = true
        bodyScrollView.showsVerticalScrollIndicator = false
        sheetView.addSubview(bodyScrollView)

        bodyStack.translatesAutoresizingMaskIntoConstraints = false
        bodyStack.axis = .vertical
        bodyStack.spacing = 18
        bodyScrollView.addSubview(bodyStack)

        skeletonView.translatesAutoresizingMaskIntoConstraints = false

        sheetBottomConstraint = sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)

        let isRegularWidth = traitCollection.horizontalSizeClass == .regular
        let sheetWidth: NSLayoutConstraint = isRegularWidth
            ? sheetView.widthAnchor.constraint(equalToConstant: 520)
            : sheetView.widthAnchor.constraint(equalTo: view.widthAnchor)

        let bodyWantsContentHeight = bodyScrollView.heightAnchor.constraint(
            equalTo: bodyScrollView.contentLayoutGuide.heightAnchor
        )
        bodyWantsContentHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            sheetView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sheetWidth,
            sheetView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.82),
            sheetBottomConstraint,

            bodyWantsContentHeight,

            dragHandleView.topAnchor.constraint(equalTo: sheetView.topAnchor, constant: 8),
            dragHandleView.centerXAnchor.constraint(equalTo: sheetView.centerXAnchor),
            dragHandleView.widthAnchor.constraint(equalToConstant: 36),
            dragHandleView.heightAnchor.constraint(equalToConstant: 4),

            sparkleBadgeView.widthAnchor.constraint(equalToConstant: 28),
            sparkleBadgeView.heightAnchor.constraint(equalToConstant: 28),
            sparkleImageView.centerXAnchor.constraint(equalTo: sparkleBadgeView.centerXAnchor),
            sparkleImageView.centerYAnchor.constraint(equalTo: sparkleBadgeView.centerYAnchor),

            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            headerStack.topAnchor.constraint(equalTo: dragHandleView.bottomAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor, constant: -16),

            headerSeparator.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            headerSeparator.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            headerSeparator.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            headerSeparator.heightAnchor.constraint(equalToConstant: 1),

            bodyScrollView.topAnchor.constraint(equalTo: headerSeparator.bottomAnchor),
            bodyScrollView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            bodyScrollView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            bodyScrollView.bottomAnchor.constraint(equalTo: sheetView.safeAreaLayoutGuide.bottomAnchor),

            bodyStack.topAnchor.constraint(equalTo: bodyScrollView.topAnchor, constant: 16),
            bodyStack.leadingAnchor.constraint(equalTo: bodyScrollView.leadingAnchor, constant: 16),
            bodyStack.trailingAnchor.constraint(equalTo: bodyScrollView.trailingAnchor, constant: -16),
            bodyStack.bottomAnchor.constraint(equalTo: bodyScrollView.bottomAnchor, constant: -28),
            bodyStack.widthAnchor.constraint(equalTo: bodyScrollView.widthAnchor, constant: -32)
        ])

        sheetView.layoutIfNeeded()
        sheetBottomConstraint.constant = sheetView.bounds.height
        view.layoutIfNeeded()
    }

    private func animateSheetIn() {
        sheetBottomConstraint.constant = 0
        UIView.animate(
            withDuration: 0.36,
            delay: 0,
            usingSpringWithDamping: 0.92,
            initialSpringVelocity: 0,
            options: [.curveEaseOut]
        ) {
            self.backdropView.backgroundColor = UIColor.black.withAlphaComponent(0.32)
            self.view.layoutIfNeeded()
        }
    }

    private func animateSheetOut(then completion: @escaping () -> Void) {
        sheetBottomConstraint.constant = sheetView.bounds.height
        UIView.animate(withDuration: 0.26, delay: 0, options: [.curveEaseIn]) {
            self.backdropView.backgroundColor = UIColor.black.withAlphaComponent(0)
            self.view.layoutIfNeeded()
        } completion: { _ in
            completion()
        }
    }

    @objc private func dismissTapped() {
        loadTask?.cancel()
        animateSheetOut { [weak self] in
            self?.dismiss(animated: false)
        }
    }

    private func runGeneration() async {
        do {
            let summary = try await AISummaryService.shared.summarise(story: story)
            guard !Task.isCancelled else { return }
            displayState = .ready(summary)
            applyDisplayState(animated: true)
        } catch {
            guard !Task.isCancelled else { return }
            displayState = .error(error.localizedDescription)
            applyDisplayState(animated: true)
        }
    }

    private func applyDisplayState(animated: Bool) {
        bodyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch displayState {
        case .loading:
            subtitleLabel.text = "Reading the article…"
            bodyStack.addArrangedSubview(skeletonView)
            skeletonView.startShimmer()

        case .ready(let summary):
            skeletonView.stopShimmer()
            subtitleLabel.text = readySubtitle
            populate(with: summary)
            if animated {
                bodyStack.alpha = 0
                bodyStack.transform = CGAffineTransform(translationX: 0, y: 6)
                UIView.animate(withDuration: 0.24) {
                    self.bodyStack.alpha = 1
                    self.bodyStack.transform = .identity
                }
            }

        case .error(let message):
            skeletonView.stopShimmer()
            subtitleLabel.text = "Couldn’t generate a summary"
            bodyStack.addArrangedSubview(makeErrorView(message: message))
        }
    }

    private var readySubtitle: String {
        if let urlString = story.url,
           let host = URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: ""),
           !host.isEmpty {
            return "Summarised from \(host)"
        }
        return "Summarised from the post"
    }

    private func populate(with summary: AISummary) {
        bodyStack.addArrangedSubview(makeSection(label: "TL;DR", body: makeTLDR(text: summary.tldr)))

        let pointsStack = UIStackView()
        pointsStack.axis = .vertical
        pointsStack.spacing = 10
        pointsStack.translatesAutoresizingMaskIntoConstraints = false
        for point in summary.keyPoints {
            pointsStack.addArrangedSubview(makeKeyPointRow(text: point))
        }
        bodyStack.addArrangedSubview(makeSection(label: "Key points", body: pointsStack))

        bodyStack.addArrangedSubview(makeDisclaimer())
    }

    private func makeSection(label: String, body: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let labelView = UILabel()
        labelView.translatesAutoresizingMaskIntoConstraints = false
        labelView.attributedText = NSAttributedString(
            string: label.uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: AppTheme.Colors.tertiaryText,
                .kern: 1.0
            ]
        )

        body.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(labelView)
        container.addSubview(body)

        NSLayoutConstraint.activate([
            labelView.topAnchor.constraint(equalTo: container.topAnchor),
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),

            body.topAnchor.constraint(equalTo: labelView.bottomAnchor, constant: 8),
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func makeTLDR(text: String) -> UIView {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textColor = AppTheme.Colors.primaryText
        label.text = text

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: AppTheme.Colors.primaryText,
                .paragraphStyle: paragraph
            ]
        )
        return label
    }

    private func makeKeyPointRow(text: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = AppTheme.Colors.tint
        dot.layer.cornerRadius = 3

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14.5, weight: .regular),
                .foregroundColor: AppTheme.Colors.primaryText,
                .paragraphStyle: paragraph
            ]
        )

        container.addSubview(dot)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            // Nudge the dot down so it sits on the first text line.
            dot.topAnchor.constraint(equalTo: container.topAnchor, constant: 7),
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),

            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func makeDisclaimer() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = AppTheme.Colors.border

        let iconView = UIImageView(image: UIImage(systemName: "sparkles", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = AppTheme.Colors.tertiaryText
        iconView.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "AI-generated on-device from the article text. Summaries can miss nuance — open the story to read it in full."
        label.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        label.textColor = AppTheme.Colors.tertiaryText
        label.numberOfLines = 0

        container.addSubview(separator)
        container.addSubview(iconView)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: container.topAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1),

            iconView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),

            label.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func makeErrorView(message: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(
            systemName: "exclamationmark.bubble",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        ))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = AppTheme.Colors.tint
        icon.contentMode = .scaleAspectFit

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = AppTheme.Colors.primaryText
        label.numberOfLines = 0
        label.textAlignment = .center

        container.addSubview(icon)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        return container
    }
}

// MARK: - Shimmer skeleton

final class AISummarySkeletonView: UIView {
    private var bars: [CAGradientLayer] = []
    private var isShimmering = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startShimmer() {
        guard !isShimmering else { return }
        isShimmering = true
        for bar in bars {
            let animation = CABasicAnimation(keyPath: "locations")
            animation.fromValue = [-1.0, -0.5, 0.0]
            animation.toValue = [1.0, 1.5, 2.0]
            animation.duration = 1.2
            animation.repeatCount = .infinity
            bar.add(animation, forKey: "shimmer")
        }
    }

    func stopShimmer() {
        isShimmering = false
        for bar in bars {
            bar.removeAnimation(forKey: "shimmer")
        }
    }

    private func build() {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 20

        let tldr = makeGroup(widths: ["96%", "88%", "62%"], headerWidth: 60)
        let keyPoints = makeKeyPointsGroup()

        stack.addArrangedSubview(tldr)
        stack.addArrangedSubview(keyPoints)

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func makeGroup(widths: [String], headerWidth: CGFloat, barHeight: CGFloat = 12, rounded: Bool = false) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let header = makeBar(height: 9, rounded: false)
        container.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.widthAnchor.constraint(equalToConstant: headerWidth)
        ])

        var lastBar: UIView = header
        for (idx, w) in widths.enumerated() {
            let bar = makeBar(height: barHeight, rounded: rounded)
            container.addSubview(bar)
            let multiplier = percentageMultiplier(w)
            NSLayoutConstraint.activate([
                bar.topAnchor.constraint(equalTo: lastBar.bottomAnchor, constant: idx == 0 ? 12 : 8),
                bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                bar.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: multiplier)
            ])
            lastBar = bar
        }

        lastBar.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        return container
    }

    private func makeKeyPointsGroup() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let header = makeBar(height: 9, rounded: false)
        container.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.widthAnchor.constraint(equalToConstant: 80)
        ])

        let widths: [CGFloat] = [0.9, 0.74, 0.84, 0.6]
        var prevBottom = header.bottomAnchor
        var firstTop = true
        for width in widths {
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(row)

            let dot = makeBar(height: 6, rounded: true)
            let line = makeBar(height: 12, rounded: false)

            row.addSubview(dot)
            row.addSubview(line)

            NSLayoutConstraint.activate([
                dot.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
                dot.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 2),
                dot.widthAnchor.constraint(equalToConstant: 6),

                line.topAnchor.constraint(equalTo: row.topAnchor),
                line.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
                line.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: width),
                line.bottomAnchor.constraint(equalTo: row.bottomAnchor),

                row.topAnchor.constraint(equalTo: prevBottom, constant: firstTop ? 14 : 12),
                row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
            prevBottom = row.bottomAnchor
            firstTop = false
        }

        prevBottom.constraint(equalTo: container.bottomAnchor).isActive = true
        return container
    }

    private func makeBar(height: CGFloat, rounded: Bool) -> UIView {
        let container = ShimmerBarView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = rounded ? height / 2 : 4
        container.clipsToBounds = true
        container.backgroundColor = AppTheme.Colors.surfaceAlt
        container.heightAnchor.constraint(equalToConstant: height).isActive = true

        let gradient = container.shimmerLayer
        gradient.colors = [
            AppTheme.Colors.surfaceAlt.cgColor,
            AppTheme.Colors.border.cgColor,
            AppTheme.Colors.surfaceAlt.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.locations = [0.0, 0.5, 1.0]
        bars.append(gradient)
        return container
    }

    private func percentageMultiplier(_ raw: String) -> CGFloat {
        let value = raw.replacingOccurrences(of: "%", with: "")
        if let percent = Double(value) {
            return CGFloat(percent / 100.0)
        }
        return 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for layer in bars {
            if let host = layer.superlayer {
                layer.frame = host.bounds
            }
        }
    }
}

final class ShimmerBarView: UIView {
    let shimmerLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(shimmerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = bounds
    }
}
