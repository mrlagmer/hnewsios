import UIKit

final class OfflineButton: UIControl {
    enum DisplayState {
        case idle
        case loading
        case done
    }

    private enum Metrics {
        static let buttonSize: CGFloat = 36
        static let strokeWidth: CGFloat = 2.2
        static let radius: CGFloat = 16.9
        static let haloInset: CGFloat = -2
    }

    private let ringContainerLayer = CALayer()
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let haloLayer = CAShapeLayer()
    private let downloadIconLayer = CAShapeLayer()
    private let checkIconLayer = CAShapeLayer()
    private let centerContainer = UIView()
    private let percentStack = UIStackView()
    private let percentValueLabel = UILabel()
    private let percentSymbolLabel = UILabel()

    private(set) var displayState: DisplayState = .idle
    private(set) var progress: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        CGSize(width: Metrics.buttonSize, height: Metrics.buttonSize)
    }

    override var isHighlighted: Bool {
        didSet {
            guard displayState == .idle else { return }
            updateColors()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        apply(state: .idle, progress: 0, animated: false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        apply(state: .idle, progress: 0, animated: false)
    }

    func apply(state: DisplayState, progress: CGFloat, animated: Bool) {
        self.displayState = state
        self.progress = min(max(progress, 0), 100)

        updateColors()
        updateProgress(animated: animated)
        updateCenterContent()
        updateHaloAnimation()
        updateAccessibility()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        centerContainer.frame = bounds
        ringContainerLayer.frame = bounds
        trackLayer.frame = bounds
        progressLayer.frame = bounds

        let circleRect = CGRect(
            x: (bounds.width / 2) - Metrics.radius,
            y: (bounds.height / 2) - Metrics.radius,
            width: Metrics.radius * 2,
            height: Metrics.radius * 2
        )
        let circlePath = UIBezierPath(ovalIn: circleRect).cgPath
        trackLayer.path = circlePath
        progressLayer.path = circlePath

        haloLayer.frame = bounds.insetBy(dx: Metrics.haloInset, dy: Metrics.haloInset)
        haloLayer.path = UIBezierPath(ovalIn: haloLayer.bounds).cgPath

        downloadIconLayer.frame = bounds
        downloadIconLayer.path = downloadIconPath(in: bounds).cgPath

        checkIconLayer.frame = bounds
        checkIconLayer.path = checkIconPath(in: bounds).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }

    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = false
        layer.cornerRadius = Metrics.buttonSize / 2
        layer.cornerCurve = .continuous
        accessibilityTraits = [.button]

        ringContainerLayer.frame = bounds
        ringContainerLayer.transform = CATransform3DMakeRotation(-CGFloat.pi / 2, 0, 0, 1)
        layer.addSublayer(ringContainerLayer)

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.lineWidth = Metrics.strokeWidth
        trackLayer.opacity = 0
        ringContainerLayer.addSublayer(trackLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = Metrics.strokeWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        progressLayer.opacity = 0
        progressLayer.shadowRadius = 4
        progressLayer.shadowOpacity = 1
        progressLayer.shadowOffset = .zero
        ringContainerLayer.addSublayer(progressLayer)

        haloLayer.fillColor = UIColor.clear.cgColor
        haloLayer.lineWidth = 1.5
        haloLayer.opacity = 0
        layer.addSublayer(haloLayer)

        downloadIconLayer.fillColor = UIColor.clear.cgColor
        downloadIconLayer.lineWidth = 1.8
        downloadIconLayer.lineCap = .round
        downloadIconLayer.lineJoin = .round
        layer.addSublayer(downloadIconLayer)

        checkIconLayer.fillColor = UIColor.clear.cgColor
        checkIconLayer.lineWidth = 2.2
        checkIconLayer.lineCap = .round
        checkIconLayer.lineJoin = .round
        checkIconLayer.isHidden = true
        layer.addSublayer(checkIconLayer)

        centerContainer.isUserInteractionEnabled = false
        centerContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerContainer)

        percentStack.axis = .horizontal
        percentStack.alignment = .firstBaseline
        percentStack.spacing = 1
        percentStack.translatesAutoresizingMaskIntoConstraints = false
        percentStack.isHidden = true
        centerContainer.addSubview(percentStack)

        percentValueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold)
        percentValueLabel.textAlignment = .center

        percentSymbolLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 7, weight: .bold)
        percentSymbolLabel.text = "%"
        percentSymbolLabel.alpha = 0.7
        percentSymbolLabel.textAlignment = .left

        percentStack.addArrangedSubview(percentValueLabel)
        percentStack.addArrangedSubview(percentSymbolLabel)

        NSLayoutConstraint.activate([
            centerContainer.topAnchor.constraint(equalTo: topAnchor),
            centerContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            centerContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            centerContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            percentStack.centerXAnchor.constraint(equalTo: centerContainer.centerXAnchor),
            percentStack.centerYAnchor.constraint(equalTo: centerContainer.centerYAnchor)
        ])
    }

    private func updateColors() {
        let trackColor: UIColor
        if traitCollection.userInterfaceStyle == .dark {
            trackColor = UIColor(white: 1, alpha: 0.10)
        } else {
            trackColor = UIColor(red: 22 / 255, green: 21 / 255, blue: 19 / 255, alpha: 0.08)
        }

        let accent = AppTheme.Colors.tint
        let defaultIconColor = isHighlighted ? accent : AppTheme.Colors.primaryText

        trackLayer.strokeColor = trackColor.cgColor
        progressLayer.strokeColor = accent.cgColor
        progressLayer.shadowColor = accent.withAlphaComponent(0.33).cgColor
        haloLayer.strokeColor = accent.cgColor
        downloadIconLayer.strokeColor = (displayState == .idle ? defaultIconColor : UIColor.clear).cgColor
        checkIconLayer.strokeColor = accent.cgColor
        percentValueLabel.textColor = accent
        percentSymbolLabel.textColor = accent
    }

    private func updateCenterContent() {
        switch displayState {
        case .idle:
            downloadIconLayer.isHidden = false
            checkIconLayer.isHidden = true
            percentStack.isHidden = true
        case .loading:
            downloadIconLayer.isHidden = true
            checkIconLayer.isHidden = true
            percentValueLabel.text = "\(Int(progress.rounded()))"
            percentStack.isHidden = false
        case .done:
            downloadIconLayer.isHidden = true
            checkIconLayer.isHidden = false
            percentStack.isHidden = true
        }
    }

    private func updateProgress(animated: Bool) {
        let visibleProgress: CGFloat
        let trackOpacity: Float
        let progressOpacity: Float

        switch displayState {
        case .idle:
            visibleProgress = 0
            trackOpacity = 0
            progressOpacity = 0
        case .loading:
            visibleProgress = progress / 100
            trackOpacity = 1
            progressOpacity = 1
        case .done:
            visibleProgress = 1
            trackOpacity = 0
            progressOpacity = 1
        }

        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(animated ? 0.18 : 0)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        trackLayer.opacity = trackOpacity
        progressLayer.opacity = progressOpacity
        progressLayer.strokeEnd = visibleProgress
        CATransaction.commit()
    }

    private func updateHaloAnimation() {
        let animationKey = "offlinePulse"

        guard displayState == .loading else {
            haloLayer.opacity = 0
            haloLayer.removeAnimation(forKey: animationKey)
            return
        }

        haloLayer.opacity = 0.5
        guard haloLayer.animation(forKey: animationKey) == nil else { return }

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.92, 1.18, 1.18]
        scale.keyTimes = [0, 0.7, 1]

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.5, 0, 0]
        opacity.keyTimes = [0, 0.7, 1]

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 1.6
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        haloLayer.add(group, forKey: animationKey)
    }

    private func updateAccessibility() {
        switch displayState {
        case .idle:
            accessibilityLabel = "Download for offline"
        case .loading:
            accessibilityLabel = "Downloading \(Int(progress.rounded())) percent"
        case .done:
            accessibilityLabel = "Available offline"
        }
    }

    private func downloadIconPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let centerX = rect.midX
        path.move(to: CGPoint(x: centerX, y: 9))
        path.addLine(to: CGPoint(x: centerX, y: 18))
        path.move(to: CGPoint(x: centerX - 4, y: 14.5))
        path.addLine(to: CGPoint(x: centerX, y: 18.5))
        path.addLine(to: CGPoint(x: centerX + 4, y: 14.5))
        path.move(to: CGPoint(x: centerX - 6, y: 22))
        path.addLine(to: CGPoint(x: centerX + 6, y: 22))
        return path
    }

    private func checkIconPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: CGPoint(x: center.x - 4, y: center.y + 0.5))
        path.addLine(to: CGPoint(x: center.x - 1, y: center.y + 3.5))
        path.addLine(to: CGPoint(x: center.x + 4, y: center.y - 3))
        return path
    }
}