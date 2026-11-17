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
    private let addRow = UIStackView()
    private let weekCard = UIControl()
    private let weekTitleLabel = UILabel()
    private let weekSubtitleLabel = UILabel()
    private let weekDaysStack = UIStackView()
    private let weekFootnoteLabel = UILabel()
    private let ideaCard = UIControl()
    private let ideaCaptionLabel = UILabel()
    private let ideaTitleLabel = UILabel()
    private let ideaSubtitleLabel = UILabel()
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

        showWeek(home.week)
        showIdea(home.idea)

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

        addRow.isHidden = (home.addFirstTitle == nil) // otherwise its empty space is still reserved
        addFirstButton.isHidden = (home.addFirstTitle == nil)
        if let text = home.addFirstTitle {
            var addConfig = addFirstButton.configuration
            var addTitle = AttributedString(text)
            addTitle.font = Theme.Typography.button.font
            addConfig?.attributedTitle = addTitle
            addFirstButton.configuration = addConfig
        }
    }

    private func showWeek(_ week: HomeWeekViewModel?) {
        weekCard.isHidden = (week == nil)
        guard let week else { return }
        weekTitleLabel.text = week.title
        weekSubtitleLabel.text = week.subtitle
        weekFootnoteLabel.text = week.footnote
        weekFootnoteLabel.isHidden = (week.footnote == nil)
        weekCard.accessibilityLabel = week.accessibilityText

        weekDaysStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for day in week.days {
            let bubble = UILabel()
            bubble.text = day.countText
            bubble.font = Theme.Typography.itemName.font
            bubble.textAlignment = .center
            bubble.textColor = day.count == 0 ? Theme.Colors.muted : day.status.badgeTextColor
            bubble.backgroundColor = day.count == 0 ? Theme.Colors.chip : day.status.badgeBackgroundColor
            bubble.layer.cornerRadius = 18
            bubble.clipsToBounds = true
            bubble.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bubble.widthAnchor.constraint(equalToConstant: 36),
                bubble.heightAnchor.constraint(equalToConstant: 36)
            ])

            let label = UILabel()
            label.text = day.label
            label.font = Theme.Typography.pill.font
            label.textColor = Theme.Colors.muted
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.7
            label.textAlignment = .center

            let column = UIStackView(arrangedSubviews: [bubble, label])
            column.axis = .vertical
            column.alignment = .center
            column.spacing = 4
            weekDaysStack.addArrangedSubview(column)
        }
    }

    private func showIdea(_ idea: HomeIdeaViewModel?) {
        ideaCard.isHidden = (idea == nil)
        guard let idea else { return }
        ideaCaptionLabel.text = idea.caption.uppercased()
        ideaTitleLabel.text = idea.title
        ideaSubtitleLabel.text = idea.subtitle
        ideaCard.accessibilityLabel = idea.accessibilityText
    }

    // MARK: Pieces

    /// Two big friendly shortcuts under the greeting: scan a date, or type an item in.
    private func makeQuickActions() -> UIView {
        func button(title: String, symbol: String, label: String, action: @escaping () -> Void) -> UIButton {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = Theme.Colors.card
            config.baseForegroundColor = Theme.Colors.brand
            config.image = UIImage(systemName: symbol)
            config.imagePlacement = .top
            config.imagePadding = 6
            config.cornerStyle = .large
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 8, bottom: 14, trailing: 8)
            var attributed = AttributedString(title)
            attributed.font = Theme.Typography.chip.font
            config.attributedTitle = attributed
            let button = UIButton(configuration: config)
            button.accessibilityLabel = label
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            return button
        }
        let scan = button(title: String(localized: "Scan a date"), symbol: "viewfinder", label: String(localized: "Scan a date")) { [weak self] in
            self?.presenter?.didTapScan()
        }
        let add = button(title: String(localized: "Add item"), symbol: "plus.circle", label: String(localized: "Add an item")) { [weak self] in
            self?.presenter?.didTapAdd()
        }
        let row = UIStackView(arrangedSubviews: [scan, add])
        row.distribution = .fillEqually
        row.spacing = 12
        return row
    }

    private func buildWeekCard() {
        weekCard.backgroundColor = Theme.Colors.card
        weekCard.layer.cornerRadius = 20
        weekCard.isAccessibilityElement = true
        weekCard.accessibilityTraits = .button
        weekCard.accessibilityHint = String(localized: "Opens your pantry")
        weekCard.addAction(UIAction { [weak self] _ in self?.presenter?.didTapWeek() }, for: .touchUpInside)

        weekTitleLabel.font = Theme.Typography.itemName.font
        weekTitleLabel.textColor = Theme.Colors.ink
        weekSubtitleLabel.font = Theme.Typography.caption.font
        weekSubtitleLabel.textColor = Theme.Colors.muted
        weekFootnoteLabel.font = Theme.Typography.caption.font
        weekFootnoteLabel.textColor = Theme.Colors.urgentText
        for label in [weekTitleLabel, weekSubtitleLabel, weekFootnoteLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        weekDaysStack.axis = .horizontal
        weekDaysStack.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [weekTitleLabel, weekSubtitleLabel, weekDaysStack, weekFootnoteLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(12, after: weekSubtitleLabel)
        stack.setCustomSpacing(10, after: weekDaysStack)
        stack.isUserInteractionEnabled = false // taps go to the card itself
        stack.translatesAutoresizingMaskIntoConstraints = false
        weekCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: weekCard.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: weekCard.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: weekCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: weekCard.trailingAnchor, constant: -16)
        ])
        weekCard.isHidden = true
    }

    private func buildIdeaCard() {
        ideaCard.backgroundColor = Theme.Colors.sage
        ideaCard.layer.cornerRadius = 20
        ideaCard.isAccessibilityElement = true
        ideaCard.accessibilityTraits = .button
        ideaCard.accessibilityHint = String(localized: "Opens recipe ideas")
        ideaCard.addAction(UIAction { [weak self] _ in self?.presenter?.didTapIdea() }, for: .touchUpInside)

        ideaCaptionLabel.font = Theme.Typography.pill.font
        ideaCaptionLabel.textColor = Theme.Colors.muted
        ideaTitleLabel.font = Theme.Typography.sectionTitle.font
        ideaTitleLabel.textColor = Theme.Colors.ink
        ideaSubtitleLabel.font = Theme.Typography.body.font
        ideaSubtitleLabel.textColor = Theme.Colors.ink
        for label in [ideaCaptionLabel, ideaTitleLabel, ideaSubtitleLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        let stack = UIStackView(arrangedSubviews: [ideaCaptionLabel, ideaTitleLabel, ideaSubtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        ideaCard.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: ideaCard.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: ideaCard.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: ideaCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: ideaCard.trailingAnchor, constant: -16)
        ])
        ideaCard.isHidden = true
    }

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
        logoLabel.text = String(localized: "thyme left.")
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

        addRow.addArrangedSubview(addFirstButton)
        addRow.addArrangedSubview(UIView())
        addRow.isHidden = true
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
        cookButton.accessibilityLabel = String(localized: "What can I cook?")
        cookButton.accessibilityHint = String(localized: "Opens recipe ideas using your food")

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

        buildWeekCard()
        buildIdeaCard()
        let column = UIStackView(arrangedSubviews: [header, taglineLabel, greetingCard, makeQuickActions(),
                                                    weekCard, ideaCard, cookButton, savedCard])
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
