import UIKit

enum AppTheme {
    enum Colors {
        static let tint = UIColor.systemOrange
        static let background = UIColor.systemGroupedBackground
        static let surface = UIColor.secondarySystemBackground
        static let elevatedSurface = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.tertiarySystemBackground : UIColor.systemBackground
        }
        static let border = UIColor.separator.withAlphaComponent(0.16)
        static let rail = UIColor.tertiaryLabel.withAlphaComponent(0.18)
        static let secondaryText = UIColor.secondaryLabel
        static let tertiaryText = UIColor.tertiaryLabel
    }

    enum Metrics {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 20

        static let cardCornerRadius: CGFloat = 16
        static let controlCornerRadius: CGFloat = 12
        static let storyImageHeight: CGFloat = 168
        static let commentRailMinWidth: CGFloat = 4
        static let commentIndentStep: CGFloat = 14
        static let commentIndentMaxWidth: CGFloat = 72
    }

    enum Typography {
        static let navigationTitle = scaledFont(forTextStyle: .headline, weight: .semibold)
        static let largeNavigationTitle = scaledFont(forTextStyle: .largeTitle, weight: .bold)
        static let cardTitle = scaledFont(forTextStyle: .title3, weight: .semibold)
        static let commentPreview = scaledFont(forTextStyle: .body, weight: .regular)
        static let metadata = scaledFont(forTextStyle: .subheadline, weight: .medium)
        static let detail = scaledFont(forTextStyle: .caption1, weight: .medium)

        private static func scaledFont(forTextStyle textStyle: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let baseSize = UIFont.preferredFont(forTextStyle: textStyle).pointSize
            let baseFont = UIFont.systemFont(ofSize: baseSize, weight: weight)
            return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont)
        }
    }
}

extension UIButton {
    func applyMetaPillStyle(emphasized: Bool = false) {
        titleLabel?.font = AppTheme.Typography.metadata
        titleLabel?.adjustsFontForContentSizeCategory = true
        contentEdgeInsets = UIEdgeInsets(
            top: AppTheme.Metrics.small,
            left: AppTheme.Metrics.medium,
            bottom: AppTheme.Metrics.small,
            right: AppTheme.Metrics.medium
        )
        layer.cornerRadius = AppTheme.Metrics.controlCornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = emphasized ? 0 : 1
        layer.borderColor = emphasized ? UIColor.clear.cgColor : AppTheme.Colors.border.cgColor
        backgroundColor = emphasized ? AppTheme.Colors.surface : .clear
        tintColor = emphasized ? AppTheme.Colors.tint : AppTheme.Colors.secondaryText
        setTitleColor(tintColor, for: .normal)
    }
}