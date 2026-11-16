import UIKit

/// A sideways-scrolling row of pill buttons: All | Fridge | Pantry | Freezer | Counter.
final class FilterChipBar: UIView {

    /// Called with the position of the chip the user tapped.
    var onSelect: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            // Make the row at least as tall as the bar, so it never wobbles up and down.
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -12),
            // At big text sizes the chips get taller, and the bar must grow with them.
            heightAnchor.constraint(greaterThanOrEqualTo: stack.heightAnchor, constant: 12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    /// Rebuilds the chips. The chip at `selectedIndex` is shown in green.
    func update(titles: [String], selectedIndex: Int) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, title) in titles.enumerated() {
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            var attributed = AttributedString(title)
            attributed.font = Theme.Typography.chip.font
            config.attributedTitle = attributed

            let button = UIButton(configuration: config)
            button.isSelected = (index == selectedIndex) // VoiceOver reads this as "selected"
            // Re-colour automatically whenever the button's selected state changes.
            button.configurationUpdateHandler = { button in
                var updated = button.configuration
                updated?.baseBackgroundColor = button.isSelected ? Theme.Colors.brand : Theme.Colors.chip
                updated?.baseForegroundColor = button.isSelected ? Theme.Colors.onBrand : Theme.Colors.ink
                button.configuration = updated
            }
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(index) }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }
}
