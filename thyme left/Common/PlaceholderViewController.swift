import UIKit

/// A temporary "coming soon" screen so every tab has something to show.
/// (Translation: a stand-in. Each real screen replaces one of these as we build it.)
final class PlaceholderViewController: UIViewController {

    private let screenTitle: String
    private let message: String

    init(title: String, message: String) {
        self.screenTitle = title
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background

        let titleLabel = UILabel()
        titleLabel.text = screenTitle
        titleLabel.font = Theme.Typography.screenTitle.font
        titleLabel.textColor = Theme.Colors.ink
        titleLabel.adjustsFontForContentSizeCategory = true

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = Theme.Typography.body.font
        messageLabel.textColor = Theme.Colors.muted
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.adjustsFontForContentSizeCategory = true

        // A vertical stack = labels placed one under the other, centred on screen.
        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }
}
