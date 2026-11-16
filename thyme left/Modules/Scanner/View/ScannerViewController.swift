import UIKit
import VisionKit
import PhotosUI

/// The waiter of the Scanner screen: shows the live camera (or a photo fallback) and a result card.
final class ScannerViewController: UIViewController, ScannerViewProtocol {

    var presenter: ScannerPresenterProtocol?

    private var scanner: DataScannerViewController?
    private let hintLabel = UILabel()
    private let fallbackStack = UIStackView()

    // Result card
    private let card = UIView()
    private let dateLabel = UILabel()
    private let countdownLabel = UILabel()
    private let sourceLabel = UILabel()
    private let swapButton = UIButton(type: .system)
    private let usePhotoButton = UIButton(type: .system)
    private let useButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)

    /// When the date came from a picked picture (not the live camera), that picture can be kept too.
    private var pickedImageData: Data?

    // MARK: Life of the screen

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        title = "Scan a date"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.presenter?.didTapCancel() })
        navigationItem.largeTitleDisplayMode = .never

        buildLayout()
        presenter?.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startLiveScanningIfPossible()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner?.stopScanning()
    }

    // MARK: ScannerViewProtocol

    func showSearching() {
        card.isHidden = true
        pickedImageData = nil
        hintLabel.text = scanner == nil
            ? "Live scanning isn't available here. Choose a photo of the date instead."
            : "Point the camera at the printed date"
        hintLabel.isHidden = false
        try? scanner?.startScanning()
    }

    func showFound(_ found: ScanFoundViewModel) {
        scanner?.stopScanning()
        hintLabel.isHidden = true
        dateLabel.text = found.dateText
        countdownLabel.text = found.countdownText
        sourceLabel.text = "Read from: \(found.sourceText)"
        swapButton.isHidden = (found.swapText == nil)
        if let text = found.swapText {
            var config = swapButton.configuration
            var title = AttributedString(text)
            title.font = Theme.Typography.caption.font
            config?.attributedTitle = title
            swapButton.configuration = config
        }
        card.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: "Found \(found.dateText). \(found.countdownText)")
    }

    func showNothingFound(message: String) {
        hintLabel.text = message
        hintLabel.isHidden = false
    }

    // MARK: Live camera

    private func startLiveScanningIfPossible() {
        guard scanner == nil, DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            showFallbackIfNeeded()
            return
        }
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()],
                                                qualityLevel: .accurate,
                                                recognizesMultipleItems: true,
                                                isHighFrameRateTrackingEnabled: false,
                                                isHighlightingEnabled: true)
        scanner.delegate = self
        addChild(scanner)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(scanner.view, at: 0)
        NSLayoutConstraint.activate([
            scanner.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        scanner.didMove(toParent: self)
        self.scanner = scanner
        fallbackStack.isHidden = true
        presenter?.viewDidLoad()
    }

    private func showFallbackIfNeeded() {
        presenter?.viewDidLoad() // refreshes the hint text
        fallbackStack.isHidden = false
    }

    /// The text lines the camera can see right now, top to bottom.
    private func visibleLines(_ items: [RecognizedItem]) -> [String] {
        items.compactMap { item -> (String, CGFloat)? in
            guard case .text(let text) = item else { return nil }
            return (text.transcript, item.bounds.topLeft.y)
        }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    // MARK: Actions

    private func confirm(withPhoto: Bool) {
        guard withPhoto else { presenter?.didConfirm(photoData: nil); return }
        if let pickedImageData {
            presenter?.didConfirm(photoData: pickedImageData)
            return
        }
        guard let scanner else { presenter?.didConfirm(photoData: nil); return }
        Task {
            // Take a still picture of what the camera sees. If that fails we still keep the date.
            let image = try? await scanner.capturePhoto()
            presenter?.didConfirm(photoData: image?.jpegData(compressionQuality: 0.9))
        }
    }

    private func choosePhoto() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: Layout

    private func styledButton(_ button: UIButton, title: String, filled: Bool, action: @escaping () -> Void) {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        config.baseBackgroundColor = Theme.Colors.brand
        config.baseForegroundColor = filled ? Theme.Colors.onBrand : Theme.Colors.brand
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        var attributed = AttributedString(title)
        attributed.font = Theme.Typography.button.font
        config.attributedTitle = attributed
        button.configuration = config
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    private func buildLayout() {
        hintLabel.font = Theme.Typography.body.font
        hintLabel.textColor = Theme.Colors.ink
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.adjustsFontForContentSizeCategory = true
        hintLabel.backgroundColor = Theme.Colors.card.withAlphaComponent(0.92)
        hintLabel.layer.cornerRadius = 14
        hintLabel.clipsToBounds = true

        // Fallback: choose a photo of the date
        let fallbackButton = UIButton(type: .system)
        styledButton(fallbackButton, title: "Choose a photo of the date", filled: true) { [weak self] in self?.choosePhoto() }
        fallbackStack.addArrangedSubview(fallbackButton)
        fallbackStack.axis = .vertical
        fallbackStack.isHidden = true
        fallbackStack.translatesAutoresizingMaskIntoConstraints = false

        // Result card
        card.backgroundColor = Theme.Colors.sage
        card.layer.cornerRadius = 22
        card.isHidden = true
        card.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = Theme.Typography.screenTitle.font
        dateLabel.textColor = Theme.Colors.ink
        countdownLabel.font = Theme.Typography.body.font
        countdownLabel.textColor = Theme.Colors.ink
        sourceLabel.font = Theme.Typography.caption.font
        sourceLabel.textColor = Theme.Colors.muted
        for label in [dateLabel, countdownLabel, sourceLabel] {
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
        }
        styledButton(swapButton, title: "", filled: false) { [weak self] in self?.presenter?.didTapSwap() }
        swapButton.isHidden = true
        styledButton(useButton, title: "Use this date", filled: true) { [weak self] in self?.confirm(withPhoto: false) }
        styledButton(usePhotoButton, title: "Use date and keep photo", filled: false) { [weak self] in self?.confirm(withPhoto: true) }
        styledButton(retryButton, title: "Scan again", filled: false) { [weak self] in self?.presenter?.didTapRetry() }
        useButton.accessibilityLabel = "Use this date"

        let cardStack = UIStackView(arrangedSubviews: [dateLabel, countdownLabel, sourceLabel, swapButton,
                                                       useButton, usePhotoButton, retryButton])
        cardStack.axis = .vertical
        cardStack.spacing = 6
        cardStack.setCustomSpacing(14, after: sourceLabel)
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)
        view.addSubview(fallbackStack)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            fallbackStack.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 16),
            fallbackStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            fallbackStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
    }
}

// MARK: - Live camera events

extension ScannerViewController: DataScannerViewControllerDelegate {
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                     allItems: [RecognizedItem]) {
        presenter?.didSeeLines(visibleLines(allItems))
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem],
                     allItems: [RecognizedItem]) {
        presenter?.didSeeLines(visibleLines(allItems))
    }
}

// MARK: - Picked picture (fallback)

extension ScannerViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let data = (object as? UIImage)?.jpegData(compressionQuality: 0.9) else { return }
            DispatchQueue.main.async {
                self?.pickedImageData = data
                self?.presenter?.didPickImage(data)
            }
        }
    }
}
