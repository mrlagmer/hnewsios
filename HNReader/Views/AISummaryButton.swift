//
//  AISummaryButton.swift
//  HNReader
//

import UIKit

final class AISummaryButton: UIButton {

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityLabel = "AI summary"
        accessibilityHint = "Summarise the comments using Apple Intelligence."

        var config = UIButton.Configuration.plain()
        config.title = "AI summary"
        config.image = UIImage(
            systemName: "sparkles",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        config.imagePlacement = .leading
        config.imagePadding = 6
        config.baseForegroundColor = AppTheme.Colors.tint
        config.background.backgroundColor = AppTheme.Colors.accentSoft
        config.background.cornerRadius = 999
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
            return outgoing
        }
        configuration = config

        configurationUpdateHandler = { button in
            guard var updated = button.configuration else { return }
            let highlighted = button.isHighlighted
            updated.background.backgroundColor = highlighted ? AppTheme.Colors.tint : AppTheme.Colors.accentSoft
            updated.baseForegroundColor = highlighted ? .white : AppTheme.Colors.tint
            button.configuration = updated
        }
    }
}
