import UIKit
import PhotosUI
import AVFoundation

/// The waiter of the Add / Edit screen: shows the form and reports what the user typed or tapped.
final class AddEditItemViewController: UIViewController, AddEditItemViewProtocol {

    var presenter: AddEditItemPresenterProtocol?

    // The form controls. Created once, filled in when the Presenter calls `showForm`.
    private let emojiLabel = UILabel()
    private let photoButton = UIButton(type: .custom) // the square tile: shows the photo or the emoji
    private let photoImageView = UIImageView()
    private let nameField = UITextField()
    private let nameErrorLabel = UILabel()
    private let quantityValueLabel = UILabel()
    private let stepper = UIStepper()
    private let locationButton = UIButton(type: .system)
    private let reminderButton = UIButton(type: .system)
    private let datePicker = UIDatePicker()
    private let quickDateBar = FilterChipBar()
    private let dateTypeControl = UISegmentedControl()
    private let priceField = UITextField()
    private let priceErrorLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private let scanButton = UIButton(type: .system)

    private var selectedLocationIndex = 0
    private var selectedReminderIndex = 0

    // MARK: Life of the screen

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.presenter?.didTapCancel() })
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .save,
            primaryAction: UIAction { [weak self] _ in self?.saveTapped() })

        buildLayout()
        presenter?.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // New item? Pop the keyboard up so the user can start typing straight away.
        if nameField.text?.isEmpty ?? true {
            nameField.becomeFirstResponder()
        }
    }

    // MARK: AddEditItemViewProtocol (what the Presenter can ask us to do)

    func showForm(_ form: AddEditFormViewModel) {
        title = form.title
        emojiLabel.text = form.emoji
        nameField.text = form.name
        showPhoto(form.photoData)

        stepper.minimumValue = Double(form.quantityRange.lowerBound)
        stepper.maximumValue = Double(form.quantityRange.upperBound)
        stepper.value = Double(form.quantity)
        updateQuantityLabel()

        selectedLocationIndex = form.selectedLocationIndex
        // A pop-up menu of the locations; the button's title follows the user's choice.
        locationButton.menu = UIMenu(children: form.locationTitles.enumerated().map { index, title in
            UIAction(title: title, state: index == form.selectedLocationIndex ? .on : .off) { [weak self] _ in
                self?.selectedLocationIndex = index
            }
        })
        locationButton.showsMenuAsPrimaryAction = true
        locationButton.changesSelectionAsPrimaryAction = true

        selectedReminderIndex = form.selectedReminderIndex
        reminderButton.menu = UIMenu(children: form.reminderTitles.enumerated().map { index, title in
            UIAction(title: title, state: index == form.selectedReminderIndex ? .on : .off) { [weak self] _ in
                self?.selectedReminderIndex = index
            }
        })
        reminderButton.showsMenuAsPrimaryAction = true
        reminderButton.changesSelectionAsPrimaryAction = true

        // "Best before" / "Use by": what the date on the pack means.
        dateTypeControl.removeAllSegments()
        for (index, title) in form.dateTypeTitles.enumerated() {
            dateTypeControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        dateTypeControl.selectedSegmentIndex = form.selectedDateTypeIndex
        priceField.text = form.priceText

        datePicker.date = form.expiryDate
        quickDateBar.update(titles: form.quickDateTitles, selectedIndex: -1) // -1 = none highlighted

        var config = saveButton.configuration
        var title = AttributedString(form.saveButtonTitle)
        title.font = Theme.Typography.button.font
        config?.attributedTitle = title
        saveButton.configuration = config
    }

    func showEmoji(_ emoji: String) {
        emojiLabel.text = emoji
    }

    func showPhoto(_ data: Data?) {
        if let data, let image = UIImage(data: data) {
            photoImageView.image = image
            photoImageView.isHidden = false
            emojiLabel.isHidden = true
        } else {
            photoImageView.image = nil
            photoImageView.isHidden = true
            emojiLabel.isHidden = false
        }
    }

    func showPhotoOptions(_ options: [PhotoOption]) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for option in options {
            switch option {
            case .takePhoto:
                // The simulator has no camera, so only offer this when one exists.
                guard UIImagePickerController.isSourceTypeAvailable(.camera) else { continue }
                sheet.addAction(UIAlertAction(title: "Take photo", style: .default) { [weak self] _ in
                    self?.presenter?.didSelectPhotoOption(.takePhoto)
                })
            case .chooseFromLibrary:
                sheet.addAction(UIAlertAction(title: "Choose from library", style: .default) { [weak self] _ in
                    self?.presenter?.didSelectPhotoOption(.chooseFromLibrary)
                })
            case .removePhoto:
                sheet.addAction(UIAlertAction(title: "Remove photo", style: .destructive) { [weak self] _ in
                    self?.presenter?.didSelectPhotoOption(.removePhoto)
                })
            }
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = photoButton // needed on iPad
        present(sheet, animated: true)
    }

    func presentPhotoPicker(_ source: PhotoSource) {
        switch source {
        case .library:
            // The library picker runs outside our app, so it needs no permission at all.
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            present(picker, animated: true)
        case .camera:
            presentCamera()
        }
    }

    private func presentCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            let alert = UIAlertController(
                title: "Camera is off",
                message: "Allow camera access in iOS Settings to take photos of your food.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            })
            present(alert, animated: true)
        default:
            // If the user hasn't decided yet, iOS shows its "Allow camera?" question by itself.
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            present(picker, animated: true)
        }
    }

    func showExpiryDate(_ date: Date) {
        datePicker.setDate(date, animated: true)
    }

    func showNameError(_ message: String?) {
        nameErrorLabel.text = message
        nameErrorLabel.isHidden = (message == nil)
        if let message {
            // Tell VoiceOver users about the problem, too.
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    func showPriceError(_ message: String?) {
        priceErrorLabel.text = message
        priceErrorLabel.isHidden = (message == nil)
        if let message {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    func showReminderPrimer() {
        let alert = UIAlertController(
            title: "Get reminders?",
            message: "We'll nudge you before things expire so nothing goes to waste. You can change this any time in the Me tab.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel) { [weak self] _ in
            self?.presenter?.didRespondToReminderPrimer(allow: false)
        })
        alert.addAction(UIAlertAction(title: "Allow reminders", style: .default) { [weak self] _ in
            self?.presenter?.didRespondToReminderPrimer(allow: true)
        })
        present(alert, animated: true)
    }

    func showError(message: String) {
        let alert = UIAlertController(title: "Something went wrong", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: Actions

    private func saveTapped() {
        view.endEditing(true)
        presenter?.didTapSave(name: nameField.text ?? "",
                              quantity: Int(stepper.value),
                              locationIndex: selectedLocationIndex,
                              reminderIndex: selectedReminderIndex,
                              expiryDate: datePicker.date)
    }

    private func updateQuantityLabel() {
        quantityValueLabel.text = "\(Int(stepper.value))"
        stepper.accessibilityValue = "\(Int(stepper.value))"
    }

    // MARK: Layout

    private func buildLayout() {
        // --- Name + emoji preview
        let emojiTile = photoButton
        emojiTile.backgroundColor = Theme.Colors.iconTile
        emojiTile.layer.cornerRadius = 18
        emojiTile.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.font = .systemFont(ofSize: 34)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.isAccessibilityElement = false // decoration only
        emojiTile.addSubview(emojiLabel)

        // The photo fills the tile (cropped to fit) and sits on top of the emoji when present.
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = 18
        photoImageView.isHidden = true
        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        emojiTile.addSubview(photoImageView)

        // A small camera badge hints that the tile can be tapped.
        let badge = UIImageView(image: UIImage(systemName: "camera.fill"))
        badge.tintColor = Theme.Colors.onBrand
        badge.contentMode = .center
        badge.backgroundColor = Theme.Colors.brand
        badge.layer.cornerRadius = 12
        badge.translatesAutoresizingMaskIntoConstraints = false
        emojiTile.addSubview(badge)
        NSLayoutConstraint.activate([
            photoImageView.topAnchor.constraint(equalTo: emojiTile.topAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: emojiTile.bottomAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: emojiTile.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: emojiTile.trailingAnchor),
            badge.widthAnchor.constraint(equalToConstant: 24),
            badge.heightAnchor.constraint(equalToConstant: 24),
            badge.trailingAnchor.constraint(equalTo: emojiTile.trailingAnchor, constant: 6),
            badge.bottomAnchor.constraint(equalTo: emojiTile.bottomAnchor, constant: 6)
        ])

        emojiTile.accessibilityLabel = "Item photo"
        emojiTile.accessibilityHint = "Add, change or remove a photo"
        emojiTile.addAction(UIAction { [weak self] _ in self?.presenter?.didTapPhoto() }, for: .touchUpInside)

        nameField.placeholder = "What is it? e.g. Milk"
        nameField.font = Theme.Typography.sectionTitle.font
        nameField.textColor = Theme.Colors.ink
        nameField.adjustsFontForContentSizeCategory = true
        nameField.returnKeyType = .done
        nameField.autocapitalizationType = .sentences
        nameField.clearButtonMode = .whileEditing
        nameField.accessibilityLabel = "Item name"
        nameField.addAction(UIAction { [weak self] _ in
            self?.presenter?.nameChanged(self?.nameField.text ?? "")
        }, for: .editingChanged)
        nameField.addAction(UIAction { [weak self] _ in self?.nameField.resignFirstResponder() },
                            for: .editingDidEndOnExit)

        let nameCard = UIView()
        nameCard.backgroundColor = Theme.Colors.card
        nameCard.layer.cornerRadius = 20
        let nameRow = UIStackView(arrangedSubviews: [emojiTile, nameField])
        nameRow.axis = .horizontal
        nameRow.alignment = .center
        nameRow.spacing = 14
        nameRow.translatesAutoresizingMaskIntoConstraints = false
        nameCard.addSubview(nameRow)

        nameErrorLabel.font = Theme.Typography.caption.font
        nameErrorLabel.textColor = Theme.Colors.urgentText
        nameErrorLabel.numberOfLines = 0
        nameErrorLabel.adjustsFontForContentSizeCategory = true
        nameErrorLabel.isHidden = true

        // --- Quantity
        quantityValueLabel.font = Theme.Typography.itemName.font
        quantityValueLabel.textColor = Theme.Colors.ink
        quantityValueLabel.adjustsFontForContentSizeCategory = true
        stepper.accessibilityLabel = "Quantity"
        stepper.addAction(UIAction { [weak self] _ in self?.updateQuantityLabel() }, for: .valueChanged)
        let quantityControl = UIStackView(arrangedSubviews: [quantityValueLabel, stepper])
        quantityControl.axis = .horizontal
        quantityControl.spacing = 12
        quantityControl.alignment = .center

        // --- Location
        var locationConfig = UIButton.Configuration.plain()
        locationConfig.baseForegroundColor = Theme.Colors.brand
        locationButton.configuration = locationConfig
        locationButton.accessibilityLabel = "Storage location"

        // --- Reminder
        var reminderConfig = UIButton.Configuration.plain()
        reminderConfig.baseForegroundColor = Theme.Colors.brand
        reminderButton.configuration = reminderConfig
        reminderButton.accessibilityLabel = "Reminder"

        // --- Expiry date
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.tintColor = Theme.Colors.brand
        datePicker.accessibilityLabel = "Expiry date"

        quickDateBar.onSelect = { [weak self] index in self?.presenter?.didSelectQuickDate(at: index) }

        // --- What kind of date is it? (tell the Presenter whenever the choice changes)
        dateTypeControl.accessibilityLabel = "Date type"
        dateTypeControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.presenter?.didSelectDateType(at: self.dateTypeControl.selectedSegmentIndex)
        }, for: .valueChanged)

        // --- Price (optional)
        priceField.placeholder = "0.00"
        priceField.keyboardType = .decimalPad
        priceField.textAlignment = .right
        priceField.font = Theme.Typography.itemName.font
        priceField.adjustsFontForContentSizeCategory = true
        priceField.textColor = Theme.Colors.ink
        priceField.accessibilityLabel = "Price"
        priceField.accessibilityIdentifier = "priceField"
        priceField.widthAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
        priceField.addAction(UIAction { [weak self] _ in
            self?.presenter?.didChangePrice(self?.priceField.text ?? "")
        }, for: .editingChanged)
        priceErrorLabel.font = Theme.Typography.caption.font
        priceErrorLabel.textColor = Theme.Colors.urgentText
        priceErrorLabel.numberOfLines = 0
        priceErrorLabel.adjustsFontForContentSizeCategory = true
        priceErrorLabel.isHidden = true

        // --- Scan the date from the pack
        var scanConfig = UIButton.Configuration.tinted()
        scanConfig.baseBackgroundColor = Theme.Colors.brand
        scanConfig.baseForegroundColor = Theme.Colors.brand
        scanConfig.image = UIImage(systemName: "viewfinder")
        scanConfig.imagePadding = 8
        scanConfig.cornerStyle = .large
        var scanTitle = AttributedString("Scan the date on the pack")
        scanTitle.font = Theme.Typography.button.font
        scanConfig.attributedTitle = scanTitle
        scanButton.configuration = scanConfig
        scanButton.accessibilityLabel = "Scan date"
        scanButton.addAction(UIAction { [weak self] _ in self?.presenter?.didTapScan() }, for: .touchUpInside)

        // --- Save button
        var saveConfig = UIButton.Configuration.filled()
        saveConfig.baseBackgroundColor = Theme.Colors.brand
        saveConfig.baseForegroundColor = Theme.Colors.onBrand
        saveConfig.cornerStyle = .large
        saveConfig.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        saveButton.configuration = saveConfig
        saveButton.addAction(UIAction { [weak self] _ in self?.saveTapped() }, for: .touchUpInside)

        // --- Put everything in one scrolling column
        let padded: (UIView) -> UIView = { inner in
            let wrapper = UIView()
            inner.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(inner)
            NSLayoutConstraint.activate([
                inner.topAnchor.constraint(equalTo: wrapper.topAnchor),
                inner.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                inner.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
                inner.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16)
            ])
            return wrapper
        }

        let column = UIStackView(arrangedSubviews: [
            padded(nameCard),
            padded(nameErrorLabel),
            padded(FormCardRow(title: "Quantity", control: quantityControl)),
            padded(FormCardRow(title: "Where is it kept?", control: locationButton)),
            padded(scanButton),
            padded(FormCardRow(title: "Expires", control: datePicker)),
            quickDateBar, // already has its own side margins
            padded(FormCardRow(title: "Date type", control: dateTypeControl)),
            padded(FormCardRow(title: "Price (optional)", control: priceField)),
            padded(priceErrorLabel),
            padded(FormCardRow(title: "Remind me", control: reminderButton)),
            padded(saveButton)
        ])
        column.axis = .vertical
        column.spacing = 12
        column.setCustomSpacing(4, after: nameCard.superview ?? nameCard)
        column.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive // drag down to hide the keyboard
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(column)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            emojiTile.widthAnchor.constraint(equalToConstant: 60),
            emojiTile.heightAnchor.constraint(equalToConstant: 60),
            emojiLabel.centerXAnchor.constraint(equalTo: emojiTile.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: emojiTile.centerYAnchor),
            nameRow.topAnchor.constraint(equalTo: nameCard.topAnchor, constant: 14),
            nameRow.bottomAnchor.constraint(equalTo: nameCard.bottomAnchor, constant: -14),
            nameRow.leadingAnchor.constraint(equalTo: nameCard.leadingAnchor, constant: 14),
            nameRow.trailingAnchor.constraint(equalTo: nameCard.trailingAnchor, constant: -14),

            quickDateBar.heightAnchor.constraint(equalToConstant: 48),

            // The scroll area ends where the keyboard begins, so nothing hides behind it.
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            column.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            column.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            column.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            column.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
}

// MARK: - Receiving the picked photo

extension AddEditItemViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            // This runs in the background; turn the picture into data there, then hop back to the main thread.
            guard let data = (object as? UIImage)?.jpegData(compressionQuality: 0.9) else { return }
            DispatchQueue.main.async { self?.presenter?.didPickPhoto(data) }
        }
    }
}

extension AddEditItemViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let data = (info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9) else { return }
        presenter?.didPickPhoto(data)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
