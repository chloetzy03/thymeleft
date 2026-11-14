import UIKit

/// One row in the pantry list: emoji tile, name + location, and a coloured expiry badge.
final class PantryItemCell: UITableViewCell {

    static let reuseIdentifier = "PantryItemCell"

    private let card = UIView()
    private let emojiTile = UIView()
    private let emojiLabel = UILabel()
    private let photoView = UIImageView()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badge = PillLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        accessibilityTraits = .button // VoiceOver: "double-tap to open"
        buildLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Not used - we build screens in code") }

    func configure(with row: PantryRowViewModel, photoCache: PhotoImageCache) {
        // Show the photo if there is one (and it loads); otherwise fall back to the emoji.
        if let name = row.photoFileName, let image = photoCache.image(named: name) {
            photoView.image = image
            photoView.isHidden = false
            emojiLabel.isHidden = true
        } else {
            photoView.image = nil
            photoView.isHidden = true
            emojiLabel.isHidden = false
        }
        emojiLabel.text = row.emoji
        nameLabel.text = row.title
        subtitleLabel.text = row.subtitle
        badge.configure(text: row.badgeText, status: row.status)

        // VoiceOver reads ONE friendly sentence for the whole row instead of four fragments.
        isAccessibilityElement = true
        accessibilityLabel = row.accessibilityText
    }

    private func buildLayout() {
        card.backgroundColor = Theme.Colors.card
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        emojiTile.backgroundColor = Theme.Colors.iconTile
        emojiTile.layer.cornerRadius = 13
        emojiTile.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.font = .systemFont(ofSize: 24)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiTile.addSubview(emojiLabel)

        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = 13
        photoView.translatesAutoresizingMaskIntoConstraints = false
        emojiTile.addSubview(photoView)

        nameLabel.font = Theme.Typography.itemName.font
        nameLabel.textColor = Theme.Colors.ink
        nameLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.font = Theme.Typography.caption.font
        subtitleLabel.textColor = Theme.Colors.muted
        subtitleLabel.adjustsFontForContentSizeCategory = true

        let textStack = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        // Badge keeps its natural size; the text column takes whatever room is left.
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [emojiTile, textStack, badge])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            emojiTile.widthAnchor.constraint(equalToConstant: 44),
            emojiTile.heightAnchor.constraint(equalToConstant: 44),
            photoView.topAnchor.constraint(equalTo: emojiTile.topAnchor),
            photoView.bottomAnchor.constraint(equalTo: emojiTile.bottomAnchor),
            photoView.leadingAnchor.constraint(equalTo: emojiTile.leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: emojiTile.trailingAnchor),
            emojiLabel.centerXAnchor.constraint(equalTo: emojiTile.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: emojiTile.centerYAnchor),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12)
        ])
    }
}
