import UIKit

/// The waiter of the Home screen.
final class HomeViewController: UIViewController, HomeViewProtocol {

    var presenter: HomePresenterProtocol?
    private let photoCache: PhotoImageCache

    private let logoLabel = UILabel()
    private let taglineLabel = UILabel()
    private let greetingCard = UIView()
    private let greetingLabel = UILabel()
    private let summaryLabel = UILabel()
    private let tilesStack = UIStackView()
    private let cookButton = UIButton(type: .system)
    private let addFirstButton = UIButton(type: .system)
    private let savedCard = UIView()
    private let savedTitleLabel = UILabel()
    private let savedTextLabel = UILabel()

    init(photoCache: PhotoImageCache) {
        self.photoCache = photoCache
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        buildLayout()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        presenter?.viewWillAppear()
    }

    @objc private func refresh() { presenter?.viewWillAppear() }

    // MARK: HomeViewProtocol

    func showHome(_ home: HomeViewModel) {
        greetingLabel.text = home.greeting
        taglineLabel.text = home.tagline
        summaryLabel.text = home.summary
        savedTitleLabel.text = home.savedTitle
        savedTextLabel.text = home.savedText

        tilesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tile in home.tiles { tilesStack.addArrangedSubview(makeTile(tile)) }
        tilesStack.isHidden = home.tiles.isEmpty

        var config = cookButton.configuration
        var title = AttributedString(home.cookTitle)
        title.font = Theme.Typography.sectionTitle.font
        var subtitle = AttributedString(home.cookSubtitle)
        subtitle.font = Theme.Typography.caption.font
        config?.attributedTitle = title
        config?.attributedSubtitle = subtitle
        cookButton.configuration = config

        addFirstButton.isHidden = (home.addFirstTitle == nil)
        if let text = home.addFirstTitle {
            var addConfig = addFirstButton.configuration
            var addTitle = AttributedString(text)
            addTitle.font = Theme.Typography.button.font
            addConfig?.attributedTitle = addTitle
            addFirstButton.configuration = addConfig
        }
    }

    // MARK: Pieces

    private func makeTile(_ tile: HomeTileViewModel) -> UIView {
        let card = UIControl()
        card.backgroundColor = Theme.Colors.card
        card.layer.cornerRadius = 16
        card.addAction(UIAction { [weak self] _ in self?.presenter?.didTapTile(id: tile.id) }, for: .touchUpInside)
        card.isAccessibilityElement = true
        card.accessibilityLabel = tile.accessibilityText
        card.accessibilityTraits = .button

        let picture = UIImageView()
        picture.contentMode = .scaleAspectFill
        picture.clipsToBounds = true
        picture.layer.cornerRadius = 12
        let emoji = UILabel()
        emoji.text = tile.emoji
        emoji.font = .systemFont(ofSize: 30)
        emoji.textAlignment = .center
        if let name = tile.photoFileName, let image = photoCache.image(named: name) {
            picture.image = image
            emoji.isHidden = true
        }
        let pictureHolder = UIView()
        for subview in [picture, emoji] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            pictureHolder.addSubview(subview)
            NSLayoutConstraint.activate([
                subview.topAnchor.constraint(equalTo: pictureHolder.topAnchor),
                subview.bottomAnchor.constraint(equalTo: pictureHolder.bottomAnchor),
                subview.leadingAnchor.constraint(equalTo: pictureHolder.leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: pictureHolder.trailingAnchor)
            ])
        }
        pictureHolder.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let name = UILabel()
        name.text = tile.name
        name.font = Theme.Typography.itemName.font
        name.textColor = Theme.Colors.ink
        name.textAlignment = .center
        name.adjustsFontForContentSizeCategory = true
        name.numberOfLines = 2
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.8

        let badge = PillLabel()
        badge.configure(text: tile.badgeText, status: tile.status)

        let stack = UIStackView(arrangedSubviews: [pictureHolder, name, badge])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        pictureHolder.widthAnchor.constraint(equalToConstant: 44).isActive = true
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6)
        ])
        return card
    }

    private func buildLayout() {
        logoLabel.text = "thyme left."
        logoLabel.font = Theme.Typography.logo.font
        logoLabel.textColor = Theme.Colors.brand
        logoLabel.adjustsFontForContentSizeCategory = true
        logoLabel.accessibilityTraits = .header
        let sprout = UILabel()
        sprout.text = "🌱"
        sprout.font = .systemFont(ofSize: 30)
        sprout.isAccessibilityElement = false
        let header = UIStackView(arrangedSubviews: [logoLabel, UIView(), sprout])
        header.alignment = .center

        taglineLabel.font = Theme.Typography.body.font
        taglineLabel.textColor = Theme.Colors.muted
        taglineLabel.adjustsFontForContentSizeCategory = true
        taglineLabel.numberOfLines = 0

        // Greeting card with the "use soon" tiles
        greetingCard.backgroundColor = Theme.Colors.sage
        greetingCard.layer.cornerRadius = 24
        greetingLabel.font = Theme.Typography.sectionTitle.font
        greetingLabel.textColor = Theme.Colors.ink
        greetingLabel.accessibilityTraits = .header
        summaryLabel.font = Theme.Typography.body.font
        summaryLabel.textColor = Theme.Colors.ink
        for label in [greetingLabel, summaryLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        tilesStack.axis = .horizontal
        tilesStack.distribution = .fillEqually
        tilesStack.spacing = 10
        tilesStack.isHidden = true

        var addConfig = UIButton.Configuration.filled()
        addConfig.baseBackgroundColor = Theme.Colors.brand
        addConfig.baseForegroundColor = Theme.Colors.onBrand
        addConfig.cornerStyle = .capsule
        addConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        addFirstButton.configuration = addConfig
        addFirstButton.isHidden = true
        addFirstButton.addAction(UIAction { [weak self] _ in self?.presenter?.didTapAddFirst() }, for: .touchUpInside)

        let addRow = UIStackView(arrangedSubviews: [addFirstButton, UIView()])
        let greetingStack = UIStackView(arrangedSubviews: [greetingLabel, summaryLabel, tilesStack, addRow])
        greetingStack.axis = .vertical
        greetingStack.spacing = 10
        greetingStack.translatesAutoresizingMaskIntoConstraints = false
        greetingCard.addSubview(greetingStack)
        NSLayoutConstraint.activate([
            greetingStack.topAnchor.constraint(equalTo: greetingCard.topAnchor, constant: 16),
            greetingStack.bottomAnchor.constraint(equalTo: greetingCard.bottomAnchor, constant: -16),
            greetingStack.leadingAnchor.constraint(equalTo: greetingCard.leadingAnchor, constant: 16),
            greetingStack.trailingAnchor.constraint(equalTo: greetingCard.trailingAnchor, constant: -16)
        ])

        // The big "What can I cook?" button
        var cookConfig = UIButton.Configuration.filled()
        cookConfig.baseBackgroundColor = Theme.Colors.brand
        cookConfig.baseForegroundColor = Theme.Colors.onBrand
        cookConfig.cornerStyle = .large
        cookConfig.titleAlignment = .center
        cookConfig.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 16, bottom: 18, trailing: 16)
        cookButton.configuration = cookConfig
        cookButton.addAction(UIAction { [weak self] _ in self?.presenter?.didTapCook() }, for: .touchUpInside)
        cookButton.accessibilityLabel = "What can I cook?"
        cookButton.accessibilityHint = "Opens recipe ideas using your food"

        // Saved-from-the-bin card
        savedCard.backgroundColor = Theme.Colors.card
        savedCard.layer.cornerRadius = 20
        savedTitleLabel.font = Theme.Typography.itemName.font
        savedTitleLabel.textColor = Theme.Colors.ink
        savedTextLabel.font = Theme.Typography.body.font
        savedTextLabel.textColor = Theme.Colors.muted
        for label in [savedTitleLabel, savedTextLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        let savedStack = UIStackView(arrangedSubviews: [savedTitleLabel, savedTextLabel])
        savedStack.axis = .vertical
        savedStack.spacing = 4
        savedStack.translatesAutoresizingMaskIntoConstraints = false
        savedCard.addSubview(savedStack)
        NSLayoutConstraint.activate([
            savedStack.topAnchor.constraint(equalTo: savedCard.topAnchor, constant: 16),
            savedStack.bottomAnchor.constraint(equalTo: savedCard.bottomAnchor, constant: -16),
            savedStack.leadingAnchor.constraint(equalTo: savedCard.leadingAnchor, constant: 16),
            savedStack.trailingAnchor.constraint(equalTo: savedCard.trailingAnchor, constant: -16)
        ])

        let column = UIStackView(arrangedSubviews: [header, taglineLabel, greetingCard, cookButton, savedCard])
        column.axis = .vertical
        column.spacing = 14
        column.setCustomSpacing(4, after: header)
        column.isLayoutMarginsRelativeArrangement = true
        column.layoutMargins = UIEdgeInsets(top: 8, left: 20, bottom: 110, right: 20)
        column.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(column)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            column.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            column.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            column.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            column.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
}
