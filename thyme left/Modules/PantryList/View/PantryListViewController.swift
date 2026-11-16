import UIKit

/// The waiter of the Pantry screen: draws what it's told and passes taps to the Presenter.
/// (Translation: no decisions in here. It never asks "is this expired?". It just shows.)
final class PantryListViewController: UIViewController, PantryListViewProtocol {

    var presenter: PantryListPresenterProtocol?
    private let photoCache: PhotoImageCache

    private let chipBar = FilterChipBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateView = EmptyStateView()
    private var sections: [PantrySectionViewModel] = []

    init(photoCache: PhotoImageCache) {
        self.photoCache = photoCache
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    // MARK: Life of the screen

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background

        title = "Pantry"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .add,
            primaryAction: UIAction { [weak self] _ in self?.presenter?.didTapAdd() })
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Add item"

        buildLayout()
        presenter?.viewDidLoad()

        // When the user comes back to the app (maybe a new day!), refresh the countdowns.
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.refreshRequested()
    }

    /// Asks for fresh information. Used when something saved from outside this screen (like the Scan tab).
    func reload() {
        presenter?.refreshRequested()
    }

    @objc private func appWillEnterForeground() {
        presenter?.refreshRequested()
    }

    // MARK: PantryListViewProtocol (what the Presenter can ask us to do)

    func showFilters(titles: [String], selectedIndex: Int) {
        chipBar.update(titles: titles, selectedIndex: selectedIndex)
    }

    func showSections(_ sections: [PantrySectionViewModel]) {
        self.sections = sections
        emptyStateView.isHidden = true
        tableView.isHidden = false
        tableView.reloadData()
    }

    func showEmptyState(_ state: PantryEmptyStateViewModel) {
        sections = []
        tableView.reloadData()
        tableView.isHidden = true
        emptyStateView.configure(emoji: state.emoji, title: state.title,
                                 message: state.message, buttonTitle: state.buttonTitle)
        emptyStateView.isHidden = false
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Something went wrong", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: Layout

    private func buildLayout() {
        chipBar.onSelect = { [weak self] index in self?.presenter?.didSelectFilter(at: index) }
        chipBar.translatesAutoresizingMaskIntoConstraints = false

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 76
        tableView.contentInset.bottom = 16
        tableView.register(PantryItemCell.self, forCellReuseIdentifier: PantryItemCell.reuseIdentifier)
        tableView.register(PantrySectionHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: PantrySectionHeaderView.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        emptyStateView.isHidden = true
        emptyStateView.onButtonTap = { [weak self] in self?.presenter?.didTapAdd() }
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(chipBar)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            chipBar.topAnchor.constraint(equalTo: safe.topAnchor),
            chipBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chipBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chipBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),

            tableView.topAnchor.constraint(equalTo: chipBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: chipBar.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: safe.bottomAnchor)
        ])
    }
}

// MARK: - Table: how many rows, what each row looks like

extension PantryListViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PantryItemCell.reuseIdentifier, for: indexPath)
        if let itemCell = cell as? PantryItemCell {
            itemCell.configure(with: sections[indexPath.section].rows[indexPath.row], photoCache: photoCache)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: PantrySectionHeaderView.reuseIdentifier)
        (header as? PantrySectionHeaderView)?.configure(title: sections[section].title)
        return header
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter?.didSelectRow(id: sections[indexPath.section].rows[indexPath.row].id)
    }

    // Swipe a row to the left to say what happened to the food.
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let id = sections[indexPath.section].rows[indexPath.row].id

        func action(_ title: String, _ outcome: ItemOutcome, style: UIContextualAction.Style,
                    color: UIColor, symbol: String) -> UIContextualAction {
            let action = UIContextualAction(style: style, title: title) { [weak self] _, _, done in
                self?.presenter?.didFinishRow(id: id, as: outcome)
                done(true)
            }
            action.backgroundColor = color
            action.image = UIImage(systemName: symbol)
            return action
        }
        let configuration = UISwipeActionsConfiguration(actions: [
            action("Delete", .removed, style: .destructive, color: Theme.Colors.urgentText, symbol: "trash"),
            action("Threw away", .wasted, style: .normal, color: Theme.Colors.soonText, symbol: "arrow.3.trianglepath"),
            action("Used it", .used, style: .normal, color: Theme.Colors.brand, symbol: "checkmark.circle")
        ])
        // A long swipe must never delete by accident, so it performs nothing.
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
