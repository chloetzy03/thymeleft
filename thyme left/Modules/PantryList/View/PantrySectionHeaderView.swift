import UIKit

/// The small grey heading above a group of rows, e.g. "USE SOON".
final class PantrySectionHeaderView: UITableViewHeaderFooterView {

    static let reuseIdentifier = "PantrySectionHeaderView"

    private let label = UILabel()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        label.font = Theme.Typography.caption.font.withWeight(.semibold)
        label.textColor = Theme.Colors.muted
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header // lets VoiceOver users jump between sections
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    func configure(title: String) {
        label.text = title
    }
}

private extension UIFont {
    /// The same font, but in a different boldness.
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
