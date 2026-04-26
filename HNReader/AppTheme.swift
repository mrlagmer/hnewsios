import UIKit

enum AppTheme {
    enum Colors {
        static let tint = UIColor(hex: 0xF58220)
        static let background = UIColor(hex: 0xFAF9F7)
        static let surface = UIColor.white
        static let elevatedSurface = UIColor.white
        static let surfaceAlt = UIColor(hex: 0xF4F2EE)
        static let border = UIColor(red: 22.0 / 255.0, green: 21.0 / 255.0, blue: 19.0 / 255.0, alpha: 0.08)
        static let rail = UIColor(red: 22.0 / 255.0, green: 21.0 / 255.0, blue: 19.0 / 255.0, alpha: 0.10)
        static let accentSoft = UIColor(red: 245.0 / 255.0, green: 130.0 / 255.0, blue: 32.0 / 255.0, alpha: 0.10)
        static let secondaryText = UIColor(red: 22.0 / 255.0, green: 21.0 / 255.0, blue: 19.0 / 255.0, alpha: 0.55)
        static let tertiaryText = UIColor(red: 22.0 / 255.0, green: 21.0 / 255.0, blue: 19.0 / 255.0, alpha: 0.40)
        static let primaryText = UIColor(hex: 0x161513)

        static func commentTint(for depth: Int) -> UIColor {
            switch min(depth, 4) {
            case 0:
                return surface
            case 1:
                return UIColor(red: 22.0 / 255.0, green: 21.0 / 255.0, blue: 19.0 / 255.0, alpha: 0.018)
            case 2:
                return UIColor(red: 22.0 / 255.0, green: 21.0 / 255.0, blue: 19.0 / 255.0, alpha: 0.035)
            case 3:
                return UIColor(red: 22.0 / 255.0, green: 21.0 / 255.0, blue: 19.0 / 255.0, alpha: 0.052)
            default:
                return UIColor(red: 22.0 / 255.0, green: 21.0 / 255.0, blue: 19.0 / 255.0, alpha: 0.068)
            }
        }
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
        static let screenTopInset: CGFloat = 54
        static let commentMaxDepth: CGFloat = 4
    }

    enum Typography {
        static let navigationTitle = scaledFont(forTextStyle: .headline, weight: .semibold)
        static let largeNavigationTitle = scaledFont(forTextStyle: .largeTitle, weight: .bold)
        static let cardTitle = scaledFont(forTextStyle: .title3, weight: .semibold)
        static let commentPreview = scaledFont(forTextStyle: .body, weight: .regular)
        static let metadata = scaledFont(forTextStyle: .subheadline, weight: .medium)
        static let detail = scaledFont(forTextStyle: .caption1, weight: .medium)
        static let feedHeader = customFont(size: 30, weight: .bold)
        static let storyHeadline = customFont(size: 22, weight: .bold)
        static let storySummaryBody = customFont(size: 14, weight: .regular)
        static let commentBody = customFont(size: 15, weight: .regular)
        static let commentMeta = customFont(size: 13, weight: .semibold)
        static let commentMetaDetail = customFont(size: 12, weight: .medium)
        static let compactMeta = customFont(size: 12, weight: .medium)
        static let compactButton = customFont(size: 15, weight: .semibold)

        private static func scaledFont(forTextStyle textStyle: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
            let baseSize = UIFont.preferredFont(forTextStyle: textStyle).pointSize
            let baseFont = UIFont.systemFont(ofSize: baseSize, weight: weight)
            return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont)
        }

        private static func customFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
            let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
            return UIFontMetrics.default.scaledFont(for: baseFont)
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
        backgroundColor = emphasized ? AppTheme.Colors.accentSoft : .clear
        tintColor = emphasized ? AppTheme.Colors.tint : AppTheme.Colors.secondaryText
        setTitleColor(tintColor, for: .normal)
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}