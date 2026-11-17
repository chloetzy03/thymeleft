import UIKit

/// The waiter of the Welcome tour: a few swipeable slides, dots, and two buttons.
final class WelcomeViewController: UIViewController, WelcomeViewProtocol, UIScrollViewDelegate {

    var presenter: WelcomePresenterProtocol?

    private let logoLabel = UILabel()
    private let pager = UIScrollView()          // the sideways-swiping area
    private let pagesStack = UIStackView()      // the slides, side by side
    private let pageControl = UIPageControl()   // the dots
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)

    private var currentPage = 0
    private var lastWidth: CGFloat = 0

    // MARK: Life of the screen

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Colors.background
        buildLayout()
        presenter?.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // If the width changes (for example on rotation), stay on the same slide.
        if pager.bounds.width != lastWidth {
            lastWidth = pager.bounds.width
            pager.contentOffset = CGPoint(x: lastWidth * CGFloat(currentPage), y: 0)
        }
    }

    // MARK: WelcomeViewProtocol

    func showSlides(_ slides: [WelcomeSlideViewModel]) {
        pagesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for slide in slides {
            let page = makeSlide(slide)
            pagesStack.addArrangedSubview(page)
            // Each slide is exactly as wide as the swiping area (set once it is inside the stack).
            page.widthAnchor.constraint(equalTo: pager.frameLayoutGuide.widthAnchor).isActive = true
        }
        pageControl.numberOfPages = slides.count
    }

    func showPage(_ page: WelcomePageViewModel, animated: Bool) {
        currentPage = page.index
        pageControl.currentPage = page.index
        pageControl.accessibilityValue = page.pageAccessibilityText
        setTitle(page.primaryTitle, on: primaryButton)
        setTitle(page.secondaryTitle, on: secondaryButton)
        let target = CGPoint(x: pager.bounds.width * CGFloat(page.index), y: 0)
        if pager.contentOffset != target { pager.setContentOffset(target, animated: animated) }
        UIAccessibility.post(notification: .pageScrolled, argument: page.pageAccessibilityText)
    }

    // MARK: Swiping

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { reportPageIfChanged() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { reportPageIfChanged() }

    private func reportPageIfChanged() {
        guard pager.bounds.width > 0 else { return }
        let page = Int((pager.contentOffset.x / pager.bounds.width).rounded())
        if page != currentPage { presenter?.didChangePage(to: page) }
    }

    // MARK: Pieces

    private func setTitle(_ text: String, on button: UIButton) {
        var config = button.configuration
        var title = AttributedString(text)
        title.font = Theme.Typography.button.font
        config?.attributedTitle = title
        button.configuration = config
    }

    /// One slide: a round picture, a title and a sentence, centred. It scrolls up and down if the
    /// text is huge (very large text sizes), so nothing is ever cut off.
    private func makeSlide(_ slide: WelcomeSlideViewModel) -> UIView {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 64, weight: .semibold)
        let icon = UIImageView(image: UIImage(systemName: slide.symbol, withConfiguration: symbolConfig))
        icon.tintColor = Theme.Colors.brand
        icon.contentMode = .center
        icon.isAccessibilityElement = false // decoration: the words say it all

        let circle = UIView()
        circle.backgroundColor = Theme.Colors.sage
        circle.layer.cornerRadius = 80
        icon.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(icon)
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 160),
            circle.heightAnchor.constraint(equalToConstant: 160),
            icon.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
        ])

        let title = UILabel()
        title.text = slide.title
        title.font = Theme.Typography.screenTitle.font
        title.textColor = Theme.Colors.ink
        title.accessibilityTraits = .header

        let message = UILabel()
        message.text = slide.message
        message.font = Theme.Typography.body.font
        message.textColor = Theme.Colors.muted

        for label in [title, message] {
            label.numberOfLines = 0
            label.textAlignment = .center
            label.adjustsFontForContentSizeCategory = true
        }

        let stack = UIStackView(arrangedSubviews: [circle, title, message])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.setCustomSpacing(32, after: circle)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // A tall-enough container inside a vertical scroll view, so short slides sit in the middle.
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = false
        scroll.showsVerticalScrollIndicator = false
        scroll.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            container.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),

            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32)
        ])

        // VoiceOver reads each slide as one thing: its title, then its sentence.
        scroll.isAccessibilityElement = false
        scroll.accessibilityElements = [title, message]
        return scroll
    }

    private func styleButton(_ button: UIButton, filled: Bool, identifier: String, action: @escaping () -> Void) {
        var config = filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        config.baseBackgroundColor = Theme.Colors.brand
        config.baseForegroundColor = filled ? Theme.Colors.onBrand : Theme.Colors.brand
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        button.configuration = config
        button.accessibilityIdentifier = identifier
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }

    private func buildLayout() {
        logoLabel.text = String(localized: "thyme left.")
        logoLabel.font = Theme.Typography.logo.font
        logoLabel.textColor = Theme.Colors.brand
        logoLabel.adjustsFontForContentSizeCategory = true
        logoLabel.textAlignment = .center
        logoLabel.accessibilityTraits = .header

        pager.isPagingEnabled = true
        pager.showsHorizontalScrollIndicator = false
        pager.bounces = false
        pager.delegate = self

        pagesStack.axis = .horizontal
        pagesStack.distribution = .fill
        pagesStack.translatesAutoresizingMaskIntoConstraints = false
        pager.addSubview(pagesStack)

        pageControl.currentPageIndicatorTintColor = Theme.Colors.brand
        pageControl.pageIndicatorTintColor = Theme.Colors.divider
        pageControl.accessibilityLabel = String(localized: "Welcome tour")
        pageControl.isUserInteractionEnabled = false // the buttons and swiping are enough

        styleButton(primaryButton, filled: true, identifier: "welcomePrimary") { [weak self] in
            self?.presenter?.didTapPrimary()
        }
        styleButton(secondaryButton, filled: false, identifier: "welcomeSecondary") { [weak self] in
            self?.presenter?.didTapSecondary()
        }

        let buttons = UIStackView(arrangedSubviews: [primaryButton, secondaryButton])
        buttons.axis = .vertical
        buttons.spacing = 4

        for item in [logoLabel, pager, pageControl, buttons] as [UIView] {
            item.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(item)
        }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            logoLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 24),
            logoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            logoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            pager.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 8),
            pager.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pager.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pager.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -8),

            pagesStack.topAnchor.constraint(equalTo: pager.contentLayoutGuide.topAnchor),
            pagesStack.bottomAnchor.constraint(equalTo: pager.contentLayoutGuide.bottomAnchor),
            pagesStack.leadingAnchor.constraint(equalTo: pager.contentLayoutGuide.leadingAnchor),
            pagesStack.trailingAnchor.constraint(equalTo: pager.contentLayoutGuide.trailingAnchor),
            pagesStack.heightAnchor.constraint(equalTo: pager.frameLayoutGuide.heightAnchor),

            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),

            buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            buttons.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16)
        ])
    }
}
