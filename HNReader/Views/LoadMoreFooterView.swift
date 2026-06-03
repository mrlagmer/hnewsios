import UIKit

final class LoadMoreFooterView: UICollectionReusableView {
    static let reuseIdentifier = "LoadMoreFooterView"

    var onTap: (() -> Void)?

    private let button = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Load more", for: .normal)
        button.applyMetaPillStyle(emphasized: true)
        button.addTarget(self, action: #selector(didTap), for: .touchUpInside)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = AppTheme.Colors.tint
        spinner.hidesWhenStopped = true

        addSubview(button)
        addSubview(spinner)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.topAnchor.constraint(equalTo: topAnchor, constant: AppTheme.Metrics.medium),
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AppTheme.Metrics.large),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),

            spinner.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    @objc private func didTap() {
        onTap?()
    }

    func apply(isLoading: Bool, hasMore: Bool) {
        isHidden = !hasMore && !isLoading

        if isLoading {
            button.isHidden = true
            button.isEnabled = false
            spinner.startAnimating()
        } else {
            button.isHidden = false
            button.isEnabled = true
            spinner.stopAnimating()
        }
    }
}
