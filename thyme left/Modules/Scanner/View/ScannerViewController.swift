import UIKit
import VisionKit
import PhotosUI
import AVFoundation

/// The waiter of the Scanner screen: shows the live camera (or a photo fallback) and a result card.
final class ScannerViewController: UIViewController, ScannerViewProtocol {

    var presenter: ScannerPresenterProtocol?

    /// True when opened on top of another screen (from the Add form), so it needs a Cancel button.
    /// False for the Scan tab, which is a normal screen.
    private let isPopUp: Bool

    private var scanner: DataScannerViewController?
    private let hintLabel = UILabel()
    private let fallbackStack = UIStackView()
    private let frameView = ViewfinderFrameView()
    private let photoLibraryButton = UIButton(type: .system)
    private let torchButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private var torchIsOn = false

    /// After a date was handed to the form, the next visit starts a fresh scan.
    private var startFreshOnNextAppear = false

    init(isPopUp: Bool = true) {
        self.isPopUp = isPopUp
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    // Result card
    private let card = UIView()
    private let dateLabel = UILabel()
    private let countdownLabel = UILabel()
    private let sourceLabel = UILabel()
    private let guessLabel = UILabel()
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
        navigationItem.title = String(localized: "Scan a date") // not `title`: that would also rename the tab
        if isPopUp {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                systemItem: .cancel,
                primaryAction: UIAction { [weak self] _ in self?.presenter?.didTapCancel() })
        }
        navigationItem.largeTitleDisplayMode = .never

        buildLayout()
        presenter?.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if startFreshOnNextAppear {
            startFreshOnNextAppear = false
            presenter?.didTapRetry()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if scanner == nil {
            startLiveScanningIfPossible()
        } else if card.isHidden {
            try? scanner?.startScanning() // we stop the camera when leaving the tab, so wake it up again
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner?.stopScanning()
        setTorch(on: false)
    }

    // MARK: ScannerViewProtocol

    func showSearching() {
        card.isHidden = true
        frameView.isHidden = (scanner == nil)
        pickedImageData = nil
        hintLabel.text = scanner == nil
            ? String(localized: "Live scanning isn't available here. Choose a photo of the date instead.")
            : String(localized: "Point the camera at the printed date")
        hintLabel.isHidden = false
        try? scanner?.startScanning()
    }

    func showFound(_ found: ScanFoundViewModel) {
        // The camera keeps running behind the card on purpose: taking the "keep photo" picture
        // needs it running. We pause it when the user finishes (see `confirm`).
        hintLabel.isHidden = true
        frameView.isHidden = true
        dateLabel.text = found.dateText
        countdownLabel.text = found.countdownText
        sourceLabel.text = String(localized: "Read from: \(found.sourceText)")
        guessLabel.text = found.guessNote
        guessLabel.isHidden = (found.guessNote == nil)
        swapButton.isHidden = (found.swapText == nil)
        if let text = found.swapText {
            var config = swapButton.configuration
            var title = AttributedString(text)
            title.font = Theme.Typography.caption.font
            config?.attributedTitle = title
            swapButton.configuration = config
        }
        card.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: String(localized: "Found \(found.dateText). \(found.countdownText)"))
    }

    func showNothingFound(message: String) {
        hintLabel.text = message
        hintLabel.isHidden = false
    }

    // MARK: Live camera

    private func startLiveScanningIfPossible() {
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            showFallbackIfNeeded()
            return
        }
        let scanner = DataScannerViewController(recognizedDataTypes: [liveTextType()],
                                                qualityLevel: .accurate,
                                                recognizesMultipleItems: true,
                                                isHighFrameRateTrackingEnabled: false,
                                                isHighlightingEnabled: true)
        scanner.delegate = self
        addChild(scanner)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(scanner.view, at: 0)
        NSLayoutConstraint.activate([
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        scanner.didMove(toParent: self)
        self.scanner = scanner
        fallbackStack.isHidden = true
        photoLibraryButton.isHidden = false
        torchButton.isHidden = !(AVCaptureDevice.default(for: .video)?.hasTorch ?? false)
        presenter?.viewDidLoad()
    }

    /// The live camera reads English and Chinese when this iPhone supports both.
    private func liveTextType() -> DataScannerViewController.RecognizedDataType {
        let supported = DataScannerViewController.supportedTextRecognitionLanguages
        let wanted = TextRecognitionLanguages.preferred.filter { supported.contains($0) }
        return wanted.isEmpty ? .text() : .text(languages: wanted)
    }

    private func showFallbackIfNeeded() {
        presenter?.viewDidLoad() // refreshes the hint text
        fallbackStack.isHidden = false
        photoLibraryButton.isHidden = true
        torchButton.isHidden = true
        // If the user said "no" to the camera before, tell them where to change their mind.
        let denied = [AVAuthorizationStatus.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .video))
        settingsButton.isHidden = !denied
        if denied {
            hintLabel.text = String(localized: "Camera access is off. Turn it on in Settings, or choose a photo of the date.")
        }
    }

    private func setTorch(on: Bool) {
        torchIsOn = on
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch,
              (try? device.lockForConfiguration()) != nil else { return }
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
        torchButton.configuration?.image = UIImage(systemName: on ? "flashlight.on.fill" : "flashlight.off.fill")
        torchButton.accessibilityValue = on ? String(localized: "On") : String(localized: "Off")
    }

    /// The text lines the camera can see right now, top to bottom.
    /// Pieces of text that sit on the same row (like "5" and "NOV 2027" printed with a gap) are joined
    /// left-to-right, so a date split by the camera is read as one date.
    private func visibleLines(_ items: [RecognizedItem]) -> [String] {
        struct Piece { let text: String; let left: CGFloat; let midY: CGFloat; let height: CGFloat }
        let pieces: [Piece] = items.compactMap { item in
            guard case .text(let text) = item else { return nil }
            let bounds = item.bounds
            let height = abs(bounds.bottomLeft.y - bounds.topLeft.y)
            return Piece(text: text.transcript, left: bounds.topLeft.x,
                         midY: (bounds.topLeft.y + bounds.bottomLeft.y) / 2, height: max(height, 1))
        }.sorted { $0.midY < $1.midY }

        var rows: [[Piece]] = []
        for piece in pieces {
            if let last = rows.last?.first, abs(last.midY - piece.midY) < max(last.height, piece.height) * 0.6 {
                rows[rows.count - 1].append(piece)
            } else {
                rows.append([piece])
            }
        }
        return rows.map { row in row.sorted { $0.left < $1.left }.map(\.text).joined(separator: " ") }
    }

    // MARK: Actions

    private func confirm(withPhoto: Bool) {
        guard withPhoto else { finish(with: nil); return }
        if let pickedImageData {
            finish(with: pickedImageData)
            return
        }
        guard let scanner else { finish(with: nil); return }
        useButton.isEnabled = false
        usePhotoButton.isEnabled = false
        Task {
            // Take a still picture of what the camera sees. If that fails we still keep the date,
            // but we say so instead of silently dropping the photo.
            let image = try? await scanner.capturePhoto()
            useButton.isEnabled = true
            usePhotoButton.isEnabled = true
            guard let data = image?.jpegData(compressionQuality: 0.9) else {
                let alert = UIAlertController(
                    title: String(localized: "Couldn't take the photo"),
                    message: String(localized: "We'll still use the date. You can add a photo on the next screen."),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default) { [weak self] _ in self?.finish(with: nil) })
                present(alert, animated: true)
                return
            }
            finish(with: data)
        }
    }

    /// Hands the result on and parks the camera. If the user comes back to this tab, a fresh scan starts.
    private func finish(with photoData: Data?) {
        scanner?.stopScanning()
        setTorch(on: false)
        startFreshOnNextAppear = true
        presenter?.didConfirm(photoData: photoData)
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
        styledButton(fallbackButton, title: String(localized: "Choose a photo of the date"), filled: true) { [weak self] in self?.choosePhoto() }
        fallbackButton.accessibilityLabel = String(localized: "Choose a photo of the date")
        fallbackStack.addArrangedSubview(fallbackButton)
        styledButton(settingsButton, title: String(localized: "Open Settings"), filled: false) {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
        settingsButton.isHidden = true
        fallbackStack.addArrangedSubview(settingsButton)
        fallbackStack.axis = .vertical
        fallbackStack.spacing = 8
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
        guessLabel.font = Theme.Typography.caption.font
        guessLabel.textColor = Theme.Colors.soonText
        guessLabel.isHidden = true
        sourceLabel.font = Theme.Typography.caption.font
        sourceLabel.textColor = Theme.Colors.muted
        for label in [dateLabel, countdownLabel, sourceLabel, guessLabel] {
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
        }
        styledButton(swapButton, title: "", filled: false) { [weak self] in self?.presenter?.didTapSwap() }
        swapButton.isHidden = true
        styledButton(useButton, title: String(localized: "Use this date"), filled: true) { [weak self] in self?.confirm(withPhoto: false) }
        styledButton(usePhotoButton, title: String(localized: "Use date and keep photo"), filled: false) { [weak self] in self?.confirm(withPhoto: true) }
        styledButton(retryButton, title: String(localized: "Scan again"), filled: false) { [weak self] in self?.presenter?.didTapRetry() }
        useButton.accessibilityLabel = String(localized: "Use this date")

        let cardStack = UIStackView(arrangedSubviews: [dateLabel, countdownLabel, sourceLabel, guessLabel, swapButton,
                                                       useButton, usePhotoButton, retryButton])
        cardStack.axis = .vertical
        cardStack.spacing = 6
        cardStack.setCustomSpacing(14, after: sourceLabel)
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        // Round buttons floating over the camera, like Apple's scanners: choose a photo, torch.
        func styleRound(_ button: UIButton, symbol: String, label: String, action: @escaping () -> Void) {
            var config = UIButton.Configuration.filled()
            config.image = UIImage(systemName: symbol)
            config.cornerStyle = .capsule
            config.baseBackgroundColor = Theme.Colors.card.withAlphaComponent(0.92)
            config.baseForegroundColor = Theme.Colors.brand
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            button.configuration = config
            button.accessibilityLabel = label
            button.isHidden = true
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        }
        styleRound(photoLibraryButton, symbol: "photo.on.rectangle", label: String(localized: "Choose a photo of the date")) { [weak self] in
            self?.choosePhoto()
        }
        styleRound(torchButton, symbol: "flashlight.off.fill", label: String(localized: "Torch")) { [weak self] in
            guard let self else { return }
            self.setTorch(on: !self.torchIsOn)
        }
        let roundButtons = UIStackView(arrangedSubviews: [torchButton, photoLibraryButton])
        roundButtons.axis = .horizontal
        roundButtons.spacing = 12
        roundButtons.translatesAutoresizingMaskIntoConstraints = false

        frameView.isHidden = true
        frameView.translatesAutoresizingMaskIntoConstraints = false

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(frameView)
        view.addSubview(hintLabel)
        view.addSubview(roundButtons)
        view.addSubview(fallbackStack)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            roundButtons.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 12),
            roundButtons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            frameView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.82),
            frameView.heightAnchor.constraint(equalTo: frameView.widthAnchor, multiplier: 0.45),

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
