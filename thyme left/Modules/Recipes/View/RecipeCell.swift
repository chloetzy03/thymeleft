import UIKit

/// One recipe in the list: picture, name, what you'd use, what's missing.
final class RecipeCell: UITableViewCell {

    static let reuseIdentifier = "RecipeCell"

    private let card = UIView()
    private let photoView = UIImageView()
    private let placeholder = UILabel()
    private let titleLabel = UILabel()
    private let usesLabel = UILabel()
    private let missingLabel = UILabel()
    /// Which picture this cell is waiting for, so a slow download can't land in a reused cell.
    private var expectedURL: URL?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        accessibilityTraits = .button
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    override func prepareForReuse() {
        super.prepareForReuse()
        expectedURL = nil
        photoView.image = nil
        placeholder.isHidden = false
    }

    func configure(with row: RecipeRowViewModel, imageLoader: RemoteImageLoading) {
        titleLabel.text = row.title
        usesLabel.text = row.usesText
        missingLabel.text = row.missingText
        missingLabel.textColor = row.hasMissing ? Theme.Colors.soonText : Theme.Colors.freshText
        isAccessibilityElement = true
        accessibilityLabel = row.accessibilityText

        expectedURL = row.imageURL
        guard let url = row.imageURL else { return }
        Task { [weak self] in
            guard let image = await imageLoader.image(for: url), self?.expectedURL == url else { return }
            self?.photoView.image = image
            self?.placeholder.isHidden = true
        }
    }

    private func buildLayout() {
        card.backgroundColor = Theme.Colors.card
        card.layer.cornerRadius = 18
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.backgroundColor = Theme.Colors.iconTile
        photoView.translatesAutoresizingMaskIntoConstraints = false

        placeholder.text = "🍳"
        placeholder.font = .systemFont(ofSize: 40)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        photoView.addSubview(placeholder)

        titleLabel.font = Theme.Typography.itemName.font
        titleLabel.textColor = Theme.Colors.ink
        usesLabel.font = Theme.Typography.caption.font
        usesLabel.textColor = Theme.Colors.muted
        missingLabel.font = Theme.Typography.caption.font
        for label in [titleLabel, usesLabel, missingLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }

        let text = UIStackView(arrangedSubviews: [titleLabel, usesLabel, missingLabel])
        text.axis = .vertical
        text.spacing = 3
        let row = UIStackView(arrangedSubviews: [photoView, text])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            photoView.widthAnchor.constraint(equalToConstant: 92),
            photoView.heightAnchor.constraint(equalToConstant: 92),
            placeholder.centerXAnchor.constraint(equalTo: photoView.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: photoView.centerYAnchor),

            row.topAnchor.constraint(equalTo: card.topAnchor),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12)
        ])
    }
}
