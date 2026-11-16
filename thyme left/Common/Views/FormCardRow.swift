import UIKit

/// A white rounded row for forms: a label on the left and a control (stepper, menu, date) on the right.
final class FormCardRow: UIView {

    init(title: String, control: UIView) {
        super.init(frame: .zero)
        backgroundColor = Theme.Colors.card
        layer.cornerRadius = 16

        let label = UILabel()
        label.text = title
        label.font = Theme.Typography.body.font
        label.textColor = Theme.Colors.ink
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0

        // The label stretches; the control keeps its natural size on the right.
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        // With the biggest text sizes there isn't room side by side, so stack the label above the control.
        let arrange = { (row: UIStackView, category: UIContentSizeCategory) in
            let big = category.isAccessibilityCategory
            row.axis = big ? .vertical : .horizontal
            row.alignment = big ? .leading : .center
        }
        arrange(row, traitCollection.preferredContentSizeCategory)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            arrange(row, self.traitCollection.preferredContentSizeCategory)
        }
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }
}
