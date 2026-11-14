import UIKit

/// The friendly "nothing here yet" message with a big emoji (and the mascot later).
final class EmptyStateView: UIView {

    var onButtonTap: (() -> Void)?

    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        emojiLabel.font = .systemFont(ofSize: 72)
        emojiLabel.textAlignment = .center
        emojiLabel.isAccessibilityElement = false // decoration only; VoiceOver skips it

        titleLabel.font = Theme.Typography.sectionTitle.font
        titleLabel.textColor = Theme.Colors.ink
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        messageLabel.font = Theme.Typography.body.font
        messageLabel.textColor = Theme.Colors.muted
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.adjustsFontForContentSizeCategory = true

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = Theme.Colors.brand
        config.baseForegroundColor = Theme.Colors.onBrand
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        button.configuration = config
        button.addAction(UIAction { [weak self] _ in self?.onButtonTap?() }, for: .touchUpInside)

        // A vertical stack puts everything in a tidy column, centred on screen.
        let stack = UIStackView(arrangedSubviews: [emojiLabel, titleLabel, messageLabel, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 10
        stack.setCustomSpacing(20, after: messageLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    func configure(emoji: String, title: String, message: String, buttonTitle: String?) {
        emojiLabel.text = emoji
        titleLabel.text = title
        messageLabel.text = message
        button.isHidden = (buttonTitle == nil)
        if let buttonTitle {
            var config = button.configuration
            var attributed = AttributedString(buttonTitle)
            attributed.font = Theme.Typography.button.font
            config?.attributedTitle = attributed
            button.configuration = config
        }
    }
}
