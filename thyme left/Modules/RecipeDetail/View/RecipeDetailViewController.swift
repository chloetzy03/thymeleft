import UIKit

/// The waiter of the Recipe detail screen.
final class RecipeDetailViewController: UIViewController, RecipeDetailViewProtocol {

    var presenter: RecipeDetailPresenterProtocol?
    private let imageLoader: RemoteImageLoading

    private let column = UIStackView()
    private let heroView = UIImageView()

    init(imageLoader: RemoteImageLoading) {
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        navigationItem.largeTitleDisplayMode = .never
        buildLayout()
        presenter?.viewDidLoad()
    }

    // MARK: RecipeDetailViewProtocol

    func showRecipe(_ detail: RecipeDetailViewModel) {
        title = detail.title
        column.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let url = detail.imageURL {
            column.addArrangedSubview(heroView)
            Task { [weak self] in
                if let image = await self?.imageLoader.image(for: url) { self?.heroView.image = image }
            }
        }

        column.addArrangedSubview(label(detail.title, font: Theme.Typography.screenTitle.font, header: true))
        if let subtitle = detail.subtitle { column.addArrangedSubview(label(subtitle, font: Theme.Typography.body.font, color: Theme.Colors.muted)) }
        column.addArrangedSubview(pill(detail.haveSummary))

        column.addArrangedSubview(label("Ingredients", font: Theme.Typography.sectionTitle.font, header: true))
        for ingredient in detail.ingredients { column.addArrangedSubview(ingredientRow(ingredient)) }

        column.addArrangedSubview(label("Steps", font: Theme.Typography.sectionTitle.font, header: true))
        for (index, step) in detail.steps.enumerated() {
            column.addArrangedSubview(label("\(index + 1). \(step)", font: Theme.Typography.body.font))
        }

        if let title = detail.sourceButtonTitle {
            column.addArrangedSubview(button(title, filled: true) { [weak self] in self?.presenter?.didTapSource() })
        }
        if let title = detail.videoButtonTitle {
            column.addArrangedSubview(button(title, filled: false) { [weak self] in self?.presenter?.didTapVideo() })
        }
        column.addArrangedSubview(label("Recipe data from TheMealDB (themealdb.com)",
                                        font: Theme.Typography.caption.font, color: Theme.Colors.muted))
    }

    // MARK: Building blocks

    private func label(_ text: String, font: UIFont, color: UIColor = Theme.Colors.ink, header: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        if header { label.accessibilityTraits = .header }
        return label
    }

    private func pill(_ text: String) -> UIView {
        let label = PaddedLabel(insets: UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14))
        label.text = text
        label.font = Theme.Typography.body.font
        label.textColor = Theme.Colors.freshText
        label.backgroundColor = Theme.Colors.freshBackground
        label.layer.cornerRadius = 14
        label.clipsToBounds = true
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        let wrapper = UIStackView(arrangedSubviews: [label, UIView()]) // keeps the pill from stretching full width
        return wrapper
    }

    private func ingredientRow(_ ingredient: RecipeDetailViewModel.IngredientRow) -> UIView {
        let mark = UIImageView(image: UIImage(systemName: ingredient.have ? "checkmark.circle.fill" : "circle"))
        mark.tintColor = ingredient.have ? Theme.Colors.brand : Theme.Colors.muted
        mark.setContentHuggingPriority(.required, for: .horizontal)
        mark.isAccessibilityElement = false

        let text = label(ingredient.text, font: Theme.Typography.body.font,
                         color: ingredient.have ? Theme.Colors.ink : Theme.Colors.soonText)
        let row = UIStackView(arrangedSubviews: [mark, text])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .firstBaseline
        row.isAccessibilityElement = true
        row.accessibilityLabel = ingredient.accessibilityText
        return row
    }

    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> UIButton {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        config.baseBackgroundColor = Theme.Colors.brand
        config.baseForegroundColor = filled ? Theme.Colors.onBrand : Theme.Colors.brand
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        var attributed = AttributedString(title)
        attributed.font = Theme.Typography.button.font
        config.attributedTitle = attributed
        let button = UIButton(configuration: config)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func buildLayout() {
        heroView.contentMode = .scaleAspectFill
        heroView.clipsToBounds = true
        heroView.layer.cornerRadius = 20
        heroView.backgroundColor = Theme.Colors.iconTile
        heroView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        heroView.isAccessibilityElement = false

        column.axis = .vertical
        column.spacing = 12
        column.isLayoutMarginsRelativeArrangement = true
        column.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 40, right: 20)
        column.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(column)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            column.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            column.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -90),
            column.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            column.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
}

/// A label with room around its text (used for the "You have 3 of 4" pill).
final class PaddedLabel: UILabel {
    private let insets: UIEdgeInsets

    init(insets: UIEdgeInsets) {
        self.insets = insets
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let inner = super.sizeThatFits(CGSize(width: size.width - insets.left - insets.right, height: size.height))
        return CGSize(width: inner.width + insets.left + insets.right, height: inner.height + insets.top + insets.bottom)
    }
}
