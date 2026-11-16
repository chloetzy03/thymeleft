import UIKit

/// The waiter of the Recipes screen.
final class RecipesViewController: UIViewController, RecipesViewProtocol {

    var presenter: RecipesPresenterProtocol?
    private let imageLoader: RemoteImageLoading

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let segmented = UISegmentedControl()
    private let rescueLabel = UILabel()
    private let bannerLabel = UILabel()
    private let attributionLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let messageView = EmptyStateView()
    private var rows: [RecipeRowViewModel] = []

    init(imageLoader: RemoteImageLoading) {
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        title = "Recipes"
        navigationController?.navigationBar.prefersLargeTitles = true
        buildLayout()
        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }

    // MARK: RecipesViewProtocol

    func showSortModes(titles: [String], selectedIndex: Int) {
        segmented.removeAllSegments()
        for (index, title) in titles.enumerated() { segmented.insertSegment(withTitle: title, at: index, animated: false) }
        segmented.selectedSegmentIndex = selectedIndex
    }

    func showLoading() {
        tableView.isHidden = true
        messageView.isHidden = true
        spinner.startAnimating()
    }

    func showRecipes(_ screen: RecipesScreenViewModel) {
        spinner.stopAnimating()
        messageView.isHidden = true
        rows = screen.rows
        rescueLabel.text = screen.rescueSummary
        rescueLabel.isHidden = (screen.rescueSummary == nil)
        bannerLabel.text = screen.banner
        bannerLabel.isHidden = (screen.banner == nil)
        sizeHeader()
        tableView.isHidden = false
        tableView.reloadData()
    }

    func showMessage(emoji: String, title: String, message: String, buttonTitle: String?) {
        spinner.stopAnimating()
        tableView.isHidden = true
        messageView.configure(emoji: emoji, title: title, message: message, buttonTitle: buttonTitle)
        messageView.isHidden = false
    }

    // MARK: Layout

    private func buildLayout() {
        styleSegmented()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _) in self.styleSegmented() }
        segmented.accessibilityLabel = "Order recipes by"
        segmented.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didSelectSort(at: self.segmented.selectedSegmentIndex)
        }, for: .valueChanged)

        rescueLabel.font = Theme.Typography.body.font
        rescueLabel.textColor = Theme.Colors.ink
        bannerLabel.font = Theme.Typography.caption.font
        bannerLabel.textColor = Theme.Colors.soonText
        bannerLabel.backgroundColor = Theme.Colors.soonBackground
        bannerLabel.layer.cornerRadius = 12
        bannerLabel.clipsToBounds = true
        for label in [rescueLabel, bannerLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        let header = UIStackView(arrangedSubviews: [segmented, rescueLabel, bannerLabel])
        header.axis = .vertical
        header.spacing = 10
        header.isLayoutMarginsRelativeArrangement = true
        header.layoutMargins = UIEdgeInsets(top: 4, left: 16, bottom: 10, right: 16)
        header.frame = CGRect(x: 0, y: 0, width: 0, height: 120)
        tableView.tableHeaderView = header

        attributionLabel.text = "Recipes from TheMealDB (themealdb.com)"
        attributionLabel.font = Theme.Typography.caption.font
        attributionLabel.textColor = Theme.Colors.muted
        attributionLabel.textAlignment = .center
        attributionLabel.numberOfLines = 0
        attributionLabel.adjustsFontForContentSizeCategory = true
        attributionLabel.frame = CGRect(x: 0, y: 0, width: 0, height: 60)
        tableView.tableFooterView = attributionLabel

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 106
        tableView.contentInset.bottom = 90 // room above the floating tab bar
        tableView.register(RecipeCell.self, forCellReuseIdentifier: RecipeCell.reuseIdentifier)
        tableView.isHidden = true

        messageView.isHidden = true
        messageView.onButtonTap = { [weak self] in self?.presenter?.didTapRetry() }
        spinner.color = Theme.Colors.brand
        spinner.accessibilityLabel = "Loading recipes"
        for subview in [tableView, messageView, spinner] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            messageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            messageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            messageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    /// The segmented control's text colours are fixed when set, so pick the right ones for light or dark.
    private func styleSegmented() {
        segmented.selectedSegmentTintColor = Theme.Colors.brand
        segmented.setTitleTextAttributes([.foregroundColor: Theme.Colors.onBrand.resolvedColor(with: traitCollection)], for: .selected)
        segmented.setTitleTextAttributes([.foregroundColor: Theme.Colors.ink.resolvedColor(with: traitCollection)], for: .normal)
    }

    /// A table header doesn't resize itself, so measure it after its content changes.
    private func sizeHeader() {
        // The footer is one wrapping label; give it as much height as its text needs.
        let footerWidth = max(tableView.bounds.width, view.bounds.width) - 32
        let footerHeight = attributionLabel.sizeThatFits(CGSize(width: footerWidth, height: .greatestFiniteMagnitude)).height + 32
        attributionLabel.frame = CGRect(x: 0, y: 0, width: 0, height: footerHeight)
        tableView.tableFooterView = attributionLabel

        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : view.bounds.width
        let height = header.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                                    withHorizontalFittingPriority: .required,
                                                    verticalFittingPriority: .fittingSizeLevel).height
        header.frame = CGRect(x: 0, y: 0, width: width, height: height)
        tableView.tableHeaderView = header
    }
}

extension RecipesViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RecipeCell.reuseIdentifier, for: indexPath)
        (cell as? RecipeCell)?.configure(with: rows[indexPath.row], imageLoader: imageLoader)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter?.didSelectRecipe(id: rows[indexPath.row].id)
    }
}
