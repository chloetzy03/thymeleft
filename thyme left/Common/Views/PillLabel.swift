import UIKit

/// A label with padding and fully rounded ends, like "3 days" on its coloured badge.
final class PillLabel: UILabel {

    private let insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = Theme.Typography.pill.font
        adjustsFontForContentSizeCategory = true
        textAlignment = .center
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    /// Colours the pill to match an expiry status.
    func configure(text: String, status: ExpiryStatus) {
        self.text = text
        backgroundColor = status.badgeBackgroundColor
        textColor = status.badgeTextColor
    }

    // Draw the text a little away from the edges (this is the padding).
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    // Tell Auto Layout the label is bigger than its text, to make room for the padding.
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}
